-module(wl_object).

-export([ start_link/4
        , notify/2
        , call/2
        , call/3
        ]).

% internal API
-export([ init/6
        , init_new_id/7
        , system_continue/3
        , system_terminate/4
        ]).

-include("wl.hrl").


start_link(Id, {Itf, Ver}, Conn, Handler) ->
    proc_lib:start_link(?MODULE, init, [self(), Id, Itf, Ver, Conn, Handler]).


notify(#wl_event{sender={Mod, Pid},evtcode=Code,args=Args}, Fds) ->
    Mod:'$notify$'(Pid, Code, Args, Fds).


call(Pid, Request) ->
    call(Pid, Request, 5000).

call(Pid, Request, Timeout) ->
    Mref = erlang:monitor(process, Pid),
    Pid ! {'$call$', {self(), Mref}, Request},
    receive
        {Mref, Reply} ->
            erlang:demonitor(Mref, [flush]),
            Reply;
        {'DOWN', Mref, _, _, Reason} ->
            exit(Reason)
    after Timeout ->
            erlang:demonitor(Mref, [flush]),
            exit(timeout)
    end .


-record(state,{id,interface,version,connection,handler,handler_state}).


init(Parent, Id, Itf, Ver, Conn, Handler) ->
    InitHandler = init_handler(Parent, Ver, Handler),
    init_1(Parent, Id, Itf, Ver, Conn, InitHandler).


init_new_id(Parent, ParentId, _ParentVer, OpCode,
            {Args1, {new_id, {Itf, Ver, Handler}}, Args2},
            Fds, Conn) ->
    InitHandler = init_handler(Parent, Ver, Handler),
    NewArgs1 = [request_arg(Arg, Conn) || Arg <- Args1],
    NewArgs2 = [request_arg(Arg, Conn) || Arg <- Args2],
    Fun = fun (NewId) ->
              ItfBin = list_to_binary(atom_to_list(Itf)),
              NewArgs = NewArgs1 ++
                  [ wl_wire:encode_string(ItfBin)
                  , wl_wire:encode_uint(Ver)
                  , wl_wire:encode_object(NewId)
                  ]
                  ++ NewArgs2,
              {#wl_request{sender=ParentId,opcode=OpCode,args=NewArgs}, Fds}
          end,
    init_2(Parent, Fun, Itf, Ver, Conn, InitHandler);

init_new_id(Parent, ParentId, ParentVer, OpCode,
            {Args1, {new_id, Itf, Handler}, Args2},
            Fds, Conn) ->
    Ver = min(Itf:version(), ParentVer),
    InitHandler = init_handler(Parent, Ver, Handler),
    NewArgs1 = [request_arg(Arg, Conn) || Arg <- Args1],
    NewArgs2 = [request_arg(Arg, Conn) || Arg <- Args2],
    Fun = fun (NewId) ->
              NewArgs = NewArgs1 ++ [wl_wire:encode_object(NewId) | NewArgs2],
              {#wl_request{sender=ParentId,opcode=OpCode,args=NewArgs}, Fds}
          end,
    init_2(Parent, Fun, Itf, Ver, Conn, InitHandler).


init_1(Parent, Id, Itf, Ver, Conn, {ok, Handler, HandlerState}) ->
    ok = wl_connection:register(Conn, Id, Itf, self()),
    proc_lib:init_ack(Parent, {ok, self()}),
    State = #state{ id=Id
                  , interface=Itf
                  , version=Ver
                  , connection=Conn
                  , handler=Handler
                  , handler_state=HandlerState
                  },
    loop(Parent, {Itf, self()}, State, []);

init_1(Parent, _Id, _Itf, _Ver, _Conn, {stop, Reason}) ->
    proc_lib:init_ack(Parent, {error, Reason}),
    exit(Reason);

init_1(Parent, _Id, _Itf, _Ver, _Conn, Other) ->
    Reason = {bad_return_value, Other},
    proc_lib:init_ack(Parent, {error, Reason}),
    exit(Reason).


init_2(Parent, Fun, Itf, Ver, Conn, {ok, _, _}=InitHandler) ->
    Id = wl_connection:request_new_id(Conn, Fun),
    init_1(Parent, Id, Itf, Ver, Conn, InitHandler);

init_2(Parent, _Fun, Itf, Ver, Conn, InitHandler) ->
    init_1(Parent, null, Itf, Ver, Conn, InitHandler).


init_handler(Parent, Ver, {Handler, Init}) ->
    try Handler:init(Ver, Init) of
        {ok, HandlerState} -> {ok, Handler, HandlerState};
        Other              -> Other
    catch
        _:Reason ->
            proc_lib:init_ack(Parent, {error, Reason}),
            exit(Reason)
    end;

init_handler(Parent, Ver, Handler) ->
    try Handler:init(Ver) of
        {ok, HandlerState} -> {ok, Handler, HandlerState};
        Other              -> Other
    catch
        _:Reason ->
            proc_lib:init_ack(Parent, {error, Reason}),
            exit(Reason)
    end.


loop(Parent, Name, State, Dbg) ->
    receive
        {'$request$', Code, Args, Fds} = Msg->
            Dbg1 = sys:handle_debug(Dbg, fun debug/3, Name, {in, Msg}),
            NewState = handle_request(Code, Args, Fds, State),
            loop(Parent, Name, NewState, Dbg1);

        {'$request_new_id$', {To, Tag}, {Code, Args, Fds}} = Msg->
            Dbg1 = sys:handle_debug(Dbg, fun debug/3, Name, {in, Msg}),
            {Reply, NewState} = handle_request_new_id(Code, Args, Fds, State),
            To ! {Tag, Reply},
            Dbg2 = sys:handle_debug(Dbg1, fun debug/3, Name, {out, Reply, To}),
            loop(Parent, Name, NewState, Dbg2);

        {'$request_destructor$', Code, Args, Fds} = Msg->
            sys:handle_debug(Dbg, fun debug/3, Name, {in, Msg}),
            NewState = handle_request(Code, Args, Fds, State),
            terminate(normal, NewState);

        {'$event$', Event, Args} = Msg ->
            Dbg1 = sys:handle_debug(Dbg, fun debug/3, Name, {in, Msg}),
            NewState = handle_event(Event, Args, State),
            loop(Parent, Name, NewState, Dbg1);

        {'$call$', {To, Tag}, Request} = Msg->
            Dbg1 = sys:handle_debug(Dbg, fun debug/3, Name, {in, Msg}),
            {Reply, NewState} = handle_call(Request, State),
            To ! {Tag, Reply},
            Dbg2 = sys:handle_debug(Dbg1, fun debug/3, Name, {out, Reply, To}),
            loop(Parent, Name, NewState, Dbg2);

        {system, From, Msg} ->
            sys:handle_system_msg(Msg, From, Parent, ?MODULE, Dbg,
                                  {fun loop/4, Name, State});
        Msg ->
            Dbg1 = sys:handle_debug(Dbg, fun debug/3, Name, {in, Msg}),
            loop(Parent, Name, State, Dbg1)
    end.


terminate(Reason, #state{handler=Handler}=State) ->
    catch Handler:terminate(State#state.handler_state),
    wl_connection:unregister(State#state.connection, self()),
    exit(Reason).


handle_request(Code, Args, Fds, State) ->
    NewArgs = [request_arg(Arg, State#state.connection) || Arg <- Args],
    Request = #wl_request{sender=State#state.id,opcode=Code,args=NewArgs},
    ok = wl_connection:request(State#state.connection, Request, Fds),
    State.


handle_request_new_id(Code, Args, Fds, State) ->
    InitArgs = [ self()
               , State#state.id
               , State#state.version
               , Code
               , Args
               , Fds
               , State#state.connection
               ],
    case proc_lib:start_link(?MODULE, init_new_id, InitArgs) of
        {ok, Pid}       -> {Pid, State};
        {error, Reason} -> exit(Reason)
    end.


request_arg({id, Pid}, Conn) ->
    wl_connection:pid_to_id(Conn, Pid);

request_arg(Arg, _) ->
    Arg.


handle_event(Event, Args, #state{handler=Handler}=State) ->
    NewArgs = [event_arg(Arg, State) || Arg <- Args],
    case Handler:handle_event(Event, NewArgs, State#state.handler_state) of
        ok ->
            State;
        {new_state, NewHandlerState} ->
            State#state{handler_state=NewHandlerState};
        {delete_id, Id, NewHandlerState} ->
            Pid = wl_connection:id_to_pid(State#state.connection, Id),
            ok = proc_lib:stop(Pid),
            State#state{handler_state=NewHandlerState}
    end.


event_arg({new_id, Itf, Id}, #state{handler=Handler}=State) ->
    Ver = min(Itf:version(), State#state.version),
    NewHandler = Handler:new_handler(Itf, Ver, State#state.handler_state),
    case start_link(Id, {Itf, Ver}, State#state.connection, NewHandler) of
        {ok, Pid}       -> Pid;
        {error, Reason} -> exit(Reason)
    end;

event_arg({id, Id}, #state{connection=Conn}) ->
    wl_connection:id_to_pid(Conn, Id);

event_arg(Arg, _) ->
    Arg.


handle_call(Request, #state{handler=Handler}=State) ->
    case Handler:handle_call(Request, State#state.handler_state) of
        {reply, Reply} ->
            {Reply, State};
        {reply, Reply, NewHandlerState} ->
            {Reply, State#state{handler_state=NewHandlerState}}
    end.


debug(Dev, {in, Msg}, Name) ->
    io:format(Dev, "*DBG* ~p got ~p~n", [Name, Msg]);
debug(Dev, {out, Msg, To}, Name) ->
    io:format(Dev, "*DBG* ~p sent ~p to ~w~n", [Name, Msg, To]);
debug(Dev, Event, Name) ->
    io:format(Dev, "*DBG* ~p dbg  ~p~n", [Name, Event]).


system_continue(Parent, Debug, {Loop, Name, Data}) ->
    Loop(Parent, Name, Data, Debug).


system_terminate(Reason, _Parent, _Debug, {_Loop, _Name, State}) ->
    terminate(Reason, State).
