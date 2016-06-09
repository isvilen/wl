-module(wl_object).

% public API
-export([ id/1
        , interface/1
        , connection/1
        , call/2
        , call/3
        , cast/2
        ]).

% internal API
-export([ start_link/4
        , notify/2
        , new_id/2
        , init/5
        , init/6
        , start_child/2
        , request/4
        , destroy/1
        , system_continue/3
        , system_terminate/4
        ]).

-include("wl.hrl").


id(Pid) when Pid == self() ->
    get(wl_id);

id(Pid) ->
    call(Pid, '$get_id$').


interface(Pid) when Pid == self() ->
    {get(wl_interface), get(wl_version)};

interface(Pid) ->
    call(Pid, '$get_interface_version$').


connection(Pid) when Pid == self() ->
    get(wl_connection);

connection(Pid) ->
    call(Pid, '$get_connection$').


call(Pid, Request) ->
    call(Pid, Request, 5000).


call(Pid, _Request, _Timeout) when Pid =:= self() ->
    error(badarg);

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
    end.


cast(Pid, Message) ->
    Pid ! {'$cast$', Message},
    ok.


start_link(Id, {Itf, Ver}, Conn, Handler) ->
    proc_lib:start_link(?MODULE, init, [self(), Id, Itf, Ver, Conn, Handler]).


notify(#wl_event{sender={Mod, Pid},evtcode=Code,args=Args}, Fds) ->
    Mod:'$notify$'(Pid, Code, Args, Fds).


start_child(Pid, Arg) ->
    call(Pid, {'$start_child$', Arg}).


new_id(Pid, NewId) ->
    Pid ! {'$new_id$', NewId},
    ok.


start_new_id_link({Itf, Ver}, Conn, Handler) ->
    case proc_lib:start_link(?MODULE, init, [self(), Itf, Ver, Conn, Handler]) of
        {ok, Pid}       -> Pid;
        {error, Reason} -> exit(Reason)
    end.


request(Pid, OpCode, Args, Fds) ->
    {Id, Conn, Args1} = prepare_request(Pid, Args),
    Request = #wl_request{sender=Id, opcode=OpCode, args=Args1},
    wl_connection:request(Conn, Request, Fds).


prepare_request(Pid, Args) when Pid =:= self() ->
    prepare_local_request(Args);

prepare_request(Pid, {Args1, NewId, Args2}) ->
    {Id, Conn, NewId1} = prepare_new_id(Pid, NewId),
    {Id, Conn, {Args1, NewId1, Args2}};

prepare_request(Pid, Args) ->
    erlang:append_element(call(Pid, '$get_id_conn$'), Args).


prepare_local_request({Args1, NewId, Args2}) ->
    {Id, Conn, NewPid} = prepare_local_new_id(NewId),
    {Id, Conn, {Args1, NewPid, Args2}};

prepare_local_request(Args) ->
    {get(wl_id), get(wl_connection), Args}.


prepare_new_id(Pid, {new_id, {Itf, Ver, _}}=NewId) ->
    {Id, Conn, NewPid} = start_child(Pid, NewId),
    {Id, Conn, {new_id, {Itf, Ver, NewPid}}};

prepare_new_id(Pid, {new_id, Itf, _}=NewId) ->
    {Id, Conn, NewPid} = start_child(Pid, NewId),
    {Id, Conn, {new_id, Itf, NewPid}}.


prepare_local_new_id({new_id, {Itf, Ver, Handler}}) ->
    ItfVer = {Itf, Ver},
    Conn = get(wl_connection),
    NewPid = start_new_id_link(ItfVer, Conn, Handler),
    {get(wl_id), Conn, {new_id, {Itf, Ver, NewPid}}};

prepare_local_new_id({new_id, Itf, Handler}) ->
    ItfVer = {Itf, min(Itf:interface_info(version), get(wl_version))},
    Conn = get(wl_connection),
    NewPid = start_new_id_link(ItfVer, Conn, Handler),
    {get(wl_id), Conn, {new_id, Itf, NewPid}}.


destroy(Pid) ->
    Pid ! '$destroy$',
    ok.


-record(state,{handler,handler_state}).


init(Parent, Itf, Ver, Conn, Handler) ->
    put(wl_interface, Itf),
    put(wl_version, Ver),
    put(wl_connection, Conn),
    proc_lib:init_ack(Parent, {ok, self()}),
    unborn(Parent, {Itf, self()}, #state{handler=Handler}, []).


init(Parent, Id, Itf, Ver, Conn, Handler) ->
    put(wl_id, Id),
    put(wl_interface, Itf),
    put(wl_version, Ver),
    put(wl_connection, Conn),
    proc_lib:init_ack(Parent, {ok, self()}),
    State = init_handler(Parent, #state{handler=Handler}),
    loop(Parent, {Itf, self()}, State, []).


init_handler(Parent, #state{handler={Handler, Init}}=State) ->
    ItfVer = {get(wl_interface), get(wl_version)},
    try Handler:init(Parent, ItfVer, Init) of
        {ok, HandlerState} ->
            State#state{handler=Handler, handler_state=HandlerState};
        Other ->
            exit({bad_return_value, Other})
    catch
        _:Reason -> exit(Reason)
    end;

init_handler(Parent, #state{handler=Handler}=State) ->
    ItfVer = {get(wl_interface), get(wl_version)},
    try Handler:init(Parent, ItfVer) of
        {ok, HandlerState} -> State#state{handler_state=HandlerState};
        Other              -> exit({bad_return_value, Other})
    catch
        _:Reason -> exit(Reason)
    end.


unborn(Parent, Name, State, Dbg) ->
    receive
        {'$new_id$', Id} = Msg ->
            put(wl_id, Id),
            Dbg1 = sys:handle_debug(Dbg, fun debug/3, Name, {in, Msg}),
            loop(Parent, Name, init_handler(Parent, State), Dbg1);

        {system, From, Msg} ->
            sys:handle_system_msg(Msg, From, Parent, ?MODULE, Dbg,
                                  {fun unborn/4, Name, State})
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

        {'$cast$', Message} = Msg ->
            Dbg1 = sys:handle_debug(Dbg, fun debug/3, Name, {in, Msg}),
            NewState = handle_cast(Message, State),
            loop(Parent, Name, NewState, Dbg1);

        '$destroy$' = Msg ->
            Dbg1 = sys:handle_debug(Dbg, fun debug/3, Name, {in, Msg}),
            case get(wl_id) of
                Id when Id < ?WL_SERVER_ID_START ->
                    zombie(Parent, Name, State, Dbg1);
                _ ->
                    terminate(normal, State)
            end;

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


terminate(Reason, #state{handler=Handler}=State)  ->
    catch Handler:terminate(State#state.handler_state),
    case get(wl_id) of
        Id when Id < ?WL_SERVER_ID_START ->
            wl_connection:free_id(get(wl_connection), Id);
        _ ->
            ok
    end,
    exit(Reason).


handle_event(Event, Args, #state{handler=Handler}=State) ->
    NewArgs = [event_arg(Arg) || Arg <- Args],
    case Handler:handle_event(Event, NewArgs, State#state.handler_state) of
        ok                        -> State;
        {new_state, HandlerState} -> State#state{handler_state=HandlerState}
    end.


event_arg({id, null}) ->
    null;

event_arg({id, Id}) ->
    wl_connection:id_to_pid(get(wl_connection), Id);

event_arg(Arg) ->
    Arg.


handle_call('$get_id$', State) ->
    {get(wl_id), State};

handle_call('$get_connection$', State) ->
    {get(wl_connection), State};

handle_call('$get_interface_version$', State) ->
    {{get(wl_interface), get(wl_version)}, State};

handle_call('$get_id_conn$', State) ->
    {{get(wl_id), get(wl_connection)}, State};

handle_call({'$start_child$', {id, Itf, Id}}, #state{handler=Handler}=State) ->
    ItfVer = {Itf, min(Itf:interface_info(version), get(wl_version))},
    NewHandler = Handler:new_handler(ItfVer, State#state.handler_state),
    case start_link(Id, ItfVer, get(wl_connection), NewHandler) of
        {ok, Pid}       -> {Pid, State};
        {error, Reason} -> exit(Reason)
    end;

handle_call({'$start_child$', {new_id, {Itf, Ver, Handler}}}, State) ->
    ItfVer = {Itf, min(Ver, get(wl_version))},
    Conn = get(wl_connection),
    Pid = start_new_id_link(ItfVer, Conn, Handler),
    {{get(wl_id), Conn, Pid}, State};

handle_call({'$start_child$', {new_id, Itf, Handler}}, State) ->
    ItfVer = {Itf, min(Itf:interface_info(version), get(wl_version))},
    Conn = get(wl_connection),
    Pid = start_new_id_link(ItfVer, Conn, Handler),
    {{get(wl_id), Conn, Pid}, State};

handle_call(Request, #state{handler=Handler}=State) ->
    case Handler:handle_call(Request, State#state.handler_state) of
        {reply, Reply} ->
            {Reply, State};
        {reply, Reply, NewHandlerState} ->
            {Reply, State#state{handler_state=NewHandlerState}}
    end.


handle_cast(Message, #state{handler=Handler}=State) ->
    case Handler:handle_cast(Message, State#state.handler_state) of
        ok                        -> State;
        {new_state, HandlerState} -> State#state{handler_state=HandlerState}
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
