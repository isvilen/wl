-module(wl_display_handler).
-export([ init/1
        , handle_event/3
        ]).


init(_Ver) ->
    {ok, []}.


handle_event(error, [ObjectId, Code, Message], State) ->
    io:format("wl_display_error: object_id=~p, code=~p, message=~p~n",
              [ObjectId, Code, Message]),
    {new_state, State};

handle_event(delete_id, [Id], State) ->
    {delete_id, Id, State}.
