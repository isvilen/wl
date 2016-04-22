-module(wl_registry_handler).
-export([ globals/1
        , bind/3
        , find/2
        , init/2
        , handle_event/3
        , handle_call/2
        ]).


globals(Registry) ->
    wl_object:call(Registry, globals).


bind(Registry, Itf, Handler) ->
    wl_object:call(Registry, {bind, Itf, Handler}).


find(Registry, Itf) ->
    wl_object:call(Registry, {find, Itf}).


-record(state,{globals,bindings}).

init(_Parent, _ItfVer) ->
    {ok, #state{globals=#{},bindings=#{}}}.


handle_event(global, [Name, ItfStr, Ver], #state{globals=Globals}=State) ->
    Itf = list_to_atom(binary_to_list(ItfStr)),
    {new_state, State#state{globals=maps:put(Name, {Itf, Ver}, Globals)}};

handle_event(global_remove, [Name], #state{globals=Globals}=State) ->
    {new_state, State#state{globals=maps:remove(Name, Globals)}}.


handle_call(globals, #state{globals=Globals}) ->
    {reply, Globals};

handle_call({bind, Itf, Handler}, State) ->
    case find_globals(State#state.globals, Itf) of
        [] ->
            {reply, {error, {not_supported, Itf}}};
        [NameVer] ->
            Pid = do_bind(Itf, NameVer, Handler),
            NewBindings = register_binding(Itf, Pid, State#state.bindings),
            {reply, {ok, Pid}, State#state{bindings=NewBindings}};
        Values ->
            Pids = [do_bind(Itf, NameVer, Handler) || NameVer <- Values],
            NewBindings = register_binding(Itf, Pids, State#state.bindings),
            {reply, {ok, Pids, State#state{bindings=NewBindings}}}
    end;

handle_call({find, Itf}, #state{bindings=Bindings}) ->
    case maps:get(Itf, Bindings, undefined) of
        undefined -> {reply, {error, not_binded}};
        [Pid]     -> {reply, {ok, Pid}};
        Pids      -> {reply, {ok, Pids}}
    end.


find_globals(Globals, Itf) ->
    Fun = fun (K, {I, V}, Acc) when I == Itf -> [{K, V} | Acc];
              (_, _, Acc) -> Acc
          end,
    maps:fold(Fun, [], Globals).


do_bind(Itf, {Name, Ver}, Handler) ->
    V = min(Itf:interface_info(version), Ver),
    wl_registry:bind(self(), Name, {Itf, V, Handler}).


register_binding(Itf, PidOrPids, Bindings) ->
    Values = maps:get(Itf, Bindings, []),
    NewValues = if
                    is_list(PidOrPids) -> PidOrPids ++ Values;
                    true               -> [PidOrPids | Values]
                end,
    maps:put(Itf, NewValues, Bindings).
