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
    endcase
    return addr;
endfunction

function ServerIndex ip_to_host_id (IP ip_addr);
    ServerIndex idx = fromInteger(valueof(NUM_OF_SERVERS));
    case (ip_addr)
        'hc0a80001 : idx = 0;
        'hc0a80002 : idx = 1;
        'hc0a80003 : idx = 2;
        'hc0a80004 : idx = 3;
        'hc0a80005 : idx = 4;
        'hc0a80006 : idx = 5;
        'hc0a80007 : idx = 6;
        'hc0a80008 : idx = 7;
    endcase
    return idx;
endfunction

function ServerIndex mac_to_host_id (MAC mac_addr);
    ServerIndex idx = fromInteger(valueof(NUM_OF_SERVERS));
    case (mac_addr)
        'h3417eb96df1f : idx = 0;
        'h3417eb96df1e : idx = 1;
        'h3417eb96df1d : idx = 2;
        'h3417eb96df1c : idx = 3;
        'h3417eb96df1b : idx = 4;
        'h3417eb96df1a : idx = 5;
        'h3417eb96df19 : idx = 6;
        'h3417eb96df18 : idx = 7;
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
    endcase
    return addr;
endfunction

function IP mac_to_ip(MAC mac_addr);
    IP ip_addr = 'h00000000;
    case (mac_addr)
        'h3417eb96df1f : ip_addr = 'hc0a80001;
        'h3417eb96df1e : ip_addr = 'hc0a80002;
        'h3417eb96df1d : ip_addr = 'hc0a80003;
        'h3417eb96df1c : ip_addr = 'hc0a80004;
        'h3417eb96df1b : ip_addr = 'hc0a80005;
        'h3417eb96df1a : ip_addr = 'hc0a80006;
        'h3417eb96df19 : ip_addr = 'hc0a80007;
        'h3417eb96df18 : ip_addr = 'hc0a80008;
    endcase
    return ip_addr;
endfunction
