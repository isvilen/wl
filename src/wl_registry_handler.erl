-module(wl_registry_handler).
-export([ init/1
        , handle_event/3
        , handle_call/2
        ]).


init(_Ver) ->
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
