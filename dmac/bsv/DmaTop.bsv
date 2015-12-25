//`include "ConnectalProjectConfig.bsv"

import FIFOF::*;
import GetPut::*;
import Connectable::*;
import Vector::*;
import BuildVector::*;
import ConnectalConfig::*;
import DmaTopPins::*;
import DmaController::*;
import Pipe::*;
import MemTypes::*;

`ifndef DataBusWidth
`define DataBusWidth 128
`endif

interface DmaTop;
   // request from software
   interface DmaRequest request0;
   interface DmaRequest request1;
   interface DmaRequest request2;
/*   interface DmaRequest request3;
   interface DmaRequest request4;
   interface DmaRequest request5;
   interface DmaRequest request6;
   interface DmaRequest request7;*/

   // memory interfaces connected to MemServer
   interface Vector#(1,MemReadClient#(DataBusWidth))      readClient;
   interface Vector#(1,MemWriteClient#(DataBusWidth))     writeClient;
   interface DmaTopPins pins;
endinterface

module mkDmaTop#(DmaIndication dmaIndication0,
		  DmaIndication dmaIndication1,
		  DmaIndication dmaIndication2
/*		  DmaIndication dmaIndication3,
		  DmaIndication dmaIndication4,
		  DmaIndication dmaIndication5,
		  DmaIndication dmaIndication6,
		  DmaIndication dmaIndication7*/
		  )(DmaTop);

   Vector#(NumChannels,DmaIndication) dmaIndications = vec(dmaIndication0,
							   dmaIndication1,
							   dmaIndication2
/*							   dmaIndication3,
							   dmaIndication4,
							   dmaIndication5,
							   dmaIndication6,
							   dmaIndication7*/
                        );
   DmaController#(NumChannels) dmaController <- mkDmaController(dmaIndications);
   let defaultClock <- exposeCurrentClock;
   let defaultReset <- exposeCurrentReset;

   for (Integer channel = 0; channel < valueOf(NumChannels); channel = channel + 1) begin
      Reg#(Bit#(16)) iter <- mkReg(0);
      rule toFpgaRule;
          PipeOut#(MemDataF#(DataBusWidth)) toFpgaPipe = dmaController.toFpga[channel];
          MemDataF#(DataBusWidth) md = toFpgaPipe.first();
          toFpgaPipe.deq();
          // insert code here to consume md
      endrule
      rule fromFpgaRule;
          // placeholder code to produce md
          // tag, first, and last are not checked by the library
          MemDataF#(DataBusWidth) md = MemDataF {data: ('hdada << 32) | (fromInteger(channel) << 16) | extend(iter),
                        tag: 0, first: False, last: False};
          PipeIn#(MemDataF#(DataBusWidth)) fromFpgaPipe = dmaController.fromFpga[channel];
          fromFpgaPipe.enq(md);
          iter <= iter + 1;
      endrule
   end

   interface readClient  = dmaController.readClient;
   interface writeClient = dmaController.writeClient;
   interface request0 = dmaController.request[0];
   interface request1 = dmaController.request[1];
   interface request2 = dmaController.request[2];
/*   interface request3 = dmaController.request[3];
   interface request4 = dmaController.request[4];
   interface request5 = dmaController.request[5];
   interface request6 = dmaController.request[6];
   interface request7 = dmaController.request[7];*/
   interface DmaTopPins pins;
      interface clock = defaultClock;
      interface reset = defaultReset;
      interface toFpga = dmaController.toFpga;
      interface fromFpga = dmaController.fromFpga;
   endinterface
endmodule
