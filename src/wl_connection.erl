-module(wl_connection).
-behaviour(gen_server).

-export([ start_link/2
        , stop/1
        , display/1
        , free_id/2
        , request/3
        , id_to_pid/2
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


free_id(ConnPid, Id) ->
    gen_server:cast(ConnPid, {free_id, Id}).


request(ConnPid, Request, Fds) ->
    gen_server:call(ConnPid, {request, Request, Fds}).


id_to_pid(ConnPid, Id) ->
    case gen_server:call(ConnPid, {id_to_pid, Id}) of
        {ok, Pid}       -> Pid;
        {error, Reason} -> exit(Reason)
    end.


-record(state,{ socket
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
               , ids=maps:from_list([{1, {wl_display, Display}}])
               , pids=maps:from_list([{Display, {wl_display, 1}}])
               , free_ids=[]
               , next_id=2
               , recv_data= <<>>
               , recv_fds= []
               }};

init_1(_,_,{error, Reason}) ->
    {stop, Reason}.


handle_call({id_to_pid, Id}, _From, State) ->
    handle_id_to_pid(Id, State);

handle_call({request, Request, Fds}, _From, State) ->
    handle_request(Request, Fds, State);

handle_call(get_display, _From, State) ->
    handle_get_display(State);

handle_call(_Request, _From, State) ->
    {noreply, State}.

handle_cast({free_id, Id}, State) ->
    {noreply, handle_free_id(Id, State)};

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


handle_id_to_pid(Id, #state{ids=Ids}=State) ->
    case maps:get(Id, Ids, undefined) of
        {_, Pid}  -> {reply, {ok, Pid}, State};
        undefined -> {reply, {error, {invalid_wl_id, Id}}, State}
    end.

handle_request(Request, Fds, State) ->
    {Reply, Args, NewState} = handle_request_args(Request, State),
    {reply, Reply, send_request(Request#wl_request{args=Args}, Fds, NewState)}.


handle_get_display(#state{ids=#{1:={_,Display}}}=State) ->
    {reply, Display, State}.


handle_free_id(Id, #state{pids=Pids, ids=Ids, free_ids=FreeIds}=State) ->
    case maps:get(Id, Ids, undefined) of
        undefined -> State;
        {_, Pid} -> State#state{ pids=maps:remove(Pid, Pids)
                               , ids=maps:remove(Id, Ids)
                               , free_ids=[Id | FreeIds]
                               }
    end.


handle_request_args(#wl_request{sender=Id,args={Args1, Arg, Args2}},
                    #state{ids=Ids,pids=Pids}=State) ->
    {NewId, State1} = new_id(State),
    {Itf, Handler, NewArgs} = handle_new_id_args(Args1, Arg, Args2, NewId, Pids),
    {_, ParentPid} = maps:get(Id, Ids),
    Pid = wl_object:start_child(ParentPid, Itf, NewId, Handler),
    {Pid, NewArgs, register_object(NewId, Itf, Pid, State1)};

handle_request_args(#wl_request{args=Args}, #state{pids=Pids}=State)->
    {ok, [request_arg(Arg, Pids) || Arg <- Args], State}.


handle_new_id_args(Args1, {new_id, {Itf, Ver, Handler}}, Args2, NewId, Pids) ->
    NewArgs1 = [request_arg(Arg, Pids) || Arg <- Args1],
    NewArgs2 = [request_arg(Arg, Pids) || Arg <- Args2],
    NewIdArgs = [ wl_wire:encode_string(list_to_binary(atom_to_list(Itf)))
                , wl_wire:encode_uint(Ver)
                , wl_wire:encode_object(NewId)
                ],
    {Itf, Handler, NewArgs1 ++ NewIdArgs ++ NewArgs2};

handle_new_id_args(Args1, {new_id, Itf, Handler}, Args2, NewId, Pids) ->
    NewArgs1 = [request_arg(Arg, Pids) || Arg <- Args1],
    NewArgs2 = [request_arg(Arg, Pids) || Arg <- Args2],
    {Itf, Handler, NewArgs1 ++ [wl_wire:encode_object(NewId) | NewArgs2]}.


request_arg({id, Pid}, Pids) ->
    {_, Id} = maps:get(Pid, Pids),
    wl_wire:encode_object(Id);

request_arg(Arg, _) ->
    Arg.


new_id(#state{free_ids=[],next_id=NextId}=State) ->
    {NextId, State#state{next_id=NextId+1}};

new_id(#state{free_ids=[Id|Ids]}=State) ->
    {Id, State#state{free_ids=Ids}}.


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
    socket_read(afunix:recv(S, 1024), State).

socket_read({ok, Bytes}, #state{recv_data=Data}=State) ->
    NewData = <<Data/binary,Bytes/binary>>,
    socket_read(handle_recv_data(State#state{recv_data=NewData}));

socket_read({ok, Fds, Bytes}, #state{recv_data=Data, recv_fds=OldFds}=State) ->
    NewFds = OldFds ++ Fds,
    NewData = <<Data/binary,Bytes/binary>>,
    socket_read(handle_recv_data(State#state{ recv_data=NewData
                                            , recv_fds=NewFds}));

socket_read({error, eagain}, State) ->
    notify_read(State#state{read_ready=undefined});

socket_read({error, Error}, _State) ->
    exit({socket_error, Error}).


handle_recv_data(#state{recv_data=Data}=State) ->
    handle_event(wl_wire:decode_event(Data), State).


handle_event({#wl_event{sender=Id}=Event, Data}, #state{recv_fds=Fds}=State) ->
    ModPid = maps:get(Id, State#state.ids),
    {NewObjects, NewFds} = wl_object:notify(Event#wl_event{sender=ModPid}, Fds),
    State1 = register_objects(NewObjects, State),
    handle_recv_data(State1#state{recv_data=Data, recv_fds=NewFds});

handle_event(incomplete, State) ->
    State.


register_object(Id, Module, Pid, #state{pids=Pids, ids=Ids}=State) ->
    State#state{ pids=maps:put(Pid, {Module, Id}, Pids)
               , ids=maps:put(Id, {Module, Pid}, Ids)
               }.


register_objects([], State) ->
    State;

register_objects([{Id, Module, Pid} | Rest], State) ->
    register_objects(Rest, register_object(Id, Module, Pid, State)).
