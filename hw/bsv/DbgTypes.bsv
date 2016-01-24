
typedef struct {
   Bit#(64) sopEnq;
   Bit#(64) eopEnq;
   Bit#(64) sopDeq;
   Bit#(64) eopDeq;
} PktBuffDbgRec deriving (Bits, Eq);

typedef struct {
   Bit#(64) allocCnt;
   Bit#(64) freeCnt;
} MemMgmtDbgRec deriving (Bits, Eq);

typedef struct {
   Bit#(64) lookupCnt;
   Bit#(64) modifyMacCnt;
   Bit#(64) fwdReqCnt;
   Bit#(64) sendCnt;
} TDMDbgRec deriving (Bits, Eq);
