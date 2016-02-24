import Ethernet::*;
import Vector::*;
import ClientServer::*;
import RegFile::*;
import FIFO::*;
import GetPut::*;
import Connectable::*;

typedef union tagged {
   struct {
      PacketInstance pkt;
   } PacketMemRequest;

   struct {
      PacketInstance pkt;
      Bit#(4) queue;
      Bit#(2) port;
   } QueueRequest;

   struct {
      PacketInstance pkt;
      Bit#(48) mac;
   } ModifyMacRequest;

   struct {
      PacketInstance pkt;
      Bit#(32) dstip;
   } RouteLookupRequest;

   struct {
      PacketInstance pkt;
   } RoleLookupRequest;

   struct {
      PacketInstance pkt;
   } RoundTblRequest;

   struct {
      PacketInstance pkt;
   } SequenceTblRequest;
} MetadataRequest deriving (Bits, Eq);

typedef struct {
   Bool done;
} MetadataResponse deriving (Bits, Eq);

typedef 8 RoundSize;
typedef 8 MsgTypeSize;
typedef 16 InstanceSize;
typedef 512 ValueSize;

interface P4RegisterIfc#(type addr, type data);
endinterface

typedef struct {
   addrT addr;
   dataT data;
   Bool write;
} RegRequest#(type addrT, type dataT) deriving (Bits);

typedef struct {
   dataT data;
} RegResponse#(type dataT) deriving (Bits);

typeclass MkP4Register#(type addr, type data, type req, type resp);
   module mkP4Register#(Vector#(n, Client#(req, resp)) clients)(P4RegisterIfc#(addr, data));
endtypeclass

typedef RegRequest#(Bit#(InstanceSize), Bit#(RoundSize)) RoundRegRequest;
typedef RegResponse#(Bit#(RoundSize)) RoundRegResponse;
typedef RegRequest#(Bit#(1), Bit#(8)) RoleRegRequest;
typedef RegResponse#(Bit#(8)) RoleRegResponse;
typedef RegRequest#(Bit#(1), Bit#(64)) DatapathIdRegRequest;
typedef RegResponse#(Bit#(64)) DatapathIdRegResponse;
typedef RegRequest#(Bit#(1), Bit#(16)) InstanceRegRequest;
typedef RegResponse#(Bit#(16)) InstanceRegResponse;
typedef RegRequest#(Bit#(InstanceSize), Bit#(RoundSize)) VRoundRegRequest;
typedef RegResponse#(Bit#(RoundSize)) VRoundRegResponse;
typedef RegRequest#(Bit#(InstanceSize), Bit#(ValueSize)) ValueRegRequest;
typedef RegResponse#(Bit#(ValueSize)) ValueRegResponse;

instance MkP4Register#(Bit#(InstanceSize), Bit#(RoundSize), RoundRegRequest, RoundRegResponse);
   module mkP4Register#(Vector#(numClients, Client#(RoundRegRequest, RoundRegResponse)) clients)(P4RegisterIfc#(Bit#(InstanceSize), Bit#(RoundSize)));
      RegFile#(Bit#(InstanceSize), Bit#(RoundSize)) regFile <- mkRegFileFull();
      FIFO#(RoundRegRequest) inReqFifo <- mkFIFO;
      FIFO#(RoundRegResponse) outRespFifo <- mkFIFO;

      rule processReq;
         let req <- toGet(inReqFifo).get;
         if (req.write) begin
            regFile.upd(req.addr, req.data);
         end
         else begin
            match {.data} = regFile.sub(req.addr);
            let resp = RoundRegResponse { data: data };
            outRespFifo.enq(resp);
         end
      endrule

      Vector#(numClients, Server#(RoundRegRequest, RoundRegResponse)) servers = newVector;
      for (Integer i=0; i<valueOf(numClients); i=i+1) begin
         servers[i] = (interface Server;
            interface Put request;
               method Action put(RoundRegRequest req);
                  inReqFifo.enq(req);
               endmethod
            endinterface
            interface response = toGet(outRespFifo);
         endinterface);
      end
      zipWithM_(mkConnection, clients, servers);
   endmodule
endinstance

instance MkP4Register#(Bit#(1), Bit#(8), RoleRegRequest, RoleRegResponse);
   module mkP4Register#(Vector#(numClients, Client#(RoleRegRequest, RoleRegResponse)) clients)(P4RegisterIfc#(Bit#(1), Bit#(8)));
      RegFile#(Bit#(1), Bit#(8)) regFile <- mkRegFileFull();
      FIFO#(RoleRegRequest) inReqFifo <- mkFIFO;
      FIFO#(RoleRegResponse) outRespFifo <- mkFIFO;

      rule processReq;
         let req <- toGet(inReqFifo).get;
         if (req.write) begin
            regFile.upd(req.addr, req.data);
         end
         else begin
            match {.data} = regFile.sub(req.addr);
            let resp = RoleRegResponse { data: data };
            outRespFifo.enq(resp);
         end
      endrule

      Vector#(numClients, Server#(RoleRegRequest, RoleRegResponse)) servers = newVector;
      for (Integer i=0; i<valueOf(numClients); i=i+1) begin
         servers[i] = (interface Server;
            interface Put request;
               method Action put(RoleRegRequest req);
                  inReqFifo.enq(req);
               endmethod
            endinterface
            interface response = toGet(outRespFifo);
         endinterface);
      end
      zipWithM_(mkConnection, clients, servers);
   endmodule
endinstance

instance MkP4Register#(Bit#(1), Bit#(64), DatapathIdRegRequest, DatapathIdRegResponse);
   module mkP4Register#(Vector#(numClients, Client#(DatapathIdRegRequest, DatapathIdRegResponse)) clients)(P4RegisterIfc#(Bit#(1), Bit#(64)));
      RegFile#(Bit#(1), Bit#(64)) regFile <- mkRegFileFull();
      FIFO#(DatapathIdRegRequest) inReqFifo <- mkFIFO;
      FIFO#(DatapathIdRegResponse) outRespFifo <- mkFIFO;

      rule processReq;
         let req <- toGet(inReqFifo).get;
         if (req.write) begin
            regFile.upd(req.addr, req.data);
         end
         else begin
            match {.data} = regFile.sub(req.addr);
            let resp = DatapathIdRegResponse { data: data };
            outRespFifo.enq(resp);
         end
      endrule

      Vector#(numClients, Server#(DatapathIdRegRequest, DatapathIdRegResponse)) servers = newVector;
      for (Integer i=0; i<valueOf(numClients); i=i+1) begin
         servers[i] = (interface Server;
            interface Put request;
               method Action put(DatapathIdRegRequest req);
                  inReqFifo.enq(req);
               endmethod
            endinterface
            interface response = toGet(outRespFifo);
         endinterface);
      end
      zipWithM_(mkConnection, clients, servers);
   endmodule
endinstance

instance MkP4Register#(Bit#(1), Bit#(16), InstanceRegRequest, InstanceRegResponse);
   module mkP4Register#(Vector#(numClients, Client#(InstanceRegRequest, InstanceRegResponse)) clients)(P4RegisterIfc#(Bit#(1), Bit#(16)));
      RegFile#(Bit#(1), Bit#(16)) regFile <- mkRegFileFull();
      FIFO#(InstanceRegRequest) inReqFifo <- mkFIFO;
      FIFO#(InstanceRegResponse) outRespFifo <- mkFIFO;

      rule processReq;
         let req <- toGet(inReqFifo).get;
         if (req.write) begin
            regFile.upd(req.addr, req.data);
         end
         else begin
            match {.data} = regFile.sub(req.addr);
            let resp = InstanceRegResponse { data: data };
            outRespFifo.enq(resp);
         end
      endrule

      Vector#(numClients, Server#(InstanceRegRequest, InstanceRegResponse)) servers = newVector;
      for (Integer i=0; i<valueOf(numClients); i=i+1) begin
         servers[i] = (interface Server;
            interface Put request;
               method Action put(InstanceRegRequest req);
                  inReqFifo.enq(req);
               endmethod
            endinterface
            interface response = toGet(outRespFifo);
         endinterface);
      end
      zipWithM_(mkConnection, clients, servers);
   endmodule
endinstance

instance MkP4Register#(Bit#(InstanceSize), Bit#(ValueSize), ValueRegRequest, ValueRegResponse);
   module mkP4Register#(Vector#(numClients, Client#(ValueRegRequest, ValueRegResponse)) clients)(P4RegisterIfc#(Bit#(InstanceSize), Bit#(ValueSize)));
      RegFile#(Bit#(InstanceSize), Bit#(ValueSize)) regFile <- mkRegFileFull();
      FIFO#(ValueRegRequest) inReqFifo <- mkFIFO;
      FIFO#(ValueRegResponse) outRespFifo <- mkFIFO;

      rule processReq;
         let req <- toGet(inReqFifo).get;
         if (req.write) begin
            regFile.upd(req.addr, req.data);
         end
         else begin
            match {.data} = regFile.sub(req.addr);
            let resp = ValueRegResponse { data: data };
            outRespFifo.enq(resp);
         end
      endrule

      Vector#(numClients, Server#(ValueRegRequest, ValueRegResponse)) servers = newVector;
      for (Integer i=0; i<valueOf(numClients); i=i+1) begin
         servers[i] = (interface Server;
            interface Put request;
               method Action put(ValueRegRequest req);
                  inReqFifo.enq(req);
               endmethod
            endinterface
            interface response = toGet(outRespFifo);
         endinterface);
      end
      zipWithM_(mkConnection, clients, servers);
   endmodule
endinstance


