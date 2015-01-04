interface AvalonWrapper#(numeric type address_width, numeric type data_width);
   interface AvalonMasterWires#(address_width, data_width) masterWires;
   interface AvalonMasterInverseWires#(address_width, data_width)  masterInverseWires;
endinterface

module mkAvalonWrapper(AvalonWrapper#(address_width, data_width));
   
   let readW          <- mkDWire(?);
   let writeW         <- mkDWire(?);
   let addressW       <- mkDWire(?);
   let writedataW     <- mkDWire(?);
   let readdataW      <- mkDWire(?);
   let waitrequestW   <- mkDWire(?);
   let readdatavalidW <- mkDWire(?);
   
   interface AvalonMasterWires masterWires;
      method Bit#(1) read();
         return readW;
      endmethod
  
      method Bit#(1) write();
         return writeW;
      endmethod

      method Bit#(address_width) address();
         return addressW;
      endmethod

      method Bit#(data_width) writedata();  
         return writedataW;
      endmethod

      method Action readdata(Bit#(data_width) readdataNew);
         readdataW <= readdataNew;
      endmethod

      method Action waitrequest(Bit#(1) waitrequestNew);
         waitrequestW <= waitrequestNew;
      endmethod

      method Action readdatavalid(Bit#(1) readdatavalidNew);
         readdatavalidW <= readdatavalidNew;
      endmethod
   endinterface

  interface AvalonMasterInverseWires masterInverseWires;

    method Action read(Bit#(1) readIn);
      readW <= readIn;  
    endmethod

    method Action write(Bit#(1) writeIn);
      writeW <= writeIn;  
    endmethod

    method Action address(Bit#(address_width) addressIn);
      addressW <= addressIn;  
    endmethod

    method Bit#(data_width) readdata();  
      return readdataW;
    endmethod

    method Action writedata(Bit#(data_width) writedataValue);
      writedataW <= writedataValue;
    endmethod

    method Bit#(1) waitrequest();
      return waitrequestW;
    endmethod

    method Bit#(1) readdatavalid();
      return readdatavalidW;
    endmethod

  endinterface
   
endmodule      
      