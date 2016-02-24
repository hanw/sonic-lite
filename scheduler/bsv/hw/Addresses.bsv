import SchedulerTypes::*;

function IP ip_address (ServerIndex index);
    IP addr = 'h00000000;
    case (index)
        0 : addr = 'hc0a80001;
        1 : addr = 'hc0a80002;
        2 : addr = 'hc0a80003;
        3 : addr = 'hc0a80004;
        4 : addr = 'hc0a80005;
        5 : addr = 'hc0a80006;
        6 : addr = 'hc0a80007;
        7 : addr = 'hc0a80008;
        8 : addr = 'hc0a80009;
        9 : addr = 'hc0a8000a;
    endcase
    return addr;
endfunction

function ServerIndex host_id (IP ip_address);
    ServerIndex idx = fromInteger(valueof(NUM_OF_SERVERS));
    case (ip_address)
        'hc0a80001 : idx = 0;
        'hc0a80002 : idx = 1;
        'hc0a80003 : idx = 2;
        'hc0a80004 : idx = 3;
        'hc0a80005 : idx = 4;
        'hc0a80006 : idx = 5;
        'hc0a80007 : idx = 6;
        'hc0a80008 : idx = 7;
        'hc0a80009 : idx = 8;
        'hc0a8000a : idx = 9;
    endcase
    return idx;
endfunction

function MAC mac_address (ServerIndex index);
    MAC addr = 'h000000000000;
    case (index)
        0 : addr = 'h3417eb96df1f;
        1 : addr = 'h3417eb96df1e;
        2 : addr = 'h3417eb96df1d;
        3 : addr = 'h3417eb96df1c;
        4 : addr = 'h3417eb96df1b;
        5 : addr = 'h3417eb96df1a;
        6 : addr = 'h3417eb96df19;
        7 : addr = 'h3417eb96df18;
        8 : addr = 'h3417eb96df17;
        9 : addr = 'h3417eb96df16;
    endcase
    return addr;
endfunction
