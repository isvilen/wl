-module(wl_display_handler).
-export([ init/2
        , handle_event/3
        ]).


init(Connection, _ItfVer) ->
    {ok, Connection}.


handle_event(error, [ObjectId, Code, Message], _Connection) ->
    error_logger:error_report([ {object, ObjectId}
                              , {error, Code}
                              , {message, Message}
                              ]);

handle_event(delete_id, [Id], Connection) ->
    Pid = wl_connection:id_to_pid(Connection, Id),
    ok = proc_lib:stop(Pid).
