-module(wl_logo).
-export([main/0]).

-define(WIDTH,266).
-define(HEIGHT,266).
-define(SIZE,?WIDTH*?HEIGHT*4).
-define(STRIDE,?WIDTH*4).

-define(ESC_KEY,1).


main() ->
    {ok, Conn} = wl:connect(),
    Compositor = wl:bind(Conn, wl_compositor),
    Shm = wl:bind(Conn, wl_shm),
    Shell = wl:bind(Conn, wl_shell),
    Seat = wl:bind(Conn, wl_seat),
    _ = wl_seat:get_keyboard(Seat, {wl_default_handler, self()}),

    Fd = afunix:fd_from_binary(load_image()),
    Pool = wl_shm:create_pool(Shm, wl_default_handler, Fd, ?SIZE),

    Buf = wl_shm_pool:create_buffer(Pool, wl_default_handler, 0,
                                    ?WIDTH, ?HEIGHT, ?STRIDE, 0),

    Surface = wl_compositor:create_surface(Compositor, wl_default_handler),
    SSurface = wl_shell:get_shell_surface(Shell, {wl_default_handler, self()},
                                          Surface),
    ok = wl_shell_surface:set_toplevel(SSurface),

    ok = wl_surface:attach(Surface, Buf, 0, 0),
    ok = wl_surface:damage(Surface, 0, 0, ?WIDTH, ?HEIGHT),
    ok = wl_surface:commit(Surface),

    loop(),

    wl_connection:stop(Conn).


loop() ->
    receive
        {wl_shell_surface, Pid, ping, [Arg]} ->
            ok = wl_shell_surface:pong(Pid, Arg),
            loop();
        {wl_keyboard, _, key, [_Serial, _Time, ?ESC_KEY, released]} ->
            ok;
        Msg ->
            io:format("~p~n", [Msg]),
            loop()
    end.


load_image() ->
    Logo = code:where_is_file("wayland_logo.zlib"),
    {ok, Data} = file:read_file(Logo),
    MemFd = memfd:create(),
    ok = memfd:pwrite(MemFd, 0, zlib:uncompress(Data)),
    memfd:fd_to_binary(MemFd).
