import DefaultValue::*;

typedef 32 IP_ADDR_LEN;
typedef 48 MAC_ADDR_LEN;
typedef 2 NUM_OF_SERVERS;
typedef NUM_OF_SERVERS TABLE_LEN;

typedef Bit#(IP_ADDR_LEN) IP;
typedef Bit#(MAC_ADDR_LEN) MAC;
typedef Bit#(4) AddrIndex; /* log2(TABLE_LEN) */
typedef Bit#(32) Address;

typedef 20 RING_BUFFER_SIZE;

typedef enum {GET, PUT, REMOVE, NONE} TableOp deriving(Bits, Eq);
typedef enum {VALID, INVALID} Tag deriving(Bits, Eq);
typedef enum {SETTIME, GETTIME, SETINTERVAL, GETINTERVAL,
              INSERT, DELETE, DISPLAY,
              STARTSCHED, STOPSCHED, NONE} SchedulerOp deriving(Bits, Eq);
typedef enum {CONFIG, RUN} State deriving(Bits, Eq);
typedef enum {SUCCESS, FAILURE} Outcome deriving(Bits, Eq);

typedef struct {
    IP server_ip;
    MAC server_mac;
    Bit#(1) is_valid;
} Data deriving(Bits, Eq); /* Each entry in the table */

typedef struct {
    IP server_ip;
    MAC server_mac;
    AddrIndex addrIdx;
    TableOp op;
    Outcome op_outcome;
} TableReqResType deriving(Bits, Eq);

instance DefaultValue#(TableReqResType);
    defaultValue = TableReqResType {
                                server_ip  : 0,
                                server_mac : 0,
                                addrIdx    : 0,
                                op         : NONE,
                                op_outcome : FAILURE
                              };
endinstance

function TableReqResType makeTableReqRes(IP server_ip, MAC server_mac,
                       AddrIndex addrIdx, TableOp op, Outcome outcome);
    return TableReqResType {
                        server_ip  : server_ip,
                        server_mac : server_mac,
                        addrIdx    : addrIdx,
                        op         : op,
                        op_outcome : outcome
                      };
endfunction

typedef struct {
    IP server_ip;
    MAC server_mac;
    Bit#(64) start_time;
    Bit#(64) interval;
    AddrIndex addrIdx;
    SchedulerOp op;
    Outcome op_outcome;
} SchedReqResType deriving(Bits, Eq);

instance DefaultValue#(SchedReqResType);
    defaultValue = SchedReqResType {
                                server_ip  : 0,
                                server_mac : 0,
                                start_time : 0,
                                interval   : 0,
                                addrIdx    : 0,
                                op         : NONE,
                                op_outcome : FAILURE
                              };
endinstance

function SchedReqResType makeSchedReqRes(IP server_ip, MAC server_mac,
            Bit#(64) start_time, Bit#(64) interval, AddrIndex addrIdx,
                                     SchedulerOp op, Outcome outcome);
    return SchedReqResType {
                        server_ip  : server_ip,
                        server_mac : server_mac,
                        start_time : start_time,
                        interval   : interval,
                        addrIdx    : addrIdx,
                        op         : op,
                        op_outcome : outcome
                      };
endfunction

