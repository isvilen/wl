-module(wl_callback_handler).

-export([ notify/0
        , notify/1
        , wait/2
        , wait_callback_data/2
        , init/3
        , handle_event/3
        ]).


notify() -> {?MODULE, self()}.

notify(Data) -> {?MODULE, {self(), Data}}.


wait(Pid, Timeout) ->
    receive
        {done, Pid, _, Data} -> Data
    after
        Timeout -> timeout
    end.


wait_callback_data(Pid, Timeout) ->
    receive
        {done, Pid, CallbackData, Data} -> {Data, CallbackData}
    after
        Timeout -> timeout
    end.


init(_Parent, _ItfVer, {Pid, Data}) ->
    {ok, {Pid, Data}};

init(_Parent, _ItfVer, Pid) ->
    {ok, Pid}.


handle_event(done, [CallbackData], {Pid, Data}) ->
    Pid ! {done, self(), CallbackData, Data},
    ok;

handle_event(done, [CallbackData], Pid) ->
    Pid ! {done, self(), CallbackData, ok},
    ok.
