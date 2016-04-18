-module(wl).

-export([ connect/0
        , connect/1
        , disconnect/1
        , sync/1
        , globals/1
        , bind/2
        , bind/3
        ]).

connect() ->
    connect(default_socket_path()).


connect(SocketPath) ->
    case wl_connection:start_link(SocketPath, wl_display_handler) of
        {ok, Conn} ->
            % make wl_registry singleton object available
            Display = wl_connection:display(Conn),
            _ = wl_display:get_registry(Display, wl_registry_handler),
            case sync(Conn, 5000) of
                ok      -> {ok, Conn};
                timeout -> wl_connection:stop(Conn), {error, timeout}
            end;
        Error ->
            Error
    end.


disconnect(Conn) ->
    wl_connection:stop(Conn).


sync(Conn) ->
    sync(Conn, infinity).

sync(Conn, Timeout) ->
    Display = wl_connection:display(Conn),
    CallBackPid = wl_display:sync(Display, {wl_callback_handler, self()}),
    receive
        {done, CallBackPid, _} -> ok
    after
        Timeout -> timeout
    end.


globals(Conn) ->
    % wl_registry singleton object always has ID=2
    Registry = wl_connection:id_to_pid(Conn ,2),
    wl_object:call(Registry, globals).


bind(Conn, Itf) ->
    bind(Conn, Itf, wl_default_handler).

bind(Conn, Itf, Handler) ->
    Registry = wl_connection:id_to_pid(Conn ,2),
    case wl_object:call(Registry, {globals, Itf}) of
        [] ->
            not_supported;
        [{Name, Ver}] ->
            bind_1(Registry, Itf, Name, Ver, Handler);
        Values ->
            [bind_1(Registry, Itf, Name, Ver, Handler) || {Name, Ver} <- Values]
    end.


bind_1(Registry, Itf, Name, Ver, Handler) when is_pid(Handler) ->
    bind_1(Registry, Itf, Name, Ver, {wl_default_handler, Handler});

bind_1(Registry, Itf, Name, Ver, Handler) ->
    V = min(Itf:version(), Ver),
    wl_registry:bind(Registry, Name, {Itf, V, Handler}).


%% Internal functions

default_socket_path() ->
    case os:getenv("XDG_RUNTIME_DIR") of
        false ->
            error(xdg_runtime_dir_not_set);
        Dir ->
            Display = os:getenv("WAYLAND_DISPLAY", "wayland-0"),
            list_to_binary(filename:join([Dir, Display]))
    end.
