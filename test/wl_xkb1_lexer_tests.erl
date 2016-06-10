-module(wl_xkb1_lexer_tests).

-include_lib("eunit/include/eunit.hrl").

-define(scan(S),wl_xkb1_lexer:string(S)).


section_tokens_test_() -> [
    ?_assertMatch({ok, [{xkb_keymap,_}], _}, ?scan("xkb_keymap"))
   ,?_assertMatch({ok, [{xkb_keymap,_}
                       ,{'{',_}
                       ,{xkb_keycodes,_}
                       ,{string, _, ""}
                       ,{'{',_}
                       ,{'}',_}
                       ,{'}',_}
                       ,{';',_}
                       ], _},
                  ?scan("xkb_keymap { \n xkb_keycodes \"\" { \n } };"))
].


identifier_token_test_() -> [
    ?_assertMatch({ok, [{identifier,_, "minimum"}], _}, ?scan("minimum"))
   ,?_assertMatch({ok, [{identifier,_, "Level1"}], _}, ?scan("Level1"))
   ,?_assertMatch({ok, [{identifier,_, "Shift"}
                       ,{'+', _}
                       ,{identifier,_, "Lock"}
                       ], _},
                  ?scan("Shift+Lock"))
   ,?_assertMatch({ok, [{identifier,_, "map"}
                       ,{'[', _}
                       ,{identifier,_, "LAlt"}
                       ,{']', _}
                       ,{'=', _}
                       ,{identifier,_, "Level2"}
                       ,{';', _}
                       ], _},
                  ?scan("map[LAlt]= Level2;"))
].


keyname_token_test_() -> [
    ?_assertMatch({ok, [{keyname,_, "ESC"}], _}, ?scan("<ESC>"))
   ,?_assertMatch({ok, [{keyname,_,"AE01"}], _}, ?scan("<AE01>"))
   ,?_assertMatch({ok, [{keyname,_,"VOL-"}], _}, ?scan("<VOL->"))
   ,?_assertMatch({ok, [{keyname,_,"VOL+"}], _}, ?scan("<VOL+>"))
].


string_token_test_() -> [
    ?_assertMatch({ok, [{string,_,"CTRL+ALT"}], _}, ?scan("\"CTRL+ALT\""))
].


integer_token_test_() -> [
    ?_assertMatch({ok, [{integer,_,24}], _}, ?scan("24"))
   ,?_assertMatch({ok, [{integer,_, 1}], _}, ?scan("01"))
   ,?_assertMatch({ok, [{integer,_,32}], _}, ?scan("0x20"))
].


interpret_fragment_test_() -> [
    ?_assertMatch({ok, [{identifier,_, "interpret"}
                       ,{identifier,_, "KP_8"}
                       ,{'+',_}
                       ,{identifier,_, "AnyOfOrNone"}
                       ,{'(',_}
                       ,{identifier,_, "all"}
                       ,{')',_}
                       ,{'{',_}
                       ,{identifier,_, "repeat"}
                       ,{'=',_}
                       ,{identifier,_, "True"}
                       ,{';',_}
                       ,{identifier,_, "action"}
                       ,{'=',_}
                       ,{identifier,_, "MovePtr"}
                       ,{'(',_}
                       ,{identifier,_, "x"}
                       ,{'=',_}
                       ,{'+',_}
                       ,{integer,_, 0}
                       ,{',',_}
                       ,{identifier,_, "y"}
                       ,{'=',_}
                       ,{'-',_}
                       ,{integer,_, 1}
                       ,{')',_}
                       ,{';',_}
                       ,{'}',_}
                       ,{';',_}
                       ], _},
                  ?scan("interpret KP_8+AnyOfOrNone(all) {\n"
                        "		repeat= True;\n"
                        "		action= MovePtr(x=+0,y=-1);\n"
                        "	};\n"))
].
