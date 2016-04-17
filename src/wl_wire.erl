-module(wl_wire).
-export([ encode_request/1
        , decode_event/1
        , encode_int/1
        , decode_int/1
        , encode_uint/1
        , decode_uint/1
        , encode_string/1
        , decode_string/1
        , encode_fixed/1
        , decode_fixed/1
        , encode_array/1
        , decode_array/1
        , encode_object/1
        , decode_object/1
        ]).

-include("wl.hrl").


encode_request(#wl_request{sender=Sender,opcode=Op,args=Args}) ->
    ArgsBin = if
                  is_binary(Args) -> Args;
                  true            -> iolist_to_binary(Args)
              end,
    Header = ((8 + byte_size(ArgsBin)) bsl 16) + Op,
    <<Sender:32/native,Header:32/native,ArgsBin/binary>>.


decode_event(<<Sender:32/native,Header:32/native,Rest/binary>>) ->
    Evt = Header band 16#ffff,
    case (Header bsr 16) - 8 of
        Size when Size >= 0 ->
            case Rest of
                <<Args:Size/binary,Rest1/binary>> ->
                    {#wl_event{sender=Sender, evtcode=Evt, args=Args} , Rest1};
                _ ->
                    incomplete
            end;
        _ -> error
    end;

decode_event(Data) when is_binary(Data) ->
    {incomplete, Data}.


encode_int(V) when is_integer(V) ->
    <<V:32/native-signed>>.


decode_int(<<V:32/native-signed,Rest/binary>>) ->
    {V, Rest}.


encode_uint(V) when is_integer(V) ->
    <<V:32/native-unsigned>>.


decode_uint(<<V:32/native-unsigned,Rest/binary>>) ->
    {V, Rest}.


encode_string(V) when is_binary(V) ->
    S = size(V) + 1,
    Pad = case S rem 4 of
              0 -> 1;
              R -> 5 - R
          end,
    <<S:32/native,V/binary,0:Pad/unit:8>>.


decode_string(<<S:32/native,Rest/binary>>) ->
    Pad = case S rem 4 of
              0 -> 0;
              R -> 4 - R
          end,
    S1 = S - 1,
    <<V:S1/binary,0:8,_:Pad/unit:8,Rest1/binary>> = Rest,
    {V, Rest1}.


encode_fixed(V) when is_integer(V) ->
    encode_fixed(float(V));

encode_fixed(V) when is_float(V) ->
    <<_:32,R:32>> = <<(V + (3 bsl (51 - 8)))/float>>,
    <<R:32/native>>.


decode_fixed(<<V:32/native-signed,Rest/binary>>) ->
    <<R/float>> = <<(((1023 + 44) bsl 52) + (1 bsl 51) + V):64>>,
    {R - (3 bsl 43), Rest}.


encode_array(V) ->
    S = size(V),
    Pad = case S rem 4 of
              0 -> 0;
              R -> 4 - R
          end,
    <<S:32/native,V/binary,0:Pad/unit:8>>.


decode_array(<<S:32/native,Rest/binary>>) ->
    Pad = case S rem 4 of
              0 -> 0;
              R -> 4 - R
          end,
    <<V:S/binary,_:Pad/unit:8,Rest1/binary>> = Rest,
    {V, Rest1}.


encode_object(null) ->
    <<0:32/native>>;

encode_object(Id) when is_integer(Id) ->
    <<Id:32/native>>.


decode_object(<<0:32/native,Rest/binary>>) ->
    {null, Rest};

decode_object(<<Id:32/native,Rest/binary>>) ->
    {Id, Rest}.
