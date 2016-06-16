-module(wl_resize_example).
-export([main/0]).

-include_lib("wl/include/wl_cursor.hrl").

-define(MIN_W,40).
-define(MIN_H,40).
-define(DEF_W,200).
-define(DEF_H,200).
-define(MAX_W,400).
-define(MAX_H,400).

-define(BLUE,<<255,0,0,255>>).

-define(ESC_KEY,1).
-define(L_BTN,272).

-define(CURSOR_THEME,"default").
-define(CURSOR_SIZE,16).
-define(CURSORS,[ default
                , top_side
                , left_side
                , right_side
                , bottom_side
                , top_left_corner
                , top_right_corner
                , bottom_left_corner
                , bottom_right_corner
                ]).


main() ->
    {ok, Conn} = wl:connect(),

    State = init(Conn),

    event_loop(State),

    wl:disconnect(Conn).


init(Conn) ->
    State = #{connection => Conn, width => ?DEF_W, height => ?DEF_H},
    State1 = init_globals(State),
    State2 = init_cursors(State1),
    State3 = init_shm_pool(State2),
    State4 = init_surfaces(State3),
    State4.


init_globals(#{connection := Conn} = State) ->
    State#{ compositor => wl:bind(Conn, wl_compositor)
          , shm        => wl:bind(Conn, wl_shm)
          , shell      => wl:bind(Conn, wl_shell)
          , seat       => wl:bind(Conn, wl_seat)
          , output     => wl:bind(Conn, wl_output)
          }.


init_cursors(State) ->
    State#{ cursors => wl_cursor:load(?CURSOR_THEME, ?CURSOR_SIZE, ?CURSORS)
          , current_cursor => default
          , serial => undefined
          }.


init_shm_pool(#{shm := Shm, cursors := Cursors} = State) ->
    MaxCursorSize = lists:max([size(Img) || #wl_cursor{images=Imgs} <- Cursors
                                          , #wl_cursor_image{data=Img} <- Imgs]),

    SurfaceBufferSize = ?MAX_W * ?MAX_H * 4,
    Size =  2 * SurfaceBufferSize + MaxCursorSize,

    MemFd = memfd:create(),
    fill_fd(MemFd, ?BLUE, Size),

    Fd = afunix:fd_from_binary(memfd:fd_to_binary(MemFd)),

    State#{ shm_pool => wl_shm:create_pool(Shm, handler(), Fd, Size)
          , shm_free => [0, SurfaceBufferSize]
          , memfd    => MemFd
          }.


init_surfaces(#{compositor := Compositor, shell := Shell} = State) ->
    Surface = wl_compositor:create_surface(Compositor, handler()),
    ShellSurface = wl_shell:get_shell_surface(Shell, handler(), Surface),
    ok = wl_shell_surface:set_toplevel(ShellSurface),
    State#{ main_surface   => Surface
          , shell_surface  => ShellSurface
          , cursor_surface => wl_compositor:create_surface(Compositor, handler())
          }.


event_loop(State) ->
    receive
        Msg ->
            io:format("~p~n", [Msg]),
            case handle_event(Msg, State) of
                stop     -> ok;
                NewState -> event_loop(NewState)
            end
    end.


handle_event({wl_keyboard, _, released, _Serial, _Time, ?ESC_KEY}, _) ->
    stop;

handle_event({wl_shell_surface, ShellSurface, ping, [Arg]}, State) ->
    ok = wl_shell_surface:pong(ShellSurface, Arg),
    State;

handle_event({wl_shell_surface, _, configure, [_Edges, W, H]}, State) ->
    resize(W, H, State);

handle_event({wl_output, _Output, config, _Info}, State) ->
    render(State#{buffers => []});

handle_event({wl_pointer, _, enter, [Serial, Surface, X, Y]},
             #{main_surface := Surface} = State) ->
    update_cursor(enter, X, Y, State#{serial := Serial});

handle_event({wl_pointer, _, motion, [_Time, X, Y]}, State) ->
    update_cursor(motion, X, Y, State);

handle_event({wl_pointer, _, button, [Serial, _, ?L_BTN, pressed]}, State) ->
    request_resize(Serial, State);

handle_event({wl_pointer, _, leave, [_Serial, _Surface]}, State) ->
    State#{current_cursor := default, serial := undefined};

handle_event({wl_buffer, Buf, release},
             #{buffers := Buffers, shm_free := Free} = State) ->
    ok = wl_buffer:destroy(Buf),
    case lists:keytake(Buf, 1, Buffers) of
        {value, {Buf, Offset}, Rest} ->
            State#{buffers := Rest, shm_free := [Offset | Free]};
        _ ->
            State
    end;

handle_event(_, State) ->
    State.


update_cursor(enter, X, Y, State) ->
    set_cursor(get_cursor(X, Y, State), State);

update_cursor(motion, X, Y, #{current_cursor := Cursor}=State) ->
    case get_cursor(X, Y, State) of
        Cursor    -> State;
        NewCursor -> set_cursor(NewCursor, State)
    end.


get_cursor(X, Y, _State) when X < 5, Y < 5 ->
    top_left_corner;

get_cursor(X, Y, #{width := W}) when X > (W - 5), Y < 5 ->
    top_right_corner;

get_cursor(X, Y, #{height := H}) when X < 5, Y > (H - 5) ->
    bottom_left_corner;

get_cursor(X, Y, #{width := W, height := H}) when X > (W - 5), Y > (H - 5) ->
    bottom_right_corner;

get_cursor(X, _Y, _State) when X < 5 ->
    left_side;

get_cursor(X, _Y, #{width := W}) when X > (W - 5) ->
    right_side;

get_cursor(_X, Y, _State) when Y < 5 ->
    top_side;

get_cursor(_X, Y, #{height := H}) when Y > (H - 5) ->
    bottom_side;

get_cursor(_, _, _) ->
    default.


set_cursor(_Cursor, #{serial := undefined}=State) ->
    State;

set_cursor(Cursor, #{seat := Seat}=State) ->
    case wl_seat_handler:pointer(Seat) of
        undefined -> State;
        Pointer   -> set_cursor(Cursor, Pointer, State)
    end.

set_cursor(Cursor, Pointer, #{ serial := Serial
                             , cursor_surface := Surface
                             , cursors := Cursors
                             }=State) ->
    #wl_cursor{images=[#wl_cursor_image{ x_hot  = Xhot
                                       , y_hot  = Yhot
                                       , width  = W
                                       , height = H
                                       , data   = Data
                                       }
                       |_]} = lists:keyfind(Cursor, #wl_cursor.name, Cursors),
    Buf = allocate_cursor_buffer(W, H, Data, State),
    ok = wl_surface:attach(Surface, Buf, 0, 0),
    ok = wl_surface:damage(Surface, 0, 0, W, H),
    ok = wl_surface:commit(Surface),
    ok = wl_pointer:set_cursor(Pointer, Serial, Surface, Xhot, Yhot),
    State#{current_cursor := Cursor}.


request_resize(Serial, #{current_cursor := top_right_corner} = State) ->
    request_resize(Serial, top_right, State);

request_resize(Serial, #{current_cursor := top_left_corner} = State) ->
    request_resize(Serial, top_left, State);

request_resize(Serial, #{current_cursor := bottom_right_corner} = State) ->
    request_resize(Serial, bottom_right, State);

request_resize(Serial, #{current_cursor := bottom_left_corner} = State) ->
    request_resize(Serial, bottom_left, State);

request_resize(Serial, #{current_cursor := top_side} = State) ->
    request_resize(Serial, top, State);

request_resize(Serial, #{current_cursor := bottom_side} = State) ->
    request_resize(Serial, bottom, State);

request_resize(Serial, #{current_cursor := left_side} = State) ->
    request_resize(Serial, left, State);

request_resize(Serial, #{current_cursor := right_side} = State) ->
    request_resize(Serial, right, State);

request_resize(_Serial, State) ->
    State.

request_resize(Serial, Edge, #{seat := Seat, shell_surface := Surface}=State) ->
    ok = wl_shell_surface:resize(Surface, Seat, Serial, [Edge]),
    State.


resize(Width, Height, State)  ->
    W1 = min(Width, ?MAX_W),
    H1 = min(Height, ?MAX_H),
    render(State#{width := max(W1,?MIN_W), height := max(H1,?MIN_H)}).


render(#{width := Width, height := Height, main_surface := Surface} = State) ->
    case allocate_buffer(State) of
        {ok, Buf, State1} ->
            ok = wl_surface:attach(Surface, Buf, 0, 0),
            ok = wl_surface:damage(Surface, 0, 0, Width, Height),
            ok = wl_surface:commit(Surface),
            State1;
        false ->
            State
    end.


allocate_buffer(#{shm_free := []}) ->
    false;

allocate_buffer(#{ shm_pool := Pool
                 , shm_free := [Offset | Rest]
                 , width    := W
                 , height   := H
                 , buffers  := Buffers} = State) ->
    Stride = ?MAX_W * 4,
    Buf = wl_shm_pool:create_buffer(Pool, handler(), Offset, W, H, Stride, 0),
    {ok, Buf, State#{shm_free := Rest, buffers := [{Buf, Offset} | Buffers]}}.


allocate_cursor_buffer(W, H, Data, #{shm_pool := Pool, memfd := MemFd}) ->
    Offset = 2 * (?MAX_W * ?MAX_H * 4),
    Stride = W * 4,
    ok = memfd:pwrite(MemFd, Offset, Data),
    wl_shm_pool:create_buffer(Pool, handler(), Offset, W, H, Stride, 0).



fill_fd(_, _, Size) when Size =< 0 ->
    ok;
fill_fd(MemFd, Color, Size) ->
    memfd:write(MemFd, Color),
    fill_fd(MemFd, Color, Size-4).

handler() ->
    wl_default_handler:new().
