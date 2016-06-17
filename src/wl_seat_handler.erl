-module(wl_seat_handler).
-export([ new/0
        , new/1
        , new/2
        , capabilities/1
        , name/1
        , keyboard/1
        , pointer/1
        , touch/1
        , init/3
        , handle_event/3
        , handle_call/2
        ]).


new() ->
    new(self()).

new(NotifyPid) when is_pid(NotifyPid); NotifyPid =:= undefined ->
    {?MODULE, {NotifyPid, [keyboard, pointer, touch]}}.

new(NotifyPid, Capabilities) ->
    {?MODULE, {NotifyPid, Capabilities}}.


capabilities(Seat) ->
    wl_object:call(Seat, capabilities).


name(Seat) ->
    wl_object:call(Seat, name).


keyboard(Seat) ->
    wl_object:call(Seat, keyboard).


pointer(Seat) ->
    wl_object:call(Seat, pointer).


touch(Seat) ->
    wl_object:call(Seat, touch).


-record(state,{ capabilities
              , name = default
              , notify
              , devices
              }).

init(_Parent, _ItfVersion, {Pid, Capabilities}) ->
    {ok, #state{notify=Pid, devices=[{C,undefined} || C <- Capabilities]}}.


handle_event(capabilities, [Capabilities],
             #state{devices=Devices,notify=Pid}=State) ->
    NewDevices=create_devices(Devices, Capabilities, Pid),
    {new_state, State#state{capabilities=Capabilities,devices=NewDevices}};

handle_event(name, [Name], State) ->
    {new_state, State#state{name=list_to_binary(binary_to_list(Name))}}.


handle_call(capabilities, #state{capabilities=Capabilities}) ->
    {reply, Capabilities};

handle_call(name, #state{name=Name}) ->
    {reply, Name};

handle_call(Device, #state{devices=Devices}) when Device == keyboard
                                                ; Device == pointer
                                                ; Device == touch ->
    {reply, get_device(Device, Devices)}.



create_devices(Devices, Capabilities, NotifyPid) ->
    lists:map(fun (Device) -> create_device(Device, Capabilities, NotifyPid) end
             ,Devices).

create_device({Device, undefined}, Capabilities, NotifyPid) ->
    case lists:member(Device, Capabilities) of
        true  -> {Device, create_device(Device, NotifyPid)};
        false -> {Device, undefined}
    end;

create_device(Device, _, _) ->
    Device.

create_device(keyboard, NotifyPid) ->
    wl_seat:get_keyboard(self(), wl_keyboard_handler:new(NotifyPid));

create_device(pointer, NotifyPid) ->
    wl_seat:get_pointer(self(), wl_pointer_handler:new(NotifyPid));

create_device(touch, NotifyPid) ->
    wl_seat:get_touch(self(), wl_default_handler:new(NotifyPid)).


get_device(Device, Devices) ->
    case lists:keyfind(Device, 1, Devices) of
        {Device, Pid} -> Pid;
        false         -> undefined
    end.
