-module(wl_wire_tests).

-include_lib("eunit/include/eunit.hrl").
-include_lib("wl/src/wl.hrl").


request_test_() -> [
    ?_assertEqual(<<10:32/native,100:16/native,8:16/native>>
                 ,wl_wire:encode_request(#wl_request{sender = 10
                                                    ,opcode = 100
                                                    ,args   = <<>>})),

    ?_assertEqual(<<10:32/native,100:16/native,12:16/native,1,2,3,4>>
                 ,wl_wire:encode_request(#wl_request{sender = 10
                                                    ,opcode = 100
                                                    ,args   = <<1,2,3,4>>})),

    ?_assertEqual(<<10:32/native,100:16/native,12:16/native,1,2,3,4>>
                 ,wl_wire:encode_request(#wl_request{sender = 10
                                                    ,opcode = 100
                                                    ,args   = [ <<1,2>>
                                                              , <<3,4>>]}))
].


event_test_() -> [
    ?_assertEqual({#wl_event{sender=1, evtcode=2, args= <<>>}, <<>>}
                 ,wl_wire:decode_event(<<1:32/native
                                        ,2:16/native,8:16/native>>)),

    ?_assertEqual({#wl_event{sender=1, evtcode=2, args= <<>>}, <<1,2,3,4>>}
                 ,wl_wire:decode_event(<<1:32/native
                                        ,2:16/native,8:16/native
                                        ,1,2,3,4>>)),

    ?_assertEqual({#wl_event{sender=1, evtcode=2, args= <<1,2,3,4>>}, <<>>}
                 ,wl_wire:decode_event(<<1:32/native
                                        ,2:16/native,12:16/native
                                        ,1,2,3,4>>)),

    ?_assertEqual(incomplete
                 ,wl_wire:decode_event(<<1:32/native
                                        ,2:16/native,12:16/native>>)),

    %% size must be >= 8
    ?_assertEqual(error
                 ,wl_wire:decode_event(<<1:32/native
                                        ,2:16/native,0:16/native
                                        ,1,2,3,4>>))
].


int_type_test_() -> [
    ?_assertEqual(<<1234:32/native>>, wl_wire:encode_int(1234)),
    ?_assertEqual(<<-1234:32/native>>, wl_wire:encode_int(-1234)),
    ?_assertEqual({1234, <<255>>}, wl_wire:decode_int(<<1234:32/native,255>>)),
    ?_assertEqual({1234, <<>>}, wl_wire:decode_int(<<1234:32/native>>)),
    ?_assertEqual({-1234, <<>>}, wl_wire:decode_int(<<-1234:32/native>>))
].


uint_type_test_() -> [
    ?_assertEqual(<<1234:32/native>>, wl_wire:encode_uint(1234)),
    ?_assertEqual({1234, <<255>>}, wl_wire:decode_uint(<<1234:32/native,255>>)),
    ?_assertEqual({1234, <<>>}, wl_wire:decode_uint(<<1234:32/native>>))
].


fixed_type_test_() -> [
    ?_assertEqual(<<16#20,16#3e,16#00,16#00>>
                 ,wl_wire:encode_fixed(62.125)),

    ?_assertEqual(<<16#60,16#4f,16#fb,16#ff>>
                 ,wl_wire:encode_fixed(-1200.625)),

    ?_assertEqual(<<16#d0,16#df,16#fe,16#ff>>
                 ,wl_wire:encode_fixed(-288.1875)),

    ?LET(V,62*256,?_assertEqual(<<V:32/native>>
                               ,wl_wire:encode_fixed(62))),

    ?LET(V,-2080*256,?_assertEqual(<<V:32/native>>
                                  ,wl_wire:encode_fixed(-2080))),

    ?_assertEqual({288.1875, <<>>}
                 ,wl_wire:decode_fixed(<<16#30,16#20,16#01,16#00>>)),

    ?_assertEqual({16#70000000 / 256, <<>>}
                 ,wl_wire:decode_fixed(<<16#00,16#00,16#00,16#70>>)),

    ?_assertEqual({-1200.625, <<>>}
                 ,wl_wire:decode_fixed(<<16#60,16#4f,16#fb,16#ff>>)),

    ?_assertEqual({-288.1875, <<>>}
                 ,wl_wire:decode_fixed(<<16#d0,16#df,16#fe,16#ff>>)),

    ?_assertEqual({-16#80000000 / 256, <<>>}
                 ,wl_wire:decode_fixed(<<16#00,16#00,16#00,16#80>>))
].


string_type_test_() -> [
    ?_assertEqual(<<5:32/native,"abcd",0,0,0,0>>
                 ,wl_wire:encode_string(<<"abcd">>)),

    ?_assertEqual(<<9:32/native,"abcdefgh",0,0,0,0>>
                 ,wl_wire:encode_string(<<"abcdefgh">>)),

    ?_assertEqual(<<8:32/native,"abcdefg",0>>
                 ,wl_wire:encode_string(<<"abcdefg">>)),

    ?_assertEqual({<<"abcd">>, <<>>}
                 ,wl_wire:decode_string(<<5:32/native,"abcd",0,0,0,0>>)),

    ?_assertEqual({<<"abcdefgh">>, <<>>}
                 ,wl_wire:decode_string(<<9:32/native,"abcdefgh",0,0,0,0>>)),

    ?_assertEqual({<<"abcdefg">>, <<1,2,3,4>>}
                 ,wl_wire:decode_string(<<8:32/native,"abcdefg",0,1,2,3,4>>))
].


object_type_test_() -> [
    ?_assertEqual(<<0:32/native>>, wl_wire:encode_object(null)),
    ?_assertEqual(<<1:32/native>>, wl_wire:encode_object(1)),
    ?_assertEqual({null, <<>>}, wl_wire:decode_object(<<0:32/native>>)),
    ?_assertEqual({1, <<>>}, wl_wire:decode_object(<<1:32/native>>)),
    ?_assertEqual({1, <<255>>}, wl_wire:decode_object(<<1:32/native,255>>))
].


array_type_test_() -> [
    ?_assertEqual(<<5:32/native,1,2,3,4,5,0,0,0>>
                 ,wl_wire:encode_array(<<1,2,3,4,5>>)),

    ?_assertEqual(<<8:32/native,1,2,3,4,5,6,7,8>>
                 ,wl_wire:encode_array(<<1,2,3,4,5,6,7,8>>)),

    ?_assertEqual({<<1,2,3,4>>, <<>>}
                 ,wl_wire:decode_array(<<4:32/native,1,2,3,4>>)),

    ?_assertEqual({<<1,2,3,4,5,6,7,8,9>>, <<>>}
                 ,wl_wire:decode_array(<<9:32/native,1,2,3,4,5,6,7,8,9,0,0,0>>))
].
