-module(wl_xkb).
-export([init/2, update_modifiers/5, key_pressed/2, key_released/2]).

init(Format, Binary) when is_binary(Binary) ->
    init(Format, binary_to_list(Binary));

init(xkb_v1, String) ->
    {ok, Tokens, _} = wl_xkb1_lexer:string(String),
    {ok, Keymap} = wl_xkb1_parser:parse(Tokens),
    error_logger:info_report([ {wl_xkb, xkb_v1}
                             , {keymap, Keymap}
                             ]),
    Keymap.


update_modifiers(Keymap, _ModsDepressed, _ModsLatched, _ModsLocked, _Group) ->
    Keymap.


key_pressed(Keymap, Key) ->
    {[Key], Keymap}.


key_released(Keymap, Key) ->
    {[Key], Keymap}.
