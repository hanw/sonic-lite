import DefaultValue::*;

typedef struct {
   Bit#(64) sopEnq;
   Bit#(64) eopEnq;
   Bit#(64) sopDeq;
   Bit#(64) eopDeq;
} PktBuffDbgRec deriving (Bits, Eq);
instance DefaultValue#(PktBuffDbgRec);
   defaultValue = 
   PktBuffDbgRec {
      sopEnq: 0,
      eopEnq: 0,
      sopDeq: 0,
      eopDeq: 0
   };
endinstance

typedef struct {
   Bit#(64) allocCnt;
   Bit#(64) freeCnt;
} MemMgmtDbgRec deriving (Bits, Eq);
instance DefaultValue#(MemMgmtDbgRec);
   defaultValue =
   MemMgmtDbgRec {
      allocCnt: 0,
      freeCnt: 0
   };
endinstance

typedef struct {
   Bit#(64) lookupCnt;
   Bit#(64) modifyMacCnt;
   Bit#(64) fwdReqCnt;
   Bit#(64) sendCnt;
} TDMDbgRec deriving (Bits, Eq);
instance DefaultValue#(TDMDbgRec);
   defaultValue = 
   TDMDbgRec {
      lookupCnt: 0,
      modifyMacCnt: 0,
      fwdReqCnt: 0,
      sendCnt: 0
   };
endinstance

