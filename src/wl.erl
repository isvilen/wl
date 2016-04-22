-module(wl).

-export([ connect/0
        , connect/1
        , disconnect/1
        , bind/2
        , bind/3
        , find/2
        ]).

connect() ->
    connect(default_socket_path()).


connect(SocketPath) ->
    case wl_connection:start_link(SocketPath, wl_display_handler) of
        {ok, Conn} ->
            % make wl_registry singleton object available with id 2
            Display = wl_connection:display(Conn),
            _ = wl_display:get_registry(Display, wl_registry_handler),
            case wl_display_handler:sync(Display) of
                ok      -> {ok, Conn};
                timeout -> wl_connection:stop(Conn), {error, timeout}
            end;
        Error ->
            Error
    end.


disconnect(Conn) ->
    wl_connection:stop(Conn).


bind(Conn, Itf) ->
    bind(Conn, Itf, wl_default_handler).


bind(Conn, Itf, Pid) when is_pid(Pid) ->
    bind(Conn, Itf, {wl_default_handler, Pid});

bind(Conn, Itf, Handler) ->
    Registry = wl_connection:id_to_pid(Conn, 2),
    case wl_registry_handler:bind(Registry, Itf, Handler) of
        {ok, Result}    -> Result;
        {error, Reason} -> error(Reason)
    end.


find(Conn, wl_display) ->
    wl_connection:display(Conn);

find(Conn, wl_registry) ->
    wl_connection:id_to_pid(Conn ,2);

find(Conn, Itf) ->
    Registry = wl_connection:id_to_pid(Conn, 2),
    case wl_registry_handler:find(Registry, Itf) of
        {ok, Result}    -> Result;
        {error, Reason} -> error(Reason)
    end.


%% Internal functions

default_socket_path() ->
    case os:getenv("XDG_RUNTIME_DIR") of
        false ->
            error(xdg_runtime_dir_not_set);
        Dir ->
            Display = os:getenv("WAYLAND_DISPLAY", "wayland-0"),
            list_to_binary(filename:join([Dir, Display]))
    end.
