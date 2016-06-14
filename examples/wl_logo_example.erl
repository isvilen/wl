-module(wl_logo_example).
-export([main/0]).

-define(W,266).
-define(H,266).
-define(SIZE,?W*?H*4).
-define(STRIDE,?W*4).

-define(ESC_KEY,1).


main() ->
    {ok, Conn} = wl:connect(),

    Compositor = wl:bind(Conn, wl_compositor),
    Shm = wl:bind(Conn, wl_shm),
    Shell = wl:bind(Conn, wl_shell),
    _Seat = wl:bind(Conn, wl_seat),

    Fd = wayland_logo_fd(),
    Pool = wl_shm:create_pool(Shm, handler(), Fd, ?SIZE),
    Buf = wl_shm_pool:create_buffer(Pool, handler(), 0, ?W, ?H, ?STRIDE, 0),

    Surface = wl_compositor:create_surface(Compositor, handler()),
    SSurface = wl_shell:get_shell_surface(Shell, handler(), Surface),
    ok = wl_shell_surface:set_toplevel(SSurface),

    ok = wl_surface:attach(Surface, Buf, 0, 0),
    ok = wl_surface:damage(Surface, 0, 0, ?W, ?H),
    ok = wl_surface:commit(Surface),

    event_loop(),

    wl:disconnect(Conn).


event_loop() ->
    receive
        {wl_shell_surface, SSurface, ping, [Arg]} ->
            ok = wl_shell_surface:pong(SSurface, Arg),
            event_loop();

        {wl_keyboard, _, key_released, _Serial, _Time, ?ESC_KEY} ->
            ok;

        Msg ->
            io:format("~p~n", [Msg]),
            event_loop()
    end.


wayland_logo_fd() ->
    Logo = code:where_is_file("wayland_logo.zlib"),
    {ok, Data} = file:read_file(Logo),
    MemFd = memfd:create(),
    ok = memfd:pwrite(MemFd, 0, zlib:uncompress(Data)),
    afunix:fd_from_binary(memfd:fd_to_binary(MemFd)).


handler() ->
    wl_default_handler:new().
