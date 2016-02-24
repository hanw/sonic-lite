import DefaultValue::*;

typedef 512 MAX_PKT_LEN; // 64 bytes
typedef 128 BUS_WIDTH;
typedef 9 MAX_PKT_LEN_POW_OF_2;
typedef 7 BUS_WIDTH_POW_OF_2;

typedef Bit#(32) Address;
typedef Bit#(BUS_WIDTH) Payload;

typedef enum {READ, PEEK, REMOVE, WRITE} Operation deriving(Bits, Eq);
typedef enum {SUCCESS, FAILURE} Result deriving(Bits, Eq);

typedef struct {
    Bit#(1) sop;
    Bit#(1) eop;
    Payload payload;
} RingBufferDataT deriving(Bits, Eq);

instance DefaultValue#(RingBufferDataT);
	defaultValue = RingBufferDataT {
						sop     : 0,
						eop     : 0,
						payload : 0
					};
endinstance

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

