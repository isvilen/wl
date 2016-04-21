-module(wl_callback_handler).

-export([ init/3
        , handle_event/3
        ]).

init(_Parent, _ItfVer, {Pid, Data}) ->
    {ok, {Pid, Data}};

init(_Parent, _ItfVer, Pid) ->
    {ok, Pid}.


handle_event(done, [CallbackData], {Pid, Data}) ->
    Pid ! {done, self(), CallbackData, Data},
    ok;

handle_event(done, [CallbackData], Pid) ->
    Pid ! {done, self(), CallbackData},
    ok.
