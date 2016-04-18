-module(wl_connection).
-behaviour(gen_server).

-export([ start_link/2
        , stop/1
        , display/1
        , register/4
        , unregister/2
        , request/3
        , request_new_id/2
        , id_to_pid/2
        , id_to_module/2
        , id_to_module_pid/2
        , pid_to_id/2
        , init/1
        , handle_call/3
        , handle_cast/2
        , handle_info/2
        , terminate/2
        , code_change/3
        ]).

-include("wl.hrl").


start_link(SocketPath, DisplayHandler) ->
    gen_server:start_link(?MODULE, {SocketPath, DisplayHandler}, []).


stop(ConnPid) ->
    gen_server:stop(ConnPid).


display(ConnPid) ->
    gen_server:call(ConnPid, get_display).


register(ConnPid, Id, Module, Pid) ->
    gen_server:cast(ConnPid, {register, Id, Module, Pid}).


unregister(ConnPid, Pid) ->
    gen_server:cast(ConnPid, {unregister, Pid}).


request(ConnPid, Request, Fds) ->
    gen_server:cast(ConnPid, {request, Request, Fds}).


request_new_id(ConnPid, RequestFun) ->
    gen_server:call(ConnPid, {request_new_id, RequestFun}).


id_to_pid(ConnPid, Id) ->
    case gen_server:call(ConnPid, {id_to_pid, Id}) of
        {ok, Pid}       -> Pid;
        {error, Reason} -> exit(Reason)
    end.


id_to_module(ConnPid, Id) ->
    case gen_server:call(ConnPid, {id_to_module, Id}) of
        {ok, Mod}       -> Mod;
        {error, Reason} -> exit(Reason)
    end.


id_to_module_pid(ConnPid, Id) ->
    case gen_server:call(ConnPid, {id_to_module_pid, Id}) of
        {ok, ModPid}    -> ModPid;
        {error, Reason} -> exit(Reason)
    end.


pid_to_id(ConnPid, Pid) ->
    case gen_server:call(ConnPid, {pid_to_id, Pid}) of
        {ok, Id}        -> Id;
        {error, Reason} -> exit(Reason)
    end.



-record(state,{ socket
              , display
              , ids
              , pids
              , free_ids
              , next_id
              , read_ready
              , recv_data
              , recv_fds
              }).

init({SocketPath, DisplayHandler}) ->
    case wl_object:start_link(1, {wl_display, 1}, self(), DisplayHandler) of
        {ok, Display} ->
            Socket = afunix:socket(),
            init_1(Display, Socket, afunix:connect(Socket, SocketPath));
        {error, Reason} ->
            {stop, Reason}
    end.

init_1(Display, Socket, ok) ->
    {ok, #state{ socket=Socket
               , display=Display
               , ids=maps:new()
               , pids=maps:new()
               , free_ids=[]
               , next_id=2
               , recv_data= <<>>
               , recv_fds= []
               }};

init_1(_,_,{error, Reason}) ->
    {stop, Reason}.


handle_call({id_to_pid, Id}, _From, State) ->
    {reply, handle_id_to_pid(Id, State), State};

handle_call({id_to_module, Id}, _From, State) ->
    {reply, handle_id_to_module(Id, State), State};

handle_call({id_to_module_pid, Id}, _From, State) ->
    {reply, handle_id_to_module_pid(Id, State), State};

handle_call({pid_to_id, Pid}, _From, State) ->
    {reply, handle_pid_to_id(Pid, State), State};

handle_call({request_new_id, RequestFun}, _From, State) ->
    {NewId, State1} = new_id(State),
    {{Module, NewPid}, Request, Fds} = RequestFun(NewId),
    State2 = register_object(NewId, Module, NewPid, State1),
    {reply, NewId, send_request(Request, Fds, State2)};

handle_call(get_display, _From, #state{display=Display}=State) ->
    {reply, Display, State};

handle_call(_Request, _From, State) ->
    {noreply, State}.

handle_cast({register, Id, Module, Pid}, State) ->
    {noreply, register_object(Id, Module, Pid, State)};

handle_cast({unregister, Pid}, State) ->
    {noreply, unregister_object(Pid, State)};

handle_cast({request, Request, Fds}, State) ->
    {noreply, send_request(Request, Fds, State)};

handle_cast(_Msg, State) ->
    {noreply, State}.


handle_info({afunix, Ref}, #state{read_ready=Ref}=State) ->
    {noreply, socket_read(State)};

handle_info(_Msg, State) ->
    {noreply, State}.


terminate(_Reason, _State) ->
    ok.


code_change(_OldVsn, State, _Extra) ->
    {ok, State}.


new_id(#state{free_ids=[],next_id=NextId}=State) ->
    {NextId, State#state{next_id=NextId+1}};

new_id(#state{free_ids=[Id|Ids]}=State) ->
    {Id, State#state{free_ids=Ids}}.


handle_id_to_pid(Id, #state{ids=Ids}) ->
    case maps:get(Id, Ids, undefined) of
        {_, Pid}  -> {ok, Pid};
        undefined -> {error, {invalid_wl_id, Id}}
    end.


handle_id_to_module(Id, #state{ids=Ids}) ->
    case maps:get(Id, Ids, undefined) of
        {Mod, _}  -> {ok, Mod};
        undefined -> {error, {invalid_wl_id, Id}}
    end.


handle_id_to_module_pid(Id, #state{ids=Ids}) ->
    case maps:get(Id, Ids, undefined) of
        undefined -> {error, {invalid_wl_id, Id}};
        ModPid    -> {ok, ModPid}
    end.


handle_pid_to_id(Pid, #state{pids=Pids}) ->
    case maps:get(Pid, Pids, undefined) of
        undefined -> {error, {invalid_wl_pid, Pid}};
        {_, Id}   -> {ok, Id}
    end.


register_object(Id, Module, Pid, #state{pids=Pids, ids=Ids}=State) ->
    State#state{ pids=maps:put(Pid, {Module, Id}, Pids)
               , ids=maps:put(Id, {Module, Pid}, Ids)
               }.


unregister_object(Pid, #state{pids=Pids, ids=Ids, free_ids=FreeIds}=State) ->
    case maps:get(Pid, Pids, undefined) of
        undefined -> State;
        {_, Id} -> State#state{ pids=maps:remove(Pid, Pids)
                              , ids=maps:remove(Id, Ids)
                              , free_ids=[Id | FreeIds]
                              }
    end.


send_request(Request, [], #state{socket=S}=State) ->
    EncRequest = wl_wire:encode_request(Request),
    afunix:send(S, EncRequest),
    notify_read(State);

send_request(Request, Fds, #state{socket=S}=State) ->
    EncRequest = wl_wire:encode_request(Request),
    afunix:send(S, Fds, EncRequest),
    notify_read(State).


notify_read(#state{socket=S,read_ready=undefined}=State) ->
    State#state{read_ready=afunix:monitor(S, read)};

notify_read(State) ->
    State.


socket_read(#state{socket=S}=State) ->
    socket_read(afunix:recv(S, 1000), State).

socket_read({ok, Bytes}, #state{recv_data=Data}=State) ->
    NewData = <<Data/binary,Bytes/binary>>,
    socket_read(handle_recv_data(State#state{recv_data=NewData}));

socket_read({ok, Fds, Bytes}, #state{recv_data=Data, recv_fds=OldFds}=State) ->
    NewFds=OldFds ++ Fds,
    NewData = <<Data/binary,Bytes/binary>>,
    socket_read(handle_recv_data(State#state{ recv_data=NewData
                                            , recv_fds=NewFds}));

socket_read({error, eagain}, State) ->
    notify_read(State#state{read_ready=undefined});

socket_read({error, Error}, _State) ->
    exit({socket_error, Error}).


handle_recv_data(#state{recv_data=Data,recv_fds=Fds}=State) ->
    case wl_wire:decode_event(Data) of
        {#wl_event{sender=Id}=Event, NewData} ->
            {ok, ModPid} = handle_id_to_module_pid(Id, State),
            NewFds = wl_object:notify(Event#wl_event{sender=ModPid}, Fds),
            handle_recv_data(State#state{recv_data=NewData, recv_fds=NewFds});
        incomplete ->
            State
    end.
