-module(wl_object).

-export([ start_link/4
        , notify/2
        , call/2
        , call/3
        ]).

% internal API
-export([ init/6
        , start_child/3
        , start_child/4
        , request/4
        , destroy/1
        , system_continue/3
        , system_terminate/4
        ]).

-include("wl.hrl").


start_link(Id, {Itf, Ver}, Conn, Handler) ->
    proc_lib:start_link(?MODULE, init, [self(), Id, Itf, Ver, Conn, Handler]).


start_child(Pid, Interface, Id) ->
    call(Pid, {'$start_child$', Interface, Id}).

start_child(Pid, Interface, Id, Handler) ->
    call(Pid, {'$start_child$', Interface, Id, Handler}).


request(Pid, OpCode, Args, Fds) ->
    {Id, Conn} = call(Pid, '$get_id_conn$'),
    Request = #wl_request{sender=Id, opcode=OpCode, args=Args},
    wl_connection:request(Conn, Request, Fds).

destroy(Pid) ->
    Pid ! '$destroy$',
    ok.


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
    InitHandler = init_handler(Parent, {Itf, Ver}, Handler),
    init_1(Parent, Id, Itf, Ver, Conn, InitHandler).

init_1(Parent, Id, Itf, Ver, Conn, {ok, _, _} = InitHandler) ->
    init_ack(Parent, Id, Itf, Ver, Conn, InitHandler);

init_1(Parent, Id, Itf, Ver, Conn, InitHandler) ->
    init_ack(Parent, Id, Itf, Ver, Conn, InitHandler).


init_ack(Parent, Id, Itf, Ver, Conn, {ok, Handler, HandlerState}) ->
    proc_lib:init_ack(Parent, {ok, self()}),
    State = #state{ id=Id
                  , interface=Itf
                  , version=Ver
                  , connection=Conn
                  , handler=Handler
                  , handler_state=HandlerState
                  },
    loop(Parent, {Itf, self()}, State, []);

init_ack(Parent, _Id, _Itf, _Ver, _Conn, {stop, Reason}) ->
    proc_lib:init_ack(Parent, {error, Reason}),
    exit(Reason);

init_ack(Parent, _Id, _Itf, _Ver, _Conn, Other) ->
    Reason = {bad_return_value, Other},
    proc_lib:init_ack(Parent, {error, Reason}),
    exit(Reason).


init_handler(Parent, ItfVer, {Handler, Init}) ->
    try Handler:init(Parent, ItfVer, Init) of
        {ok, HandlerState} -> {ok, Handler, HandlerState};
        Other              -> Other
    catch
        _:Reason ->
            proc_lib:init_ack(Parent, {error, Reason}),
            exit(Reason)
    end;

init_handler(Parent, ItfVer, Handler) ->
    try Handler:init(Parent, ItfVer) of
        {ok, HandlerState} -> {ok, Handler, HandlerState};
        Other              -> Other
    catch
        _:Reason ->
            proc_lib:init_ack(Parent, {error, Reason}),
            exit(Reason)
    end.


loop(Parent, Name, State, Dbg) ->
    receive
        {'$call$', {To, Tag}, Request} = Msg->
            Dbg1 = sys:handle_debug(Dbg, fun debug/3, Name, {in, Msg}),
            {Reply, NewState} = handle_call(Request, State),
            To ! {Tag, Reply},
            Dbg2 = sys:handle_debug(Dbg1, fun debug/3, Name, {out, Reply, To}),
            loop(Parent, Name, NewState, Dbg2);

        {'$event$', Event, Args} = Msg ->
            Dbg1 = sys:handle_debug(Dbg, fun debug/3, Name, {in, Msg}),
            NewState = handle_event(Event, Args, State),
            loop(Parent, Name, NewState, Dbg1);

        '$destroy$' = Msg when State#state.id < ?WL_SERVER_ID_START ->
            Dbg1 = sys:handle_debug(Dbg, fun debug/3, Name, {in, Msg}),
            zombie(Parent, Name, State, Dbg1);

        '$destroy$' = Msg ->
            sys:handle_debug(Dbg, fun debug/3, Name, {in, Msg}),
            terminate(normal, State);

        {system, From, Msg} ->
            sys:handle_system_msg(Msg, From, Parent, ?MODULE, Dbg,
                                  {fun loop/4, Name, State});
        Msg ->
            Dbg1 = sys:handle_debug(Dbg, fun debug/3, Name, {in, Msg}),
            loop(Parent, Name, State, Dbg1)
    end.


zombie(Parent, Name, State, Dbg) ->
    receive
      {system, From, Msg} ->
        sys:handle_system_msg(Msg, From, Parent, ?MODULE, Dbg,
                              {fun zombie/4, Name, State});
      Msg ->
        Dbg1 = sys:handle_debug(Dbg, fun debug/3, Name, {in, Msg}),
        zombie(Parent, Name, State, Dbg1)
    end.


terminate(Reason, #state{id=Id}=State) when Id < ?WL_SERVER_ID_START ->
    catch (State#state.handler):terminate(State#state.handler_state),
    wl_connection:free_id(State#state.connection, State#state.id),
    exit(Reason);

terminate(Reason, State) ->
    catch (State#state.handler):terminate(State#state.handler_state),
    exit(Reason).


handle_event(Event, Args, #state{handler=Handler}=State) ->
    NewArgs = [event_arg(Arg, State) || Arg <- Args],
    case Handler:handle_event(Event, NewArgs, State#state.handler_state) of
        ok                        -> State;
        {new_state, HandlerState} -> State#state{handler_state=HandlerState}
    end.


event_arg({id, null}, _) ->
    null;

event_arg({id, Id}, #state{connection=Conn}) ->
    wl_connection:id_to_pid(Conn, Id);

event_arg(Arg, _) ->
    Arg.


handle_call('$get_id_conn$', #state{id=Id,connection=Conn}=State) ->
    {{Id, Conn}, State};

handle_call({'$start_child$', Itf, Id}, #state{handler=Handler}=State) ->
    ItfVer = {Itf, min(Itf:interface_info(version), State#state.version)},
    NewHandler = Handler:new_handler(ItfVer, State#state.handler_state),
    case start_link(Id, ItfVer, State#state.connection, NewHandler) of
        {ok, Pid}       -> {Pid, State};
        {error, Reason} -> exit(Reason)
    end;

handle_call({'$start_child$', Itf, Id, Handler}, State) ->
    Ver = min(Itf:interface_info(version), State#state.version),
    case start_link(Id, {Itf, Ver}, State#state.connection, Handler) of
        {ok, Pid}       -> {Pid, State};
        {error, Reason} -> exit(Reason)
    end;

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
