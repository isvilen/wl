-module(wl_display_handler).
-export([ init/1
        , handle_event/3
        ]).


init(_Ver) ->
    {ok, []}.


handle_event(error, [ObjectId, Code, Message], _State) ->
    error_logger:error_report([ {object, ObjectId}
                              , {error, Code}
                              , {message, Message}
                              ]);

handle_event(delete_id, [Id], State) ->
    {delete_id, Id, State}.
