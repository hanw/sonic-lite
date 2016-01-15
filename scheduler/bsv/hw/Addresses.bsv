import SchedulerTypes::*;

function IP ip_address (ServerIndex index);
    IP addr = 'h00000000;
    case (index)
        0 : addr = 'hc0a80001;
        1 : addr = 'hc0a80001;
        2 : addr = 'hc0a80003;
        3 : addr = 'hc0a80004;
        4 : addr = 'hc0a80005;
        5 : addr = 'hc0a80006;
        6 : addr = 'hc0a80007;
        7 : addr = 'hc0a80008;
    endcase
    return addr;
endfunction

function MAC mac_address (ServerIndex index);
    MAC addr = 'h000000000000;
    case (index)
        0 : addr = 'hffab4859fbc4;
        1 : addr = 'hffab4859fbc4;
        2 : addr = 'h2947baffe64c;
        3 : addr = 'h5bdc664dffee;
        4 : addr = 'h85774bbcfeaa;
        5 : addr = 'h95babbdfe857;
        6 : addr = 'h7584bcaafe65;
        7 : addr = 'h1baeef3647af;
    endcase
    return addr;
endfunction
