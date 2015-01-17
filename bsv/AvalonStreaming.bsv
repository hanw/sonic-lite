/*****************************************************************************
 AvalonStreaming
 ===============
 Simon Moore, May 2010
 
 This library provides Bluespec wrappers for Altera's Avalon Streaming
 interface.

 * Names - SOPC Builder expects the following names to be used for streaming
   interfaces (i.e. these are the names you should use in the top-level
   interface):
    * aso - Avalon-ST source
    * asi - Avalon-ST sink
  
 *****************************************************************************/

package AvalonStreaming;

import GetPut::*;
import FIFOF::*;

/*****************************************************************************
 Source Stream
 *****************************************************************************/

// Avalon-ST source physical interface.  Note that names of modules
// match SOPC's expectations.
(* always_ready, always_enabled *)
interface AvalonStreamSourcePhysicalIfc#(numeric type dataT_width);
   method Bit#(dataT_width) stream_out_data;
   method Bool stream_out_valid;
   method Action stream_out(Bool ready);
endinterface

interface AvalonStreamSourceVerboseIfc#(type dataT, numeric type dataT_width);
   interface Put#(dataT) tx;
   interface AvalonStreamSourcePhysicalIfc#(dataT_width) physical;
endinterface

typedef AvalonStreamSourceVerboseIfc#(dataT,SizeOf#(dataT)) AvalonStreamSourceIfc#(type dataT);

module mkPut2AvalonStreamSource(AvalonStreamSourceVerboseIfc#(dataT,dataT_width))
   provisos(Bits#(dataT,dataT_width));
   
   Wire#(Maybe#(Bit#(dataT_width))) data_dw <- mkDWire(tagged Invalid);
   Wire#(Bool) ready_w <- mkBypassWire;
   
   interface Put tx;
      method Action put(dataT d) if(ready_w);
	 data_dw <= tagged Valid pack(d);
      endmethod
   endinterface

   interface AvalonStreamSourcePhysicalIfc physical;
      method Bit#(dataT_width) stream_out_data;
	 return fromMaybe(0,data_dw);
      endmethod
      method Bool stream_out_valid;
	 return isValid(data_dw);
      endmethod
      method Action stream_out(Bool ready);
	 ready_w <= ready;
      endmethod
   endinterface
endmodule


/*****************************************************************************
 Sink Stream
 *****************************************************************************/

// Avalon-ST sink physical interface.  Note that names of modules
// match SOPC's expectations.

(* always_ready, always_enabled *)
interface AvalonStreamSinkPhysicalIfc#(type dataT_width);
   method Action stream_in(Bit#(dataT_width) data, Bool valid);
   method Bool stream_in_ready;
endinterface

interface AvalonStreamSinkVerboseIfc#(type dataT, numeric type dataT_width);
   interface Get#(dataT) rx;
   interface AvalonStreamSinkPhysicalIfc#(dataT_width) physical;
endinterface

typedef AvalonStreamSinkVerboseIfc#(dataT,SizeOf#(dataT)) AvalonStreamSinkIfc#(type dataT);


module mkAvalonStreamSink2Get(AvalonStreamSinkVerboseIfc#(dataT,dataT_width))
   provisos(Bits#(dataT,dataT_width));
   
   FIFOF#(dataT) f <- mkLFIFOF;
   Wire#(Maybe#(dataT)) d_dw <- mkDWire(tagged Invalid);
   
   rule push_data_into_fifo (isValid(d_dw));
      f.enq(fromMaybe(?,d_dw));
   endrule
   
   interface Get rx = toGet(f);

   interface AvalonStreamSinkPhysicalIfc physical;
      // method to receive data.  Note that the data should be held
      // until stream_in_ready is True, i.e. there is room in the internal
      // FIFO - f - so we should never loose data from our d_dw DWire
      method Action stream_in(Bit#(dataT_width) data, Bool valid);
	 if(valid)
	    d_dw <= tagged Valid unpack(data);
      endmethod
      method Bool stream_in_ready;
	 return f.notFull;
      endmethod
   endinterface
endmodule


endpackage
