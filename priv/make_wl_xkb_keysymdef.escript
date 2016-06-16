#!/usr/bin/env escript
-mode(compile).

-define(X11_INCLUDE_DIR,"/usr/include/X11").
-define(DEFAULT_KEYDEFS,["keysymdef.h"
                        ,"XF86keysym.h"
                        ,"Sunkeysym.h"
                        ,"DECkeysym.h"
                        ,"HPkeysym.h"
                        ]).

% special keysym
-define(KEY_KP_Space,16#ff80).
-define(KEY_BackSpace,16#ff08).
-define(KEY_Clear,16#ff0b).
-define(KEY_KP_Multiply,16#ffaa).
-define(KEY_KP_9,16#ffb9).
-define(KEY_Return,16#ff0d).
-define(KEY_Escape,16#ff1b).
-define(KEY_Delete,16#ffff).
-define(KEY_KP_Tab,16#ff89).
-define(KEY_KP_Enter,16#ff8d).
-define(KEY_KP_Equal,16#ffbd).


main([]) ->
    main([filename:join(?X11_INCLUDE_DIR, File) || File <- ?DEFAULT_KEYDEFS]);

main(KeyDefsFiles) ->
    KeyDefs = lists:foldl(fun process_keydef_file/2, #{}, KeyDefsFiles),
    io:format("%% generated with ~s~n", [escript:script_name()]),
    io:format("%% from files: ~s~n", [hd(KeyDefsFiles)]),
    [io:format("%%             ~s~n", [F]) || F <- tl(KeyDefsFiles)],
    io:format("-define(XKB_KEYDEFS,~p).~n", [KeyDefs]).


process_keydef_file(File, Acc) ->
    Re = keydef_re(),
    case file:read_file(File) of
        {ok, Data}      -> parse_keydefs(Re, Data, Acc);
        {error, enoent} -> Acc
    end.


parse_keydefs(Re, Data, AccIn) ->
    AccOut = parse_keydefs_1(Re, binary:split(Data, <<"\n">>), AccIn),
    % filter key codes used to check for duplicated or deprecated entries
    maps:filter(fun(K,_) -> not is_integer(K) end, AccOut).


parse_keydefs_1(_, [], Acc) ->
    Acc;

parse_keydefs_1(_, [<<>>], Acc) ->
    Acc;

parse_keydefs_1(Re, [Line, Rest], Acc) ->
    NewAcc = parse_keydef(Re, Line, Acc),
    parse_keydefs_1(Re, binary:split(Rest, <<"\n">>), NewAcc).


parse_keydef(Re, Line, Acc) ->
  case re:run(Line, Re, [{capture, all_but_first}]) of
    {match, [P1,P2,P3]} ->
        keysym(Line, P1, P2, P3, Acc);

    {match, [P1,P2,P3,P4]} ->
        keychar(Line, P1, P2, P3, P4, Acc);

    nomatch ->
        Acc
  end.


keydef_re() ->
   {ok, Re} = re:compile(
       "^#define ([a-zA-Z_0-9]*)XK_([a-zA-Z_0-9]+)\\s+0x([0-9a-fA-F]+)\\s*"
       "(?:/\\*(?:\s|\\()?(?:U\\+([0-9A-F]{4}))?.*)?$"
       ),
    Re.


keysym(Line, P1, P2, P3, Acc) ->
    KeyName = keysym_name(Line, P1, P2),
    KeyCode = keysym_code(Line, P3),
    KeyVal =
    case KeyCode of
       V when (V band 16#ff000000) == 16#01000000 ->
           {KeyCode, {char, V band 16#00ffffff}};

       V when V >= ?KEY_BackSpace andalso V =< ?KEY_Clear
            ; V >= ?KEY_KP_Multiply andalso V =< ?KEY_KP_9
            ; V == ?KEY_Return
            ; V == ?KEY_Escape
            ; V == ?KEY_Delete
            ; V == ?KEY_KP_Tab
            ; V == ?KEY_KP_Enter
            ; V == ?KEY_KP_Equal ->
        {KeyCode, {char, V band 16#7f}};

       ?KEY_KP_Space ->
           {?KEY_KP_Space, {char, 32}};

       _ -> % create keysym, but check for duplicated or deprecated entries
           maps:get(KeyCode, Acc, {KeyCode, {key, keysym_atom(Line, P1, P2)}})
    end,
    Acc#{KeyName => KeyVal, KeyCode => KeyVal}.


keychar(Line, P1, P2, P3, P4, Acc) ->
    KeyName = keysym_name(Line, P1, P2),
    KeyCode = keysym_code(Line, P3),
    KeyVal = {KeyCode, {char, hex_to_int(binary:part(Line, P4))}},
    Acc#{KeyName => KeyVal, KeyCode => KeyVal}.


keysym_name(Line, P1, P2) ->
    B1 = binary:part(Line, P1),
    B2 = binary:part(Line, P2),
    binary_to_list(<<B1/binary,B2/binary>>).


keysym_code(Line, P) ->
    hex_to_int(binary:part(Line, P)).


keysym_atom(Line, {_, 0}, P) ->
    B = binary:part(Line, P),
    S = binary_to_list(B),
    list_to_atom(keysym_atom_1(S, []));

keysym_atom(Line, P1, P2) ->
    B1 = binary:part(Line, P1),
    B2 = binary:part(Line, P2),
    S1 = binary_to_list(B1),
    S2 = binary_to_list(B2),
    list_to_atom(keysym_atom_1(S1, []) ++ keysym_atom_1(S2, [$_])).

% make lowercase, underscore separated keysym atom (AaBb -> aa_bb)
keysym_atom_1([], Acc) ->
    lists:reverse(Acc);

keysym_atom_1([C], Acc) ->
    lists:reverse([string:to_lower(C) | Acc]);

keysym_atom_1([C1,C2 | Rest], Acc) ->
    case {string:to_lower(C1), string:to_lower(C2)} of
       {C1, C2} -> keysym_atom_1([C2 | Rest], [C1 | Acc]);
       {$_, L2} -> keysym_atom_1(Rest, [L2, $_ | Acc]);
       {C1, L2} -> keysym_atom_1(Rest, [L2, $_, C1 | Acc]);
       {L1, L2} -> keysym_atom_1(Rest, [L2, L1 | Acc])
    end.


hex_to_int(S) ->
   {ok,[V],[]} = io_lib:fread("~16u", binary_to_list(S)), V.
