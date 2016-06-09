-module(wl_default_handler).

-export([ new/0
        , new/1
        , init/3
        , handle_event/3
        , new_handler/2
        ]).


new() -> {?MODULE, self()}.

new(Pid) -> {?MODULE, Pid}.


init(_Parent, {Itf, Version}, Pid) ->
    {ok, {Itf, Version, Pid}}.


handle_event(Event, Args, {Itf, Version, undefined}) ->
    error_logger:info_report([ {object, {Itf, Version}}
                             , {event, Event}
                             , {args, Args}
                             ]);

handle_event(Event, [], {Itf, _, Pid}) ->
    Pid ! {Itf, self(), Event},
    ok;

handle_event(Event, Args, {Itf, _, Pid}) ->
    Pid ! {Itf, self(), Event, Args},
    ok.


new_handler(_ItfVer, {_,_,Pid}) ->
    {?MODULE, Pid}.
