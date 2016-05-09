import Arith::*;
import BRAM::*;
import BRAMCore::*;
import Connectable::*;
import FIFO::*;
import FIFOF::*;
import SpecialFIFOs::*;
import OInt::*;
import StmtFSM::*;
import Vector::*;
import Pipe::*;
import AsymmetricBRAM::*;
import TcamTypes::*;

typedef struct {
   Vector#(4, Maybe#(Bit#(9))) rpatt;
} RPatt deriving (Bits, Eq);

interface SetRam#(numeric type camDepth);
   interface Put#(TcamWriteReq#(Bit#(TLog#(camDepth)), Bit#(9))) writeServer;
   interface Server#(Tuple2#(Bit#(TLog#(camDepth)), Bit#(9)), Bit#(16)) readServer;
endinterface

module mkSetRam(SetRam#(camDepth))
   provisos(Log#(camDepth, camSz)
            ,Add#(cdep, 7, camSz)
            ,Add#(readSz, 0, 40)
            ,Add#(writeSz, 0, 10)
            ,Div#(readSz, writeSz, ratio)
            ,Log#(ratio, ratioSz)
            ,Div#(camDepth, 4, writeDepth)
            ,Log#(writeDepth, writeDepthSz)
            ,Add#(readDepthSz, ratioSz, writeDepthSz)
            ,Add#(2, a__, camSz)
            ,Add#(TLog#(cdep), 4, wAddrHWidth)
            ,Add#(readDepthSz, 0, wAddrHWidth)
            ,Add#(readDepthSz, c__, camSz));
   let verbose = True;
 
   `define SETRAM AsymmetricBRAM#(Bit#(readDepthSz), Bit#(readSz), Bit#(writeDepthSz), Bit#(writeSz))
   Vector#(4, `SETRAM) rdata <- replicateM(mkAsymmetricBRAM(True, False, "RamData"));
   `define SETRAM AsymmetricBRAM#(Bit#(readDepthSz), Bit#(readSz), Bit#(writeDepthSz), Bit#(writeSz))
   Vector#(4, `SETRAM) rmask <- replicateM(mkAsymmetricBRAM(True, False, "RamMask"));

   FIFO#(Bit#(16)) readFifo <- mkSizedFIFO(4);
   FIFO#(Bit#(9)) cPattFifo <- mkSizedFIFO(4);

   function Bit#(16) computeSetIndc(Vector#(4, RPatt) data, Vector#(4, RPatt) mask, Maybe#(Bit#(9)) cPatt);
      Vector#(16, Bool) setIndc;
      for (Integer i=0; i<4; i=i+1) begin
         for (Integer j=0; j<4; j=j+1) begin
            setIndc[i*4+j] = ((fromMaybe(0, data[i].rpatt[j]) & fromMaybe(0, mask[i].rpatt[j])) == (fromMaybe(0, mask[i].rpatt[j]) & fromMaybe(0, cPatt))) && isValid(data[i].rpatt[j]);
         end
      end
      return pack(setIndc);
   endfunction

   rule read_setram;
      Vector#(4, RPatt) data = newVector;
      Vector#(4, RPatt) mask = newVector;
      for (Integer i=0; i<4; i=i+1) begin
         let setram_data <- rdata[i].readServer.response.get;
         data[i] = unpack(setram_data);
      end
      for (Integer i=0; i<4; i=i+1) begin
         let setram_mask <- rmask[i].readServer.response.get;
         mask[i] = unpack(setram_mask);
      end
      let cPatt <- toGet(cPattFifo).get;
      Bit#(16) setIndc = computeSetIndc(data, mask, tagged Valid cPatt);
      readFifo.enq(setIndc);
   endrule

   interface Put writeServer;
      method Action put(TcamWriteReq#(Bit#(camSz), Bit#(9)) req);
         Vector#(2, Bit#(1)) wAddrLH = takeAt(2, unpack(req.addr));
         Vector#(2, Bit#(1)) wAddrLL = take(unpack(req.addr));
         Vector#(readDepthSz, Bit#(1)) wAddrH = takeAt(4, unpack(req.addr));
         Bit#(writeDepthSz) writeAddr = {pack(wAddrH), pack(wAddrLL)};
         Maybe#(Bit#(9)) writeData = tagged Valid req.data;
         Maybe#(Bit#(9)) writeMask = tagged Valid req.mask;
         if (verbose) $display("setData writeReq wAddr=", fshow(writeAddr), "wData=", fshow(writeData)," wMask=", fshow(writeMask));
         for (Integer i=0; i<4; i=i+1) begin
            if (fromInteger(i) == pack(wAddrLH)) begin
               rdata[i].writeServer.put(tuple2(writeAddr, pack(writeData)));
               rmask[i].writeServer.put(tuple2(writeAddr, pack(writeMask)));
            end
         end
      endmethod
   endinterface
   interface Server readServer;
      interface Put request;
         method Action put(Tuple2#(Bit#(camSz), Bit#(9)) req);
            let addr = tpl_1(req);
            let cPatt = tpl_2(req);
            Vector#(wAddrHWidth, Bit#(1)) wAddrH = takeAt(4, unpack(addr));
            for (Integer i=0; i<4; i=i+1) begin
               rdata[i].readServer.request.put(pack(wAddrH));
               rmask[i].readServer.request.put(pack(wAddrH));
            end
            cPattFifo.enq(cPatt);
         endmethod
      endinterface
      interface Get response = toGet(readFifo);
   endinterface
endmodule
