import PcieAlteraLIB           ::*;
import ALTERA_PCIE_TB_WRAPPER  ::*;

interface PcieAlteraTb;
   interface PcieS5HipPipeTB hip;
endinterface

module mkPcieAlteraTb(PcieAlteraTestb);
   Vector#(8, Wire#(Bit#(1))) rxpolarity_wires <- replicateM(mkDWire(0));
   Vector#(8, Wire#(Bit#(8))) txdata_wires <- replicateM(mkDWire(0));
   Vector#(8, Wire#(Bit#(1))) txdatak_wires <- replicateM(mkDWire(0));
   Vector#(8, Wire#(Bit#(1))) txcompl_wires <- replicateM(mkDWire(0));
   Vector#(8, Wire#(Bit#(1))) txdeemph_wires <- replicateM(mkDWire(0));
   Vector#(8, Wire#(Bit#(1))) txelecidle_wires <- replicateM(mkDWire(0));
   Vector#(8, Wire#(Bit#(3))) txmargin_wires <- replicateM(mkDWire(0));
   Vector#(8, Wire#(Bit#(2))) powerdown_wires <- replicateM(mkDWire(0));
   Vector#(8, Wire#(Bit#(3))) eidleinfersel_wires <- replicateM(mkDWire(0));

   PcieTbWrap tb <- mkPcieTbWrap;

   interface PcieS5HipPipeTB hip;
      method Action rxpolarity (Vector#(8, Bit#(1)) a);
         writeVReg(rxpolarity_wires, a);
      endmethod
      method Action txcompl (Vector#(8, Bit#(1)) a);
         writeVReg(txcompl_wires, a);
      endmethod
      method Action txdata (Vector#(8, Bit#(1)) a);
         writeVReg(txdata_wires, a);
      endmethod
      method Action txdatak (Vector#(8, Bit#(1)) a);
         writeVReg(txdatak_wires, a);
      endmethod
      method Action txdeemph (Vector#(8, Bit#(1)) a);
         writeVReg(txdeemph_wires, a);
      endmethod
      method Action txelecidle (Vector#(8, Bit#(1)) a);
         writeVReg(txelecidle_wires, a);
      endmethod
      method Action txmargin (Vector#(8, Bit#(1)) a);
         writeVReg(txmargin_wires, a);
      endmethod
      method Action powerdown (Vector#(8, Bit#(1)) a);
         writeVReg(powerdown_wires, a);
      endmethod
      method Action eidleinfersel (Vector#(8, Bit#(1)) a);
         writeVReg(eidleinfersel_wires, a);
      endmethod

      method rxdata();
         Bit#(8) d = {pcie.rxd.ata[7],
                      pcie.rxd.ata[6],
                      pcie.rxd.ata[5],
                      pcie.rxd.ata[4],
                      pcie.rxd.ata[3],
                      pcie.rxd.ata[2],
                      pcie.rxd.ata[1],
                      pcie.rxd.ata[0]};
         Vector#(8, Bit#(1)) retval = unpack(d);
         return retval;
      endmethod
      method rxdatak();
         Bit#(8) d = {pcie.rxd.atak[7],
                      pcie.rxd.atak[6],
                      pcie.rxd.atak[5],
                      pcie.rxd.atak[4],
                      pcie.rxd.atak[3],
                      pcie.rxd.atak[2],
                      pcie.rxd.atak[1],
                      pcie.rxd.atak[0]};
         Vector#(8, Bit#(1)) retval = unpack(d);
         return retval;
      endmethod
      method rxelecidle();
         Bit#(8) d = {pcie.rxe.lecidle[7],
                      pcie.rxe.lecidle[6],
                      pcie.rxe.lecidle[5],
                      pcie.rxe.lecidle[4],
                      pcie.rxe.lecidle[3],
                      pcie.rxe.lecidle[2],
                      pcie.rxe.lecidle[1],
                      pcie.rxe.lecidle[0]};
         Vector#(8, Bit#(1)) retval = unpack(d);
         return retval;
      endmethod
      method rxstatus();
         Bit#(8) d = {pcie.rxs.tatus[7],
                      pcie.rxs.tatus[6],
                      pcie.rxs.tatus[5],
                      pcie.rxs.tatus[4],
                      pcie.rxs.tatus[3],
                      pcie.rxs.tatus[2],
                      pcie.rxs.tatus[1],
                      pcie.rxs.tatus[0]};
         Vector#(8, Bit#(1)) retval = unpack(d);
         return retval;
      endmethod
      method rxvalid();
         Bit#(8) d = {pcie.rxv.alid[7],
                      pcie.rxv.alid[6],
                      pcie.rxv.alid[5],
                      pcie.rxv.alid[4],
                      pcie.rxv.alid[3],
                      pcie.rxv.alid[2],
                      pcie.rxv.alid[1],
                      pcie.rxv.alid[0]};
         Vector#(8, Bit#(1)) retval = unpack(d);
         return retval;
      endmethod
      method phystatus();
         Bit#(8) d = {pcie.phy.status[7],
                      pcie.phy.status[6],
                      pcie.phy.status[5],
                      pcie.phy.status[4],
                      pcie.phy.status[3],
                      pcie.phy.status[2],
                      pcie.phy.status[1],
                      pcie.phy.status[0]};
         Vector#(8, Bit#(1)) retval = unpack(d);
         return retval;
      endmethod
   endinterface
endmodule
