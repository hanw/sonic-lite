import Vector::*;
import FIFO::*;
import SpecialFIFOs::*;
import GetPut::*;
import DefaultValue::*;
import PriorityEncoder::*;

typedef struct {
   Bit#(m) v;
   Bit#(n) p;
} NodeT#(numeric type m, numeric type n) deriving (Bits, Eq);
instance DefaultValue#(NodeT#(m, n));
   defaultValue = NodeT {
      v : minBound,
      p : maxBound
   };
endinstance

interface PriorityQueue#(numeric type depth, numeric type m, numeric type n);
   method Action enq(NodeT#(m, n) v);
   method ActionValue#(NodeT#(m, n)) first();
   method Action deq();
endinterface

module mkPriorityQueue(PriorityQueue#(depth, m, n))
   provisos (Mul#(hn, 2, depth)
            ,Add#(hn, a__, depth)
            ,Add#(b__, TLog#(hn), TLog#(depth))
            ,PriorityEncoder::PEncoder#(depth));

   PulseWire pqEnqueue <- mkPulseWire;
   PulseWire pqDequeue <- mkPulseWire;
   Wire#(NodeT#(m, n)) dataOut <- mkWire;
   FIFO#(NodeT#(m, n)) incomingReq <- mkFIFO;
   Vector#(depth, Reg#(NodeT#(m, n))) sortedList <- replicateM(mkReg(defaultValue));
   Vector#(depth, Wire#(Bit#(1))) bvec <- replicateM(mkDWire(0));

   PE#(depth) priority_encoder <- mkPEncoder;

   function generateBvec(NodeT#(m, n) node, NodeT#(m, n) req);
      return 1;
   endfunction

   rule createBvec;
      let v <- toGet(incomingReq).get;
      Vector#(depth, Bit#(1)) bvec = map(uncurry(generateBvec), zip(sortedList, replicate(v)));
      $display("bvec %h", bvec);
      priority_encoder.oht.put(pack(bvec));
   endrule

   rule readLocation;
      let v <- toGet(priority_encoder.bin).get;
      $display("read location %h", v);
   endrule

   method Action enq(NodeT#(m, n) t);
      incomingReq.enq(t);
   endmethod
   method Action deq() if (curr_size > 0);
      for (Integer i=0; i < valueOf(depth)-1; i=i+1)
         sortedList[i] <= sortedList[i+1];
      sortedList[valueOf(depth)-1] <= defaultValue;
      curr_size <= curr_size - 1;
   endmethod
   method ActionValue#(NodeT#(m, n)) first();
      return sortedList[0];
   endmethod
endmodule
