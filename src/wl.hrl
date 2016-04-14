-record(wl_request,{ sender :: pos_integer()
                   , opcode :: non_neg_integer()
                   , args   :: binary()
                   }).

-record(wl_event,{ sender  :: pos_integer()
                 , evtcode :: non_neg_integer()
                 , args    :: binary()
                 }).
