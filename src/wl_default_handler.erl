-module(wl_default_handler).

-export([ init/1
        , init/2
        , handle_event/3
        , new_handler/3
        ]).

init({Itf, Version}) ->
    {ok, {Itf, Version, undefined}}.


init({Itf, Version}, Pid) ->
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


new_handler(_Itf, _Ver, {_,_,Pid}) ->
    {?MODULE, Pid}.
