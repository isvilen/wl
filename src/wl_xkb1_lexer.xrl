Definitions.

Section = (xkb_compatibility|xkb_keycodes|xkb_keymap|xkb_symbols|xkb_types|xkb_geometry)

Digit = [0-9]

HexDigit = [0-9a-fA-F]

Letter = [A-Za-z]

Identifier = ({Letter}|{Digit}|_)

WS  = [\000-\s]


Rules.

{Section} :
    {token, {list_to_atom(TokenChars), TokenLine}}.

{Letter}{Identifier}* :
    {token, {identifier, TokenLine, TokenChars}}.

<[^>\000-\s]*> :
    {token, {keyname, TokenLine, strip(TokenChars,TokenLen)} }.

"[^"]*" :
    {token, {string, TokenLine, strip(TokenChars,TokenLen)} }.

0x({HexDigit}+) :
    {token, {integer, TokenLine, hex_to_integer(TokenChars)}}.

{Digit}+ :
    {token, {integer, TokenLine, list_to_integer(TokenChars)}}.

{Digit}+\.{Digit}+ :
    {token, {float, TokenLine, list_to_float(TokenChars)}}.

[\[\](){}=!+-;.,] :
    {token, {list_to_atom(TokenChars), TokenLine}}.

(//[^\n]*)|{WS}+ :
    skip_token.


Erlang code.

strip(TokenChars,TokenLen) ->
    lists:sublist(TokenChars, 2, TokenLen - 2).


hex_to_integer("0x" ++ Chars) ->
    {ok,[V],[]} = io_lib:fread("~16u", Chars), V.
