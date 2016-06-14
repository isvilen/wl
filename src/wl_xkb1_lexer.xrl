Definitions.

Digit = [0-9]

HexDigit = [0-9a-fA-F]

Letter = [A-Za-z]

Identifier = ({Letter}|{Digit}|_)

WS  = [\000-\s]


Rules.

{Letter}{Identifier}* :
    {token, to_keyword_or_identifier(TokenChars,TokenLine)}.

<[^>\000-\s]*> :
    {token, {keyname, TokenLine, strip(TokenChars,TokenLen)} }.

"(\\.|[^"])*" :
    {token, {string, TokenLine, to_string(strip(TokenChars,TokenLen))} }.

0x({HexDigit}+) :
    {token, {integer, TokenLine, hex_to_integer(TokenChars)}}.

{Digit}+ :
    {token, {integer, TokenLine, list_to_integer(TokenChars)}}.

{Digit}+\.{Digit}+ :
    {token, {float, TokenLine, list_to_float(TokenChars)}}.

(//[^\n]*)|(#[^\n]*)|{WS}+ :
    skip_token.

[\[\](){}=!+-/*//~;.,] :
    {token, {list_to_atom(TokenChars), TokenLine}}.


Erlang code.

strip(TokenChars,TokenLen) ->
    lists:sublist(TokenChars, 2, TokenLen - 2).


to_string([$\\,C1,C2,C3|Cs]) when C1 >= $0, C1 =< $7
                               ,  C2 >= $0, C2 =< $7
                               ,  C3 >= $0, C3 =< $7 ->
    [((C1 - $0)*8 + (C2 - $0))*8 + (C3 - $0) | to_string(Cs)];

to_string([$\\,C1,C2|Cs]) when C1 >= $0, C1 =< $7
                            ,  C2 >= $0, C2 =< $7 ->
    [(C1 - $0)*8 + (C2 - $0) | to_string(Cs)];

to_string([$\\,C1|Cs]) when C1 >= $0, C1 =< $7 ->
    [(C1 - $0) | to_string(Cs)];

to_string([$\\,C|Cs]) ->
    [escape_char(C) | to_string(Cs)];

to_string([C|Cs]) ->
    [C | to_string(Cs)];

to_string([]) ->
    [].


escape_char($n) -> $\n;   %\n = LF
escape_char($r) -> $\r;   %\r = CR
escape_char($t) -> $\t;   %\t = TAB
escape_char($v) -> $\v;   %\v = VT
escape_char($b) -> $\b;   %\b = BS
escape_char($f) -> $\f;   %\f = FF
escape_char($e) -> $\e;   %\e = ESC
escape_char(C)  -> C.


hex_to_integer("0x" ++ Chars) ->
    {ok,[V],[]} = io_lib:fread("~16u", Chars), V.


to_keyword_or_identifier("action", TokenLine) ->
    {action, TokenLine};

to_keyword_or_identifier("alias", TokenLine) ->
    {alias, TokenLine};

to_keyword_or_identifier("alphanumeric_keys", TokenLine) ->
    {alphanumeric_keys, TokenLine};

to_keyword_or_identifier("alternate_group", TokenLine) ->
    {alternate_group, TokenLine};

to_keyword_or_identifier("alternate", TokenLine) ->
    {alternate, TokenLine};

to_keyword_or_identifier("augment", TokenLine) ->
    {augment, TokenLine};

to_keyword_or_identifier("default", TokenLine) ->
    {default, TokenLine};

to_keyword_or_identifier("function_keys", TokenLine) ->
    {function_keys, TokenLine};

to_keyword_or_identifier("group", TokenLine) ->
    {group, TokenLine};

to_keyword_or_identifier("hidden", TokenLine) ->
    {hidden, TokenLine};

to_keyword_or_identifier("include", TokenLine) ->
    {include, TokenLine};

to_keyword_or_identifier("indicator", TokenLine) ->
    {indicator, TokenLine};

to_keyword_or_identifier("interpret", TokenLine) ->
    {interpret, TokenLine};

to_keyword_or_identifier("keypad_keys", TokenLine) ->
    {keypad_keys, TokenLine};

to_keyword_or_identifier("key", TokenLine) ->
    {key, TokenLine};

to_keyword_or_identifier("keys", TokenLine) ->
    {keys, TokenLine};

to_keyword_or_identifier("logo", TokenLine) ->
    {logo, TokenLine};

to_keyword_or_identifier("modifier_keys", TokenLine) ->
    {modifier_keys, TokenLine};

to_keyword_or_identifier("modifier_map", TokenLine) ->
    {modifier_map, TokenLine};
to_keyword_or_identifier("mod_map", TokenLine) ->
    {modifier_map, TokenLine};
to_keyword_or_identifier("modmap", TokenLine) ->
    {modifier_map, TokenLine};

to_keyword_or_identifier("outline", TokenLine) ->
    {outline, TokenLine};

to_keyword_or_identifier("overlay", TokenLine) ->
    {overlay, TokenLine};

to_keyword_or_identifier("override", TokenLine) ->
    {override, TokenLine};

to_keyword_or_identifier("partial", TokenLine) ->
    {partial, TokenLine};

to_keyword_or_identifier("replace", TokenLine) ->
    {replace, TokenLine};

to_keyword_or_identifier("row", TokenLine) ->
    {row, TokenLine};

to_keyword_or_identifier("section", TokenLine) ->
    {section, TokenLine};

to_keyword_or_identifier("shape", TokenLine) ->
    {shape, TokenLine};

to_keyword_or_identifier("solid", TokenLine) ->
    {solid, TokenLine};

to_keyword_or_identifier("text", TokenLine) ->
    {text, TokenLine};

to_keyword_or_identifier("type", TokenLine) ->
    {type, TokenLine};

to_keyword_or_identifier("virtual_modifiers", TokenLine) ->
    {virtual_modifiers, TokenLine};

to_keyword_or_identifier("virtual", TokenLine) ->
    {virtual, TokenLine};

to_keyword_or_identifier("xkb_compatibility_map", TokenLine) ->
    {xkb_compat, TokenLine};
to_keyword_or_identifier("xkb_compatibility", TokenLine) ->
    {xkb_compat, TokenLine};
to_keyword_or_identifier("xkb_compat_map", TokenLine) ->
    {xkb_compat, TokenLine};
to_keyword_or_identifier("xkb_compat", TokenLine) ->
    {xkb_compat, TokenLine};

to_keyword_or_identifier("xkb_geometry", TokenLine) ->
    {xkb_geometry, TokenLine};

to_keyword_or_identifier("xkb_keycodes", TokenLine) ->
    {xkb_keycodes, TokenLine};

to_keyword_or_identifier("xkb_keymap", TokenLine) ->
    {xkb_keymap, TokenLine};

to_keyword_or_identifier("xkb_layout", TokenLine) ->
    {xkb_layout, TokenLine};

to_keyword_or_identifier("xkb_semantics", TokenLine) ->
    {xkb_semantics, TokenLine};

to_keyword_or_identifier("xkb_symbols", TokenLine) ->
    {xkb_symbols, TokenLine};

to_keyword_or_identifier("xkb_types", TokenLine) ->
    {xkb_types, TokenLine};

to_keyword_or_identifier(TokenChars, TokenLine) ->
    {identifier, TokenLine, TokenChars}.
