-module(wl_registry_handler).
-export([ globals/1
        , bind/3
        , init/2
        , handle_event/3
        , handle_call/2
        ]).


globals(Registry) ->
    wl_object:call(Registry, globals).


bind(Registry, Itf, Handler) ->
    case wl_object:call(Registry, {globals, Itf}) of
        [] ->
            not_supported;
        [NameVer] ->
            bind_1(Registry, Itf, NameVer, Handler);
        Values ->
            [bind_1(Registry, Itf, NameVer, Handler) || NameVer <- Values]
    end.


bind_1(Registry, Itf, NameVer, Handler) when is_pid(Handler) ->
    bind_1(Registry, Itf, NameVer, {wl_default_handler, Handler});

bind_1(Registry, Itf, {Name, Ver}, Handler) ->
    V = min(Itf:interface_info(version), Ver),
    wl_registry:bind(Registry, Name, {Itf, V, Handler}).


init(_Parent, _ItfVer) ->
    {ok, #{}}.


handle_event(global, [Name, ItfStr, Ver], Globals) ->
    Itf = list_to_atom(binary_to_list(ItfStr)),
    {new_state, maps:put(Name, {Itf, Ver}, Globals)};

handle_event(global_remove, [Name], Globals) ->
    {new_state, maps:remove(Name, Globals)}.


handle_call(globals, Globals) ->
    {reply, Globals};

handle_call({globals, Itf}, Globals) ->
    Fun = fun (K, {I, V}, Acc) when I == Itf -> [{K, V} | Acc];
              (_, _, Acc) -> Acc
          end,
    {reply, maps:fold(Fun, [], Globals)}.
