
interface FwdTestIndication;
   method Action read_version_resp(Bit#(32) version);
   method Action readTxRingBuffCntrsResp(Bit#(64) sopEnq, Bit#(64) eopEnq, Bit#(64) sopDeq, Bit#(64) eopDeq);
   method Action readRxRingBuffCntrsResp(Bit#(64) sopEnq, Bit#(64) eopEnq, Bit#(64) sopDeq, Bit#(64) eopDeq);
   method Action readMemMgmtCntrsResp(Bit#(64) allocCnt, Bit#(64) freeCnt, Bit#(64) allocCompleted, Bit#(64) freeCompleted, Bit#(64) errorCode, Bit#(64) lastIdFreed, Bit#(64) lastIdAllocated, Bit#(64) freeStarted, Bit#(64) firstSegment, Bit#(64) lastSegment, Bit#(64) currSegment, Bit#(64) invalidSegment);
   method Action readIngressCntrsResp(Bit#(64) fwdCount);
   method Action readHostChanCntrsResp(Bit#(64) paxosCount, Bit#(64) ipv6Count, Bit#(64) udpCount);
   method Action readRxChanCntrsResp(Bit#(64) paxosCount, Bit#(64) ipv6Count, Bit#(64) udpCount);
endinterface


