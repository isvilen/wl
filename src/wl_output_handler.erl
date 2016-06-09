-module(wl_output_handler).
-export([ new/0
        , new/1
        , geometry/1
        , subpixel/1
        , manufacturer/1
        , model/1
        , transform/1
        , scale/1
        , mode/1
        , mode/2
        , modes/1
        , init/3
        , handle_event/3
        , handle_call/2
        ]).

new() -> {?MODULE, self()}.

new(NotifyPid) -> {?MODULE, NotifyPid}.


geometry(Output) ->
    wl_object:call(Output, geometry).


subpixel(Output) ->
    wl_object:call(Output, subpixel).


manufacturer(Output) ->
    wl_object:call(Output, manufacturer).


model(Output) ->
    wl_object:call(Output, model).


transform(Output) ->
    wl_object:call(Output, transform).


scale(Output) ->
    wl_object:call(Output, scale).


mode(Output) ->
    mode(Output, current).


mode(Output, Mode) ->
    wl_object:call(Output, {mode, Mode}).


modes(Output) ->
    wl_object:call(Output, modes).


-record(state,{ geometry
              , subpixel
              , manufacturer
              , model
              , transform
              , scale = 1
              , modes = []
              , notify
              , version
              }).

init(_Parent, {wl_output, Version}, Pid) ->
    {ok, #state{notify=Pid, version=Version}}.


handle_event(geometry, [X,Y,W,H,SubPx,Make,Model,Trans], State) ->
    {new_state, State#state{ geometry={X,Y,W,H}
                           , subpixel=SubPx
                           , manufacturer=Make
                           , model=Model
                           , transform=Trans
                           }};

handle_event(mode, [Flags,W,H,Refresh], State) ->
    Mode = {W,H,Refresh},
    Modes = lists:keydelete(Mode, 1, State#state.modes),
    NewState = State#state{modes=[{Mode, Flags} | Modes]},
    case lists:member(current, Flags) of
        true when State#state.version =:= 1 ->
            send_config(NewState); % there is no 'done' event in version 1
        _ ->
            ok
    end,
    {new_state, NewState};

handle_event(scale, [Factor], State) ->
    {new_state, State#state{scale=Factor}};

handle_event(done, [], State) ->
    send_config(State).


handle_call(geometry, #state{geometry=G}) ->
    {reply, G};

handle_call(subpixel, #state{subpixel=S}) ->
    {reply, S};

handle_call(manufacturer, #state{manufacturer=M}) ->
    {reply, M};

handle_call(model, #state{model=M}) ->
    {reply, M};

handle_call(transform, #state{transform=T}) ->
    {reply, T};

handle_call(scale, #state{scale=S}) ->
    {reply, S};

handle_call({mode, Mode}, #state{modes=Modes}) ->
    {reply, find_mode(Mode, Modes)};

handle_call(modes, #state{modes=Modes}) ->
    {reply, [M || {M,_} <- Modes]}.


find_mode(_, []) ->
    undefined;

find_mode(Mode, [{M,Flags} | Modes]) ->
    case lists:member(Mode, Flags) of
        true  -> M;
        false -> find_mode(Mode, Modes)
    end.


send_config(#state{notify=undefined}) ->
    ok;

send_config(#state{ geometry=G
                  , subpixel=SubPx
                  , manufacturer=Mf
                  , model=M
                  , transform=T
                  , scale=S
                  , modes=Modes
                  , notify=Pid}) ->
    Info = [ {geometry,G}
           , {subpixel,SubPx}
           , {manufacturer,Mf}
           , {model,M}
           , {transform,T}
           , {scale,S}
           , {mode,find_mode(current,Modes)}
    ],
    Pid ! {wl_output, self(), config, Info},
    ok.
