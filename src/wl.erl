-module(wl).

-export([ connect/0
        , connect/1
        , disconnect/1
        , bind/2
        , bind/3
        , find/2
        ]).

-define(SYNC_TIMEOUT,5000).


connect() ->
    connect(default_socket_path()).


connect(SocketPath) ->
    case wl_connection:start_link(SocketPath, wl_display_handler) of
        {ok, Conn} -> init_connection(Conn);
        Error      -> Error
    end.


disconnect(Conn) ->
    wl_connection:stop(Conn).


bind(Conn, Itf) ->
    bind(Conn, Itf, wl_default_handler).


bind(Conn, Itf, Pid) when is_pid(Pid) ->
    bind(Conn, Itf, {wl_default_handler, Pid});

bind(Conn, Itf, Handler) ->
    case wl_registry_handler:bind(get_registry(Conn), Itf, Handler) of
        {ok, Result}    -> Result;
        {error, Reason} -> error(Reason)
    end.


find(Conn, wl_display) ->
    wl_connection:display(Conn);

find(Conn, wl_registry) ->
    get_registry(Conn);

find(Conn, Itf) ->
    case wl_registry_handler:find(get_registry(Conn), Itf) of
        {ok, Result}    -> Result;
        {error, Reason} -> error(Reason)
    end.


%% Internal functions

init_connection(Conn) ->
    Display = wl_connection:display(Conn),

    % make wl_registry singleton object available with id 2
    _ = wl_display:get_registry(Display, wl_registry_handler),

    case wl_display_handler:sync(Display, ?SYNC_TIMEOUT) of
        ok      -> {ok, Conn};
        timeout -> wl_connection:stop(Conn), {error, timeout}
    end.


get_registry(Conn) ->
    wl_connection:id_to_pid(Conn, 2).


default_socket_path() ->
    case os:getenv("XDG_RUNTIME_DIR") of
        false ->
            error(xdg_runtime_dir_not_set);
        Dir ->
            Display = os:getenv("WAYLAND_DISPLAY", "wayland-0"),
            list_to_binary(filename:join([Dir, Display]))
    end.
