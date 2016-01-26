
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
   method Action readMemMgmtCntrsResp(Bit#(64) allocCnt, Bit#(64) freeCnt, Bit#(64) allocCompleted, Bit#(64) freeCompleted, Bit#(64) errorCode, Bit#(64) lastIdFreed, Bit#(64) lastIdAllocated, Bit#(64) freeStarted, Bit#(64) firstSegment, Bit#(64) lastSegment, Bit#(64) currSegment, Bit#(64) invalidSegment);
   method Action readTDMCntrsResp(Bit#(64) lookupCnt, Bit#(64) modifyMacCnt, Bit#(64) fwdReqCnt, Bit#(64) sendCnt);
   method Action readMatchTableCntrsResp(Bit#(64) matchRequestCount, Bit#(64) matchResponseCount, Bit#(64) matchValidCount, Bit#(64) lastMatchIdx, Bit#(64) lastMatchRequest);
   method Action readTxThruCntrsResp(Bit#(64) goodputCount, Bit#(64) idleCount);
endinterface


