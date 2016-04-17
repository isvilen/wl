-module(wl).

-export([ connect/0
        , connect/1
        ]).

connect() ->
    connect(default_socket_path()).


connect(SocketPath) ->
    wl_connection:start_link(SocketPath, wl_display_handler).


%% Internal functions

default_socket_path() ->
    case os:getenv("XDG_RUNTIME_DIR") of
        false ->
            error(xdg_runtime_dir_not_set);
        Dir ->
            Display = os:getenv("WAYLAND_DISPLAY", "wayland-0"),
            list_to_binary(filename:join([Dir, Display]))
    end.
