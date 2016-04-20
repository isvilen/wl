-define(WL_SERVER_ID_START,16#ff000000).

-record(wl_request,{ sender :: pos_integer()
                   , opcode :: non_neg_integer()
                   , args   :: binary()
                   }).

-record(wl_event,{ sender  :: pos_integer() | {module(), pid()}
                 , evtcode :: non_neg_integer()
                 , args    :: binary()
                 }).
