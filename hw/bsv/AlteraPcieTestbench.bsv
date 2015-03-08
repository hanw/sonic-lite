// Copyright (c) 2015 Cornell University.

// Permission is hereby granted, free of charge, to any person
// obtaining a copy of this software and associated documentation
// files (the "Software"), to deal in the Software without
// restriction, including without limitation the rights to use, copy,
// modify, merge, publish, distribute, sublicense, and/or sell copies
// of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:

// The above copyright notice and this permission notice shall be
// included in all copies or substantial portions of the Software.

// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
// EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
// MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
// NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS
// BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN
// ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN
// CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
// SOFTWARE.

import Clocks        ::*;
import Vector        ::*;
import Connectable   ::*;
import ConnectalAlteraCells ::*;
import ConnectalClocks      ::*;

import PS5LIB ::*;
import ALTERA_PCIE_TB_WRAPPER                 ::*;

interface PcieS5HipTbPipe;
   method Vector#(8, Bit#(8)) rxdata    ();
   method Vector#(8, Bit#(1)) rxdatak   ();
   method Vector#(8, Bit#(1)) rxelecidle();
   method Vector#(8, Bit#(3)) rxstatus  ();
   method Vector#(8, Bit#(1)) rxvalid   ();
   method Vector#(8, Bit#(1)) phystatus ();
   method Action rxpolarity   (Vector#(8, Bit#(1)) v);
   method Action txcompl      (Vector#(8, Bit#(1)) v);
   method Action txdata       (Vector#(8, Bit#(8)) v);
   method Action txdatak      (Vector#(8, Bit#(1)) v);
   method Action txdeemph     (Vector#(8, Bit#(1)) v);
   method Action txdetectrx   (Vector#(8, Bit#(1)) v);
   method Action txelecidle   (Vector#(8, Bit#(1)) v);
   method Action txmargin     (Vector#(8, Bit#(3)) v);
   method Action txswing      (Vector#(8, Bit#(1)) v);
   method Action powerdown    (Vector#(8, Bit#(2)) v);
   method Action eidleinfersel(Vector#(8, Bit#(3)) v);
   method Action sim_ltssmstate(Bit#(5) v);
   method Action sim_pipe_rate (Bit#(2) v);
   method Bit#(1) sim_pipe_pclk_in();
   method Bit#(32) test_in();
endinterface

module mkAlteraPcieTb(PcieS5HipTbPipe);
   Vector#(8, Wire#(Bit#(1))) rxpolarity_wires <- replicateM(mkDWire(0));
   Vector#(8, Wire#(Bit#(1))) txcompl_wires <- replicateM(mkDWire(0));
   Vector#(8, Wire#(Bit#(8))) txdata_wires <- replicateM(mkDWire(0));
   Vector#(8, Wire#(Bit#(1))) txdatak_wires  <- replicateM(mkDWire(0));
   Vector#(8, Wire#(Bit#(1))) txdeemph_wires   <- replicateM(mkDWire(0));
   Vector#(8, Wire#(Bit#(1))) txdetectrx_wires <- replicateM(mkDWire(0));
   Vector#(8, Wire#(Bit#(1))) txelecidle_wires <- replicateM(mkDWire(0));
   Vector#(8, Wire#(Bit#(3))) txmargin_wires <- replicateM(mkDWire(0));
   Vector#(8, Wire#(Bit#(1))) txswing_wires <- replicateM(mkDWire(0));
   Vector#(8, Wire#(Bit#(2))) powerdown_wires <- replicateM(mkDWire(0));
   Vector#(8, Wire#(Bit#(3))) eidleinfersel_wires <- replicateM(mkDWire(0));
   Wire#(Bit#(5))             sim_ltssmstate_wires <- mkDWire(0);
   Wire#(Bit#(2))             sim_pipe_rate_wires <- mkDWire(0);

   // Generated pcie testbench wrapper
   PcieTbWrap tb <- mkPcieTbWrap();

   (* no_implicit_conditions *)
   rule pcie_tx;
      tb.rxp.olarity0(rxpolarity_wires[0]);
      tb.rxp.olarity1(rxpolarity_wires[1]);
      tb.rxp.olarity2(rxpolarity_wires[2]);
      tb.rxp.olarity3(rxpolarity_wires[3]);
      tb.rxp.olarity4(rxpolarity_wires[4]);
      tb.rxp.olarity5(rxpolarity_wires[5]);
      tb.rxp.olarity6(rxpolarity_wires[6]);
      tb.rxp.olarity7(rxpolarity_wires[7]);

      tb.txc.ompl0(txcompl_wires[0]);
      tb.txc.ompl1(txcompl_wires[1]);
      tb.txc.ompl2(txcompl_wires[2]);
      tb.txc.ompl3(txcompl_wires[3]);
      tb.txc.ompl4(txcompl_wires[4]);
      tb.txc.ompl5(txcompl_wires[5]);
      tb.txc.ompl6(txcompl_wires[6]);
      tb.txc.ompl7(txcompl_wires[7]);

      tb.txd.ata0(txdata_wires[0]);
      tb.txd.ata1(txdata_wires[1]);
      tb.txd.ata2(txdata_wires[2]);
      tb.txd.ata3(txdata_wires[3]);
      tb.txd.ata4(txdata_wires[4]);
      tb.txd.ata5(txdata_wires[5]);
      tb.txd.ata6(txdata_wires[6]);
      tb.txd.ata7(txdata_wires[7]);

      tb.txd.atak0(txdatak_wires[0]);
      tb.txd.atak1(txdatak_wires[1]);
      tb.txd.atak2(txdatak_wires[2]);
      tb.txd.atak3(txdatak_wires[3]);
      tb.txd.atak4(txdatak_wires[4]);
      tb.txd.atak5(txdatak_wires[5]);
      tb.txd.atak6(txdatak_wires[6]);
      tb.txd.atak7(txdatak_wires[7]);

      tb.txd.eemph0(txdeemph_wires[0]);
      tb.txd.eemph1(txdeemph_wires[1]);
      tb.txd.eemph2(txdeemph_wires[2]);
      tb.txd.eemph3(txdeemph_wires[3]);
      tb.txd.eemph4(txdeemph_wires[4]);
      tb.txd.eemph5(txdeemph_wires[5]);
      tb.txd.eemph6(txdeemph_wires[6]);
      tb.txd.eemph7(txdeemph_wires[7]);

      tb.txd.etectrx0(txdetectrx_wires[0]);
      tb.txd.etectrx1(txdetectrx_wires[1]);
      tb.txd.etectrx2(txdetectrx_wires[2]);
      tb.txd.etectrx3(txdetectrx_wires[3]);
      tb.txd.etectrx4(txdetectrx_wires[4]);
      tb.txd.etectrx5(txdetectrx_wires[5]);
      tb.txd.etectrx6(txdetectrx_wires[6]);
      tb.txd.etectrx7(txdetectrx_wires[7]);

      tb.txe.lecidle0(txelecidle_wires[0]);
      tb.txe.lecidle1(txelecidle_wires[1]);
      tb.txe.lecidle2(txelecidle_wires[2]);
      tb.txe.lecidle3(txelecidle_wires[3]);
      tb.txe.lecidle4(txelecidle_wires[4]);
      tb.txe.lecidle5(txelecidle_wires[5]);
      tb.txe.lecidle6(txelecidle_wires[6]);
      tb.txe.lecidle7(txelecidle_wires[7]);

      tb.txm.argin0(txmargin_wires[0]);
      tb.txm.argin1(txmargin_wires[1]);
      tb.txm.argin2(txmargin_wires[2]);
      tb.txm.argin3(txmargin_wires[3]);
      tb.txm.argin4(txmargin_wires[4]);
      tb.txm.argin5(txmargin_wires[5]);
      tb.txm.argin6(txmargin_wires[6]);
      tb.txm.argin7(txmargin_wires[7]);

      tb.txs.wing0(txswing_wires[0]);
      tb.txs.wing1(txswing_wires[1]);
      tb.txs.wing2(txswing_wires[2]);
      tb.txs.wing3(txswing_wires[3]);
      tb.txs.wing4(txswing_wires[4]);
      tb.txs.wing5(txswing_wires[5]);
      tb.txs.wing6(txswing_wires[6]);
      tb.txs.wing7(txswing_wires[7]);

      tb.power.down0(powerdown_wires[0]);
      tb.power.down1(powerdown_wires[1]);
      tb.power.down2(powerdown_wires[2]);
      tb.power.down3(powerdown_wires[3]);
      tb.power.down4(powerdown_wires[4]);
      tb.power.down5(powerdown_wires[5]);
      tb.power.down6(powerdown_wires[6]);
      tb.power.down7(powerdown_wires[7]);

      tb.eidle.infersel0(eidleinfersel_wires[0]);
      tb.eidle.infersel1(eidleinfersel_wires[1]);
      tb.eidle.infersel2(eidleinfersel_wires[2]);
      tb.eidle.infersel3(eidleinfersel_wires[3]);
      tb.eidle.infersel4(eidleinfersel_wires[4]);
      tb.eidle.infersel5(eidleinfersel_wires[5]);
      tb.eidle.infersel6(eidleinfersel_wires[6]);
      tb.eidle.infersel7(eidleinfersel_wires[7]);

      tb.sim.ltssmstate(sim_ltssmstate_wires);
      tb.sim.pipe_rate(sim_pipe_rate_wires);
   endrule

   method rxdata();
      Vector#(8, Bit#(8)) retval;
      retval = unpack({tb.rxd.ata7,
                       tb.rxd.ata6,
                       tb.rxd.ata5,
                       tb.rxd.ata4,
                       tb.rxd.ata3,
                       tb.rxd.ata2,
                       tb.rxd.ata1,
                       tb.rxd.ata0
                      });
      return retval;
   endmethod

   method rxdatak();
      Vector#(8, Bit#(1)) retval;
      retval = unpack({tb.rxd.atak7,
                       tb.rxd.atak6,
                       tb.rxd.atak5,
                       tb.rxd.atak4,
                       tb.rxd.atak3,
                       tb.rxd.atak2,
                       tb.rxd.atak1,
                       tb.rxd.atak0
                      });
      return retval;
   endmethod

   method rxelecidle();
      Vector#(8, Bit#(1)) retval;
      retval = unpack({tb.rxe.lecidle7,
                       tb.rxe.lecidle6,
                       tb.rxe.lecidle5,
                       tb.rxe.lecidle4,
                       tb.rxe.lecidle3,
                       tb.rxe.lecidle2,
                       tb.rxe.lecidle1,
                       tb.rxe.lecidle0
                      });
      return retval;
   endmethod

   method rxstatus();
      Vector#(8, Bit#(3)) retval;
      retval = unpack({tb.rxs.tatus7,
                       tb.rxs.tatus6,
                       tb.rxs.tatus5,
                       tb.rxs.tatus4,
                       tb.rxs.tatus3,
                       tb.rxs.tatus2,
                       tb.rxs.tatus1,
                       tb.rxs.tatus0
                      });
      return retval;
   endmethod

   method rxvalid();
      Vector#(8, Bit#(1)) retval;
      retval = unpack({tb.rxv.alid7,
                       tb.rxv.alid6,
                       tb.rxv.alid5,
                       tb.rxv.alid4,
                       tb.rxv.alid3,
                       tb.rxv.alid2,
                       tb.rxv.alid1,
                       tb.rxv.alid0
                      });
      return retval;
   endmethod

   method phystatus();
      Vector#(8, Bit#(1)) retval;
      retval = unpack({tb.phy.status7,
                       tb.phy.status6,
                       tb.phy.status5,
                       tb.phy.status4,
                       tb.phy.status3,
                       tb.phy.status2,
                       tb.phy.status1,
                       tb.phy.status0
                      });
      return retval;
   endmethod

   method Action rxpolarity (Vector#(8, Bit#(1)) v);
      writeVReg(rxpolarity_wires, v);
   endmethod
   method Action txcompl    (Vector#(8, Bit#(1)) v);
      writeVReg(txcompl_wires, v);
   endmethod
   method Action txdata     (Vector#(8, Bit#(8)) v);
      writeVReg(txdata_wires, v);
   endmethod
   method Action txdatak    (Vector#(8, Bit#(1)) v);
      writeVReg(txdatak_wires, v);
   endmethod
   method Action txdeemph   (Vector#(8, Bit#(1)) v);
      writeVReg(txdeemph_wires, v);
   endmethod
   method Action txdetectrx (Vector#(8, Bit#(1)) v);
      writeVReg(txdetectrx_wires, v);
   endmethod
   method Action txelecidle (Vector#(8, Bit#(1)) v);
      writeVReg(txelecidle_wires, v);
   endmethod
   method Action txmargin   (Vector#(8, Bit#(3)) v);
      writeVReg(txmargin_wires, v);
   endmethod
   method Action txswing    (Vector#(8, Bit#(1)) v);
      writeVReg(txswing_wires, v);
   endmethod
   method Action powerdown  (Vector#(8, Bit#(2)) v);
      writeVReg(powerdown_wires, v);
   endmethod
   method Action eidleinfersel(Vector#(8, Bit#(3)) v);
      writeVReg(eidleinfersel_wires, v);
   endmethod

   method sim_pipe_pclk_in ();
      return tb.sim.pipe_pclk_in;
   endmethod

   method Action sim_ltssmstate(Bit#(5) v);
      sim_ltssmstate_wires <= v;
   endmethod

   method Action sim_pipe_rate(Bit#(2) v);
      sim_pipe_rate_wires <= v;
   endmethod
endmodule

instance Connectable#(PcieS5HipTbPipe, PcieS5HipPipe);
module mkConnection#(PcieS5HipTbPipe tb, PcieS5HipPipe dut)(Empty);
   (* no_implicit_conditions, fire_when_enabled *)
   rule tb_to_dut;
      dut.rxdata(tb.rxdata);
      dut.rxdatak(tb.rxdatak);
      dut.rxelecidle(tb.rxelecidle);
      dut.rxstatus(tb.rxstatus);
      dut.rxvalid(tb.rxvalid);
      dut.phystatus(tb.phystatus);
      dut.sim_pipe_pclk_in(tb.sim_pipe_pclk_in);
   endrule

   (* no_implicit_conditions, fire_when_enabled *)
   rule dut_to_tb;
      tb.rxpolarity(dut.rxpolarity);
      tb.txcompl(dut.txcompl);
      tb.txdata(dut.txdata);
      tb.txdatak(dut.txdatak);
      tb.txdeemph(dut.txdeemph);
      tb.txdetectrx(dut.txdetectrx);
      tb.txelecidle(dut.txelecidle);
      tb.txmargin(dut.txmargin);
      tb.txswing(dut.txswing);
      tb.powerdown(dut.powerdown);
      tb.eidleinfersel(dut.eidleinfersel);
      tb.sim_ltssmstate(dut.sim_ltssmstate);
      tb.sim_pipe_rate(dut.sim_pipe_rate);
   endrule
endmodule
endinstance
