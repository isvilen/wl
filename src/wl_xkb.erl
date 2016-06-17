-module(wl_xkb).
-export([init/2, update_modifiers/5, key_pressed/2, key_released/2]).

-define(EVDEV_OFFSET,8).
-define(MODS_REAL_MASK,16#ff).

-define(BUILTIN_MODS,#{ "Shift"   => 2#00000001
                      , "Lock"    => 2#00000010
                      , "Control" => 2#00000100
                      , "Mod1"    => 2#00001000
                      , "Mod2"    => 2#00010000
                      , "Mod3"    => 2#00100000
                      , "Mod4"    => 2#01000000
                      , "Mod5"    => 2#10000000
                      }).

-include("wl_xkb_keysymdef.hrl").

-type keycode()           :: pos_integer().
-type group_index()       :: pos_integer().
-type level_index()       :: pos_integer().
-type modifiers()         :: integer().
-type keysym()            :: {char, char()} | {key, atom()} | no_symbol.
-type unknown_key_group() :: {redirect, group_index()} | saturate | wrap.

-record(key_group,{ levels    :: [{modifiers(), level_index()}]
                  , symbols   :: [keysym()]
                  , mods_mask :: integer()
                  }).

-record(key,{ groups        :: [#key_group{}]
            , unknown_group :: unknown_key_group()
            }).

-type keymap() :: #{keycode() => #key{}}.

-record(state,{ keymap    :: keymap()
              , modifiers :: integer()
              , group     :: integer()
              }).


init(Format, Binary) when is_binary(Binary) ->
    init(Format, binary_to_list(Binary));

init(xkb_v1, String) ->
    #state{keymap = keymap_from_string(String)}.


update_modifiers(State, ModsDepressed, ModsLatched, ModsLocked, Group) ->
    Mods = (ModsDepressed bor ModsLatched bor ModsLocked) band ?MODS_REAL_MASK,
    State#state{modifiers=Mods, group=Group}.


key_pressed(#state{keymap=Keymap,modifiers=Mods,group=Group}=State, Key) ->
    {keysym_get(Key, Keymap, Mods, Group), State}.


key_released(#state{keymap=Keymap,modifiers=Mods,group=Group}=State, Key) ->
    {keysym_get(Key, Keymap, Mods, Group), State}.


keymap_from_string(String) ->
    compile_keymap(parse_keymap(String)).


parse_keymap(String) ->
    {ok, Tokens, _} = wl_xkb1_lexer:string(String),
    {ok, Keymap} = wl_xkb1_parser:parse(Tokens),
    Keymap.


compile_keymap({keymap,_,Blocks, _}) ->
    Ctx = lists:foldl(fun (B, Ctx) -> compile_keymap_block(B, Blocks, Ctx) end
                     ,#{ keynames  => #{}
                       , types     => #{}
                       , symbols   => #{}
                       }
                     ,[keycodes, types, compat, symbols]),
    create_keymap(Ctx).

compile_keymap_block(BlockId, Blocks, Ctx) ->
    case lists:keyfind(BlockId, 1, Blocks) of
        false ->
            Ctx;
        {BlockId, _Description, Data, _Opts} ->
            lists:foldl(fun (D,Acc) ->
                                process_keymap_block_data(BlockId, D, Acc)
                        end, Ctx, Data)
    end.

process_keymap_block_data(keycodes, {keyname, Name, Code, _MergeMode}
                         ,#{keynames := Keynames} = Ctx) ->
    Ctx#{keynames := Keynames#{Name => Code}};

process_keymap_block_data(types, {type, Name, Data, _MergeMode}
                         ,#{types := Types} = Ctx) ->
    Ctx#{types := Types#{Name => process_type(Data)}};

process_keymap_block_data(symbols, {key, Name, Data, _MergeMode}
                         ,#{symbols := Symbols} = Ctx) ->
    Ctx#{symbols := Symbols#{Name => process_symbols(Data, Ctx)}};

process_keymap_block_data(_, _, Ctx) ->
    Ctx.

process_symbols(Data, Ctx) ->
    KeySymbolsGroups = key_symbols_groups(Data, Ctx),
    {KeySymbolsGroups, key_unknown_group_action(KeySymbolsGroups, Data)}.


key_symbols_groups(Data, Ctx) ->
    Type = key_defined_type(Data),
    case [S || {{"symbols",_}, S} <- Data] of
        [] ->
            [{key_type(Type, S, Ctx), S} || S <- Data, is_list(S)];
        Syms ->
            [{key_type(Type, S, Ctx), S} || S <- Syms]
    end.


key_unknown_group_action(KeySymbolsGroups, Data) ->
    case lists:foldl(fun key_unknown_group_action_1/2, wrap, Data) of
        {redirect, Idx} -> {redirect, min(Idx, length(KeySymbolsGroups))};
        Action          -> Action
    end.

key_unknown_group_action_1({Lhs, Value}, Action)
  when Lhs == "groupswrap" ; Lhs == "wrapgroups"->
    case boolean_value(Value) of
        {ok, true} -> wrap;
        _          -> Action
    end;


key_unknown_group_action_1({Lhs, Value}, Action)
  when Lhs == "groupsclamp" ; Lhs == "clampgroups"->
    case boolean_value(Value) of
        true -> saturate;
        _    -> Action
    end;


key_unknown_group_action_1({Lhs, Value}, Action)
  when Lhs == "groupsredirect" ; Lhs == "redirectgroups" ->
    case integer_value(Value) of
        undefined -> Action;
        Value     -> {redirect, Value}
    end;

key_unknown_group_action_1(_, Action) ->
    Action.


boolean_value(Value) when Value == true
                        ; Value == "true"
                        ; Value == "yes"
                        ; Value == "on" -> true;

boolean_value(Value) when Value == false
                        ; Value == "false"
                        ; Value == "no"
                        ; Value == "off" -> false;

boolean_value(_) -> undefined.


integer_value(Value) ->
    case string:to_integer(Value) of
        {Value, []} -> Value;
        _           -> undefined
    end.


key_defined_type(Symbols) ->
    case lists:keyfind("type", 1, Symbols) of
        {_, T} -> T;
        false  -> undefined
    end.


key_type(undefined, Symbols, Ctx) -> key_auto_type(Symbols, Ctx);
key_type(Type, _, _)              -> Type.


key_auto_type(Symbols, _) when length(Symbols) =< 1 ->
    "ONE_LEVEL";

key_auto_type([S1, S2], _) ->
    key_auto_type_width2(S1, S2);

key_auto_type([S1, S2, S3], _) ->
    key_auto_type_width4(S1, S2, S3, no_symbol);

key_auto_type([S1, S2, S3, S4], _) ->
    key_auto_type_width4(S1, S2, S3, S4);

key_auto_type(_, #{types := [{Type, _} | _]}) ->
    Type;

key_auto_type(_, _) ->
    "ONE_LEVEL".

key_auto_type_width2(S1, S2) ->
    case keysym_is_lower(S1) andalso keysym_is_upper(S2) of
        true  -> "ALPHABETIC";
        false -> case keysym_is_keypad(S1) orelse keysym_is_keypad(S2) of
                     true  -> "KEYPAD";
                     false -> "TWO_LEVEL"
                 end
    end.

key_auto_type_width4(S1, S2, S3, S4) ->
    case keysym_is_lower(S1) andalso keysym_is_upper(S2) of
        true  -> case keysym_is_lower(S3) andalso keysym_is_upper(S4) of
                     true  -> "FOUR_LEVEL_ALPHABETIC";
                     false -> "FOUR_LEVEL_SEMIALPHABETIC"
                 end;
        false -> case keysym_is_keypad(S1) orelse keysym_is_keypad(S2) of
                     true  -> "FOUR_LEVEL_KEYPAD";
                     false -> "FOUR_LEVEL"
                 end
    end.


keysym_is_lower({unicode, {char, Char}}) ->
    unicode_is_lower(Char);

keysym_is_lower({Keysym, _}) when Keysym < 16#100 ->
    unicode_is_lower(Keysym);

keysym_is_lower({Keysym, _}) when (Keysym band 16#ff000000) == 16#01000000 ->
    unicode_is_lower(Keysym band 16#00ffffff);

keysym_is_lower({Keysym, _})
  when Keysym == ?KEY_aogonek
     ; Keysym >= ?KEY_lstroke,           Keysym =< ?KEY_sacute
     ; Keysym >= ?KEY_scaron,            Keysym =< ?KEY_zacute
     ; Keysym >= ?KEY_zcaron,            Keysym =< ?KEY_zabovedot
     ; Keysym >= ?KEY_racute,            Keysym =< ?KEY_tcedilla
     ; Keysym >= ?KEY_hstroke,           Keysym =< ?KEY_hcircumflex
     ; Keysym >= ?KEY_gbreve,            Keysym =< ?KEY_jcircumflex
     ; Keysym >= ?KEY_cabovedot,         Keysym =< ?KEY_scircumflex
     ; Keysym >= ?KEY_rcedilla,          Keysym =< ?KEY_tslash
     ; Keysym == ?KEY_eng
     ; Keysym >= ?KEY_amacron,           Keysym =< ?KEY_umacron
     ; Keysym >= ?KEY_Serbian_dje,       Keysym =< ?KEY_Serbian_dze
     ; Keysym >= ?KEY_Cyrillic_yu,       Keysym =< ?KEY_Cyrillic_hardsign
     ; Keysym >= ?KEY_Greek_alphaaccent, Keysym =< ?KEY_Greek_omegaaccent
                                       , Keysym /= ?KEY_Greek_iotaaccentdieresis
                                       , Keysym /= ?KEY_Greek_upsilonaccentdieresis
     ; Keysym >= ?KEY_Greek_alpha,       Keysym >= ?KEY_Greek_omega
                                       , Keysym /= ?KEY_Greek_finalsmallsigma
     ; Keysym == ?KEY_oe
     ; Keysym == ?KEY_ydiaeresis -> true;

keysym_is_lower(_) -> false.


unicode_is_lower(Code)
  when Code >= 16#0061, Code =< 16#007a % a-z
     ; Code >= 16#0061, Code =< 16#007a
     ; Code >= 16#00e0, Code =< 16#00f6
     ; Code >= 16#00f8, Code =< 16#00fe
     ; Code == 16#00ff                  % y with diaeresis
     ; Code == 16#00b5  -> true;        % micro sign

unicode_is_lower(Code)
  when Code >= 16#0100, Code =< 16#017f -> % Latin Extended-A
    if
        Code >= 16#0100, Code =< 16#0137 -> (Code band 1) == 1;
        Code == 16#0138                  -> true;
        Code >= 16#0139, Code =< 16#0148 -> (Code band 1) == 0;
        Code == 16#0149                  -> true;
        Code >= 16#014a, Code =< 16#0178 -> (Code band 1) == 1;
        Code >= 16#0179, Code =< 16#017e -> (Code band 1) == 0;
        Code == 16#017f                  -> true
    end;

%% TODO:
unicode_is_lower(_) ->
    false.


keysym_is_upper({unicode, {char, Char}}) ->
    unicode_is_upper(Char);

keysym_is_upper({Keysym, _}) when Keysym < 16#100 ->
    unicode_is_upper(Keysym);

keysym_is_upper({Keysym, _}) when (Keysym band 16#ff000000) == 16#01000000 ->
    unicode_is_upper(Keysym band 16#00ffffff);

keysym_is_upper({Keysym, _})
  when Keysym == ?KEY_Aogonek
     ; Keysym >= ?KEY_Lstroke,           Keysym =< ?KEY_Sacute
     ; Keysym >= ?KEY_Scaron,            Keysym =< ?KEY_Zacute
     ; Keysym >= ?KEY_Zcaron,            Keysym =< ?KEY_Zabovedot
     ; Keysym >= ?KEY_Racute,            Keysym =< ?KEY_Tcedilla
     ; Keysym >= ?KEY_Hstroke,           Keysym =< ?KEY_Hcircumflex
     ; Keysym >= ?KEY_Gbreve,            Keysym =< ?KEY_Jcircumflex
     ; Keysym >= ?KEY_Cabovedot,         Keysym =< ?KEY_Scircumflex
     ; Keysym >= ?KEY_Rcedilla,          Keysym =< ?KEY_Tslash
     ; Keysym == ?KEY_ENG
     ; Keysym >= ?KEY_Amacron,           Keysym =< ?KEY_Umacron
     ; Keysym >= ?KEY_Serbian_DJE,       Keysym =< ?KEY_Serbian_DZE
     ; Keysym >= ?KEY_Cyrillic_YU,       Keysym =< ?KEY_Cyrillic_HARDSIGN
     ; Keysym >= ?KEY_Greek_ALPHAaccent, Keysym =< ?KEY_Greek_OMEGAaccent
     ; Keysym >= ?KEY_Greek_ALPHA,       Keysym =< ?KEY_Greek_OMEGA
     ; Keysym == ?KEY_OE
     ; Keysym == ?KEY_Ydiaeresis -> true;

keysym_is_upper(_) -> false.


unicode_is_upper(Code)
  when Code >= 16#0041, Code =< 16#005a % A-Z
     ; Code >= 16#00c0, Code =< 16#00d6
     ; Code >= 16#00d8, Code =< 16#00de -> true;

unicode_is_upper(Code)
  when Code >= 16#0100, Code =< 16#017f -> % Latin Extended-A
    if
        Code >= 16#0100, Code =< 16#0137 -> (Code band 1) == 0;
        Code >= 16#0139, Code =< 16#0148 -> (Code band 1) == 1;
        Code >= 16#014a, Code =< 16#0178 -> (Code band 1) == 0;
        Code >= 16#0179, Code =< 16#017e -> (Code band 1) == 1;
        true                             -> false
    end;

%% TODO:
unicode_is_upper(_Code) ->
    false.


keysym_is_keypad({Keysym, _}) when is_integer(Keysym) ->
    Keysym >= ?KEY_KP_Space andalso Keysym =< ?KEY_KP_Equal;

keysym_is_keypad(_) -> false.


process_type(Data) ->
    resolve_type(lists:foldl(fun process_type_1/2, {undefined, #{}}, Data)).

process_type_1({"modifiers", Mods}, {_, Mappings}) ->
    {type_modifiers(Mods), Mappings};

process_type_1({{"map",LevelMods},Level}, {Mods, Mappings}) ->
    {Mods, Mappings#{type_modifiers(LevelMods) => type_level(Level)}};

process_type_1(_, Acc) ->
    Acc.

type_modifiers("none")        -> [];
type_modifiers({'+', M1, M2}) -> type_modifiers(M1) ++ type_modifiers(M2);
type_modifiers(Mod)           -> [Mod].


type_level("Level" ++ L) -> list_to_integer(L);
type_level("level" ++ L) -> list_to_integer(L).


resolve_type({ModNames, Mappings}) ->
   Mods = lists:foldl(fun (M, Acc) -> maps:get(M, ?BUILTIN_MODS, 0) bor Acc end
                     , 0, ModNames),
   Levels = maps:fold(fun (Ms, L, Acc) -> resolve_type_level(Ms, L) ++ Acc end
                     , [], Mappings),
   {Mods, sort_type_levels(Levels)}.

resolve_type_level(ModNames, Level) ->
   case lists:foldl(fun (_, undefined) ->
                            undefined;
                        (M, Acc) ->
                            case maps:get(M, ?BUILTIN_MODS, undefined) of
                                undefined -> undefined;
                                Mod       -> Mod bor Acc
                            end
                    end, 0, ModNames)
   of
       undefined -> [];
       0         -> [];
       ModMask   -> [{ModMask, Level}]
   end.


sort_type_levels(Levels) ->
    lists:sort(fun ({_,L1},{_,L2}) -> L1 =< L2 end, Levels).


create_keymap(#{keynames:=Keynames, symbols:=Symbols} = Ctx) ->
    maps:fold(fun (Name, SymbolData, Acc) ->
                  Code = maps:get(Name, Keynames) - ?EVDEV_OFFSET,
                  Acc#{Code => create_key(SymbolData, Ctx)}
              end, #{}, Symbols).


create_key({KeySymbols, UnknownGroupAction}, Ctx) ->
    Groups = [create_key_group(T, S, Ctx) || {T, S} <- KeySymbols],
    #key{ groups = Groups
        , unknown_group = UnknownGroupAction
        }.

create_key_group(Type, Symbols, #{types := Types}) ->
    {ModsMask, Levels} = maps:get(Type, Types),

    Syms = [case S of {_, Sym} -> Sym; _ -> S end || S <- Symbols],

    #key_group{ levels    = Levels
              , symbols   = Syms
              , mods_mask = ModsMask
              }.


keysym_get(Keycode, Keymap, Mods, Group) ->
    case maps:get(Keycode, Keymap, undefined) of
        undefined -> [];
        Key       -> keysym_get(Key, Mods, Group)
    end.

keysym_get(#key{groups=Groups}, Mods, Group) when Group >= 0
                                                , Group < length(Groups) ->
    keysym_get(lists:nth(Group+1, Groups), Mods);

keysym_get(#key{groups=Groups, unknown_group={redirect, GroupIdx}}, Mods, _) ->
    keysym_get(lists:nth(GroupIdx, Groups), Mods);

keysym_get(#key{groups=Groups, unknown_group=saturate}, Mods, Group) ->
    GroupIdx = if
                   Group < 0 -> 1;
                   true      -> length(Groups)
               end,
    keysym_get(lists:nth(GroupIdx, Groups), Mods);

keysym_get(#key{groups=Groups, unknown_group=wrap}, Mods, Group) ->
    NumGroups = length(Groups),
    GroupIdx = 1 + if
                       Group < 0 -> NumGroups + (Group rem NumGroups);
                       true      -> Group rem NumGroups
                   end,
    keysym_get(lists:nth(GroupIdx, Groups), Mods).


keysym_get(#key_group{levels=Levels, symbols=Symbols, mods_mask=Mask}, Mods) ->
    Level = keysym_get_level(Levels, Mods band Mask),
    case lists:nth(Level, Symbols) of
        no_symbol -> [];
        Keysym    -> [Keysym]
    end.


keysym_get_level([], _)                     -> 1;
keysym_get_level([{Mods, Level} | _], Mods) -> Level;
keysym_get_level([_ | Levels], Mods)        -> keysym_get_level(Levels, Mods).
