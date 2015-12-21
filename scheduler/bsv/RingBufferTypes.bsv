import DefaultValue::*;

typedef 12000 MAX_PKT_LEN; // 1500 bytes
typedef 128 BUS_WIDTH;

typedef Bit#(32) Address;
typedef Bit#(BUS_WIDTH) Payload;

typedef enum {READ, WRITE} Operation deriving(Bits, Eq);
typedef enum {SUCCESS, FAILURE} Result deriving(Bits, Eq);

typedef struct {
    Bit#(1) sop;
    Bit#(1) eop;
    Payload payload;
} RingBufferDataT deriving(Bits, Eq);

typedef struct {
    Operation op;
} ReadReqType deriving(Bits, Eq);

typedef struct {
    RingBufferDataT data;
} ReadResType deriving(Bits, Eq);

instance DefaultValue#(ReadResType);
    defaultValue = ReadResType {
                                data : unpack(0)
                              };
endinstance

typedef struct {
    RingBufferDataT data;
} WriteReqType deriving(Bits, Eq);

typedef struct {
    Result res;
} WriteResType deriving(Bits, Eq);

function ReadReqType makeReadReq(Operation op);
    return ReadReqType {
                        op : op
                       };
endfunction

function ReadResType makeReadRes(RingBufferDataT data);
    return ReadResType {
                        data : data
                       };
endfunction

function WriteReqType makeWriteReq(Bit#(1) sop, Bit#(1) eop, Payload payload);
    RingBufferDataT d = RingBufferDataT {
                   sop     : sop,
                   eop     : eop,
                   payload : payload
                 };

    return WriteReqType {
                         data : d
                        };
endfunction

function WriteResType makeWriteRes(Result res);
    return WriteResType {
                         res : res
                        };
endfunction

