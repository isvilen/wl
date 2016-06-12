-module(wl_xkb1_parser_tests).

-include_lib("eunit/include/eunit.hrl").

-define(parse(Ts),wl_xkb1_parser:parse(Ts)).
-define(parse_file(F),?parse(read_keymap(F))).


keymaps_files_test_() -> [
    ?_assertMatch({ok, _}, ?parse_file("host.xkb"))
   ,?_assertMatch({ok, _}, ?parse_file("no-aliases.xkb"))
   ,?_assertMatch({ok, _}, ?parse_file("no-types.xkb"))
   ,?_assertMatch({ok, _}, ?parse_file("quartz.xkb"))
   ,?_assertMatch({ok, _}, ?parse_file("comprehensive-plus-geom.xkb"))
].


read_keymap(F) ->
    {_, _, ModuleFile} = code:get_object_code(?MODULE),
    Base = filename:dirname(ModuleFile),
    {ok, Bin} = file:read_file(filename:join([Base, "data", "xkb_keymaps", F])),
    {ok, Ts, _} = wl_xkb1_lexer:string(binary_to_list(Bin)),
    Ts.
