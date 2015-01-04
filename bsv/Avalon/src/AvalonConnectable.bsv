import Connectable::*;

instance Connectable#(AvalonMasterWires#(address_width, data_width), AvalonMasterInverseWires#(address_width, data_width));
   module mkConnection#(AvalonMasterWires#(address_width, data_width) master, AvalonMasterInverseWires#(address_width, data_width) slave) (Empty);
      (* no_implicit_conditions *)
      rule connectAvalonWires;
         slave.read(master.read);
         slave.write(master.write);
         slave.address(master.address);
         slave.writedata(master.writedata);
         master.readdata(slave.readdata);
         master.waitrequest(slave.waitrequest);
         master.readdatavalid(slave.readdatavalid);
      endrule      
   endmodule   
endinstance

instance Connectable#(AvalonMasterInverseWires#(address_width, data_width), AvalonMasterWires#(address_width, data_width));
   module mkConnection#(AvalonMasterInverseWires#(address_width, data_width) slave, AvalonMasterWires#(address_width, data_width) master) (Empty);
      mkConnection(master, slave);
   endmodule   
endinstance

