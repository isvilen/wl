-module(wl_pointer_handler).
-export([ new/0
        , new/1
        , init/3
        , handle_event/3
        ]).

-define(BTN_LEFT,   16#110).
-define(BTN_RIGHT,  16#111).
-define(BTN_MIDDLE, 16#112).
-define(BTN_SIDE,   16#113).
-define(BTN_EXTRA,  16#114).
-define(BTN_FORWARD,16#115).
-define(BTN_BACK,   16#116).
-define(BTN_TASK,   16#117).

new() -> {?MODULE, self()}.

new(NotifyPid) -> {?MODULE, NotifyPid}.

-record(state,{ serial
              , notify
              }).

init(_Parent, _ItfVersion, Pid) ->
    {ok, #state{notify=Pid}}.


handle_event(enter, [Serial, Surface, X, Y], #state{notify=NotifyPid}=State) ->
    NotifyPid ! {wl_pointer, self(), enter, Serial, Surface, {X,Y}},
    {new_state, State#state{serial=Serial}};

handle_event(motion, [Time, X, Y], #state{notify=NotifyPid}) ->
    NotifyPid ! {wl_pointer, self(), motion, Time, {X,Y}},
    ok;

handle_event(button, [Serial, Time, Btn, BtnState], #state{notify=NotifyPid}) ->
    NotifyPid ! {wl_pointer, self(), BtnState, Serial, Time, button(Btn)},
    ok;

handle_event(axis, [Time, Axis, Value], #state{notify=NotifyPid}) ->
    NotifyPid ! {wl_pointer, self(), Axis, Time, Value},
    ok;

handle_event(frame, [], #state{notify=NotifyPid}) ->
    NotifyPid ! {wl_pointer, self(), frame},
    ok;

handle_event(axis_source, [Source], #state{notify=NotifyPid}) ->
    NotifyPid ! {wl_pointer, self(), source, Source},
    ok;

handle_event(axis_stop, [Time, Axis], #state{notify=NotifyPid}) ->
    NotifyPid ! {wl_pointer, self(), stop, Time, Axis},
    ok;

handle_event(axis_discrete, [Axis, Discrete], #state{notify=NotifyPid}) ->
    NotifyPid ! {wl_pointer, self(), discrete, Axis, Discrete},
    ok;

handle_event(leave, [Serial, Surface], #state{notify=NotifyPid}=State) ->
    NotifyPid ! {wl_pointer, self(), leave, Serial, Surface},
    {new_state, State#state{serial=Serial}}.


button(?BTN_LEFT)    -> button_left;
button(?BTN_RIGHT)   -> button_right;
button(?BTN_MIDDLE)  -> button_middle;
button(?BTN_SIDE)    -> button_side;
button(?BTN_EXTRA)   -> button_extra;
button(?BTN_FORWARD) -> button_forward;
button(?BTN_BACK)    -> button_back;
button(?BTN_TASK)    -> button_task;
button(Btn)          -> {button, Btn}.
