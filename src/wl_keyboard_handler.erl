-module(wl_keyboard_handler).
-export([ new/0
        , new/1
        , init/3
        , handle_event/3
        ]).

new() -> {?MODULE, self()}.

new(NotifyPid) -> {?MODULE, NotifyPid}.

-record(state,{ keymap_format
              , keymap_state
              , repeat_info
              , serial
              , notify
              }).

init(_Parent, _ItfVersion, Pid) ->
    {ok, #state{notify=Pid}}.


handle_event(keymap, [xkb_v1, AfUnixFd, Size], State) ->
    Fd = memfd:new(AfUnixFd),
    {ok, Keymap} = file:pread(Fd, bof, Size),
    {new_state, State#state{ keymap_format = xkb
                           , keymap_state  = xkb:init(xkb_v1, Keymap)
                           }};

handle_event(keymap, [no_keymap, _Fd, _Size], State) ->
    {new_state, State#state{keymap_format=no_keymap}};

handle_event(repeat_info, [Rate, Delay], State) ->
    {new_state, State#state{repeat_info={Rate,Delay}}};

handle_event(modifiers, [Serial, ModsDepressed, ModsLatched, ModsLocked, Group]
            ,#state{keymap_format=xkb, keymap_state=KeymapState}=State) ->
    NewKeymapState = xkb:update_modifiers( ModsDepressed
                                         , ModsLatched
                                         , ModsLocked
                                         , Group
                                         , KeymapState),
    {new_state, State#state{keymap_state=NewKeymapState, serial=Serial}};

handle_event(modifiers, [Serial, _, _, _, _]
            ,#state{keymap_format=no_keymap}=State) ->
    {new_state, State#state{serial=Serial}};

handle_event(enter, [Serial, Surface, _Keys], #state{notify=NotifyPid}=State) ->
    NotifyPid ! {wl_keyboard, self(), enter, Serial, Surface},
    {new_state, State#state{serial=Serial}};

handle_event(key, [Serial, Time, Key, pressed], #state{ keymap_format=xkb
                                                      , keymap_state=KeymapState
                                                      , notify=NotifyPid
                                                      }=State) ->
    {Keys, NewKeymapState} = xkb:key_pressed(Key, KeymapState),
    send_keys(NotifyPid, pressed, Serial, Time, Keys),
    {new_state, State#state{keymap_state=NewKeymapState, serial=Serial}};

handle_event(key, [Serial, Time, Key, released], #state{ keymap_format=xkb
                                                       , keymap_state=KeymapState
                                                       , notify=NotifyPid
                                                       }=State) ->
    {Keys, NewKeymapState} = xkb:key_released(Key, KeymapState),
    send_keys(NotifyPid, released, Serial, Time, Keys),
    {new_state, State#state{keymap_state=NewKeymapState, serial=Serial}};

handle_event(key, [Serial, _Time, _Key, _KeyState]
            ,#state{keymap_format=no_keymap}=State) ->
    {new_state, State#state{serial=Serial}};

handle_event(leave, [Serial, Surface], #state{notify=NotifyPid}=State) ->
    NotifyPid ! {wl_keyboard, self(), leave, Serial, Surface},
    {new_state, State#state{serial=Serial}}.


send_keys(NotifyPid, Event, Serial, Time, Keys) ->
    lists:foreach(
      fun (Key) ->
              NotifyPid ! {wl_keyboard, self(), Event, Serial, Time, Key}
      end, Keys).
