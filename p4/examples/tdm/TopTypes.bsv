
typedef Bit#(16) FlowId;

typedef struct {
   Bit#(4) egress_index;
} ActionArg deriving (Bits, Eq, FShow);

typedef struct {
   Bit#(32) dstip;
} MatchField deriving (Bits, Eq, FShow);

typedef struct {
   MatchField field;
   ActionArg argument;
} TableEntry deriving (Bits, Eq, FShow);

typedef enum {
   MODIFY_MAC = 1
} OpCode deriving (Bits, Eq, FShow);

typedef struct {
   OpCode opcode;
} ActionOp deriving (Bits, Eq, FShow);

interface MemoryTestIndication;
   method Action read_version_resp(Bit#(32) version);
   method Action addEntryResp(FlowId id);
   method Action readRingBuffCntrsResp(Bit#(64) sopEnq, Bit#(64) eopEnq, Bit#(64) sopDeq, Bit#(64) eopDeq);
   method Action readMemMgmtCntrsResp(Bit#(64) allocCnt, Bit#(64) freeCnt);
   method Action readTDMCntrsResp(Bit#(64) lookupCnt, Bit#(64) modifyMacCnt, Bit#(64) fwdReqCnt, Bit#(64) sendCnt);
endinterface


