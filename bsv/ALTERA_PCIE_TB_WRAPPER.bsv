
/*
   /home/hwang/dev/sonic-lite/scripts/../../connectal//generated/scripts/importbvi.py
   -o
   ALTERA_PCIE_TB_WRAPPER.bsv
   -I
   PcieTbWrap
   -P
   PcieTbWrap
   -r
   pin_perst
   -r
   npor
   -r
   reset_status
   -c
   refclk
   -c
   coreclkout_hip
   -f
   serdes
   -f
   pld
   -f
   dl
   -f
   ev128
   -f
   ev1
   -f
   hotrst
   -f
   l2
   -f
   current
   -f
   derr
   -f
   lane
   -f
   ltssm
   -f
   reconfig
   -f
   tx_cred
   -f
   tx_par
   -f
   tx_s
   -f
   txd
   -f
   txe
   -f
   txc
   -f
   txm
   -f
   txs
   -f
   tx
   -f
   tx_cred
   -f
   rx_par
   -f
   rx_s
   -f
   rxd
   -f
   rxr
   -f
   rxe
   -f
   rxp
   -f
   rxs
   -f
   rxv
   -f
   rx
   -f
   cfg_par
   -f
   eidle
   -f
   power
   -f
   phy
   -f
   int_s
   -f
   cpl
   -f
   tl
   -f
   pm_e
   -f
   pme
   -f
   pm
   -f
   simu
   -f
   sim
   -f
   test_in
   ../../connectal/out/de5/synthesis/altera_pcie_testbench.v
*/

import Clocks::*;
import DefaultValue::*;
import XilinxCells::*;
import GetPut::*;

(* always_ready, always_enabled *)
interface PcietbwrapEidle;
    method Action      infersel0(Bit#(3) v);
    method Action      infersel1(Bit#(3) v);
    method Action      infersel2(Bit#(3) v);
    method Action      infersel3(Bit#(3) v);
endinterface
(* always_ready, always_enabled *)
interface PcietbwrapPhy;
    method Bit#(1)     status0();
    method Bit#(1)     status1();
    method Bit#(1)     status2();
    method Bit#(1)     status3();
endinterface
(* always_ready, always_enabled *)
interface PcietbwrapPin;
    method Reset     perst();
endinterface
(* always_ready, always_enabled *)
interface PcietbwrapPower;
    method Action      down0(Bit#(2) v);
    method Action      down1(Bit#(2) v);
    method Action      down2(Bit#(2) v);
    method Action      down3(Bit#(2) v);
endinterface
(* always_ready, always_enabled *)
interface PcietbwrapRx;
    method Bit#(1)     in0();
    method Bit#(1)     in1();
    method Bit#(1)     in2();
    method Bit#(1)     in3();
endinterface
(* always_ready, always_enabled *)
interface PcietbwrapRxd;
    method Bit#(8)     ata0();
    method Bit#(8)     ata1();
    method Bit#(8)     ata2();
    method Bit#(8)     ata3();
    method Bit#(1)     atak0();
    method Bit#(1)     atak1();
    method Bit#(1)     atak2();
    method Bit#(1)     atak3();
endinterface
(* always_ready, always_enabled *)
interface PcietbwrapRxe;
    method Bit#(1)     lecidle0();
    method Bit#(1)     lecidle1();
    method Bit#(1)     lecidle2();
    method Bit#(1)     lecidle3();
endinterface
(* always_ready, always_enabled *)
interface PcietbwrapRxp;
    method Action      olarity0(Bit#(1) v);
    method Action      olarity1(Bit#(1) v);
    method Action      olarity2(Bit#(1) v);
    method Action      olarity3(Bit#(1) v);
endinterface
(* always_ready, always_enabled *)
interface PcietbwrapRxs;
    method Bit#(3)     tatus0();
    method Bit#(3)     tatus1();
    method Bit#(3)     tatus2();
    method Bit#(3)     tatus3();
endinterface
(* always_ready, always_enabled *)
interface PcietbwrapRxv;
    method Bit#(1)     alid0();
    method Bit#(1)     alid1();
    method Bit#(1)     alid2();
    method Bit#(1)     alid3();
endinterface
(* always_ready, always_enabled *)
interface PcietbwrapSim;
    method Action      ltssmstate(Bit#(5) v);
    method Bit#(1)     pipe_pclk_in();
    method Action      pipe_rate(Bit#(2) v);
endinterface
(* always_ready, always_enabled *)
interface PcietbwrapSimu;
    method Bit#(1)     mode_pipe();
endinterface
(* always_ready, always_enabled *)
interface PcietbwrapTest;
    method Bit#(32)     in();
endinterface
(* always_ready, always_enabled *)
interface PcietbwrapTx;
    method Action      out0(Bit#(1) v);
    method Action      out1(Bit#(1) v);
    method Action      out2(Bit#(1) v);
    method Action      out3(Bit#(1) v);
endinterface
(* always_ready, always_enabled *)
interface PcietbwrapTxc;
    method Action      ompl0(Bit#(1) v);
    method Action      ompl1(Bit#(1) v);
    method Action      ompl2(Bit#(1) v);
    method Action      ompl3(Bit#(1) v);
endinterface
(* always_ready, always_enabled *)
interface PcietbwrapTxd;
    method Action      ata0(Bit#(8) v);
    method Action      ata1(Bit#(8) v);
    method Action      ata2(Bit#(8) v);
    method Action      ata3(Bit#(8) v);
    method Action      atak0(Bit#(1) v);
    method Action      atak1(Bit#(1) v);
    method Action      atak2(Bit#(1) v);
    method Action      atak3(Bit#(1) v);
    method Action      eemph0(Bit#(1) v);
    method Action      eemph1(Bit#(1) v);
    method Action      eemph2(Bit#(1) v);
    method Action      eemph3(Bit#(1) v);
    method Action      etectrx0(Bit#(1) v);
    method Action      etectrx1(Bit#(1) v);
    method Action      etectrx2(Bit#(1) v);
    method Action      etectrx3(Bit#(1) v);
endinterface
(* always_ready, always_enabled *)
interface PcietbwrapTxe;
    method Action      lecidle0(Bit#(1) v);
    method Action      lecidle1(Bit#(1) v);
    method Action      lecidle2(Bit#(1) v);
    method Action      lecidle3(Bit#(1) v);
endinterface
(* always_ready, always_enabled *)
interface PcietbwrapTxm;
    method Action      argin0(Bit#(3) v);
    method Action      argin1(Bit#(3) v);
    method Action      argin2(Bit#(3) v);
    method Action      argin3(Bit#(3) v);
endinterface
(* always_ready, always_enabled *)
interface PcietbwrapTxs;
    method Action      wing0(Bit#(1) v);
    method Action      wing1(Bit#(1) v);
    method Action      wing2(Bit#(1) v);
    method Action      wing3(Bit#(1) v);
endinterface
(* always_ready, always_enabled *)
interface PcieTbWrap;
    interface PcietbwrapEidle     eidle;
    method Reset     npor();
    interface PcietbwrapPhy     phy;
    interface PcietbwrapPin     pin;
    interface PcietbwrapPower     power;
    interface Clock     refclk;
    interface PcietbwrapRx     rx;
    interface PcietbwrapRxd     rxd;
    interface PcietbwrapRxe     rxe;
    interface PcietbwrapRxp     rxp;
    interface PcietbwrapRxs     rxs;
    interface PcietbwrapRxv     rxv;
    interface PcietbwrapSim     sim;
    interface PcietbwrapSimu     simu;
    interface PcietbwrapTest     test;
    interface PcietbwrapTx     tx;
    interface PcietbwrapTxc     txc;
    interface PcietbwrapTxd     txd;
    interface PcietbwrapTxe     txe;
    interface PcietbwrapTxm     txm;
    interface PcietbwrapTxs     txs;
endinterface
import "BVI" altera_pcie_testbench =
module mkPcieTbWrap(PcieTbWrap);
    default_clock clk();
    default_reset rst();
    interface PcietbwrapEidle     eidle;
        method infersel0(eidleinfersel0) enable((*inhigh*) EN_eidleinfersel0);
        method infersel1(eidleinfersel1) enable((*inhigh*) EN_eidleinfersel1);
        method infersel2(eidleinfersel2) enable((*inhigh*) EN_eidleinfersel2);
        method infersel3(eidleinfersel3) enable((*inhigh*) EN_eidleinfersel3);
    endinterface
    output_reset npor(npor);
    interface PcietbwrapPhy     phy;
        method phystatus0 status0();
        method phystatus1 status1();
        method phystatus2 status2();
        method phystatus3 status3();
    endinterface
    interface PcietbwrapPin     pin;
        output_reset perst(pin_perst);
    endinterface
    interface PcietbwrapPower     power;
        method down0(powerdown0) enable((*inhigh*) EN_powerdown0);
        method down1(powerdown1) enable((*inhigh*) EN_powerdown1);
        method down2(powerdown2) enable((*inhigh*) EN_powerdown2);
        method down3(powerdown3) enable((*inhigh*) EN_powerdown3);
    endinterface
    output_clock refclk(refclk);
    interface PcietbwrapRx     rx;
        method rx_in0 in0();
        method rx_in1 in1();
        method rx_in2 in2();
        method rx_in3 in3();
    endinterface
    interface PcietbwrapRxd     rxd;
        method rxdata0 ata0();
        method rxdata1 ata1();
        method rxdata2 ata2();
        method rxdata3 ata3();
        method rxdatak0 atak0();
        method rxdatak1 atak1();
        method rxdatak2 atak2();
        method rxdatak3 atak3();
    endinterface
    interface PcietbwrapRxe     rxe;
        method rxelecidle0 lecidle0();
        method rxelecidle1 lecidle1();
        method rxelecidle2 lecidle2();
        method rxelecidle3 lecidle3();
    endinterface
    interface PcietbwrapRxp     rxp;
        method olarity0(rxpolarity0) enable((*inhigh*) EN_rxpolarity0);
        method olarity1(rxpolarity1) enable((*inhigh*) EN_rxpolarity1);
        method olarity2(rxpolarity2) enable((*inhigh*) EN_rxpolarity2);
        method olarity3(rxpolarity3) enable((*inhigh*) EN_rxpolarity3);
    endinterface
    interface PcietbwrapRxs     rxs;
        method rxstatus0 tatus0();
        method rxstatus1 tatus1();
        method rxstatus2 tatus2();
        method rxstatus3 tatus3();
    endinterface
    interface PcietbwrapRxv     rxv;
        method rxvalid0 alid0();
        method rxvalid1 alid1();
        method rxvalid2 alid2();
        method rxvalid3 alid3();
    endinterface
    interface PcietbwrapSim     sim;
        method ltssmstate(sim_ltssmstate) enable((*inhigh*) EN_sim_ltssmstate);
        method sim_pipe_pclk_in pipe_pclk_in();
        method pipe_rate(sim_pipe_rate) enable((*inhigh*) EN_sim_pipe_rate);
    endinterface
    interface PcietbwrapSimu     simu;
        method simu_mode_pipe mode_pipe();
    endinterface
    interface PcietbwrapTest     test;
        method test_in in();
    endinterface
    interface PcietbwrapTx     tx;
        method out0(tx_out0) enable((*inhigh*) EN_tx_out0);
        method out1(tx_out1) enable((*inhigh*) EN_tx_out1);
        method out2(tx_out2) enable((*inhigh*) EN_tx_out2);
        method out3(tx_out3) enable((*inhigh*) EN_tx_out3);
    endinterface
    interface PcietbwrapTxc     txc;
        method ompl0(txcompl0) enable((*inhigh*) EN_txcompl0);
        method ompl1(txcompl1) enable((*inhigh*) EN_txcompl1);
        method ompl2(txcompl2) enable((*inhigh*) EN_txcompl2);
        method ompl3(txcompl3) enable((*inhigh*) EN_txcompl3);
    endinterface
    interface PcietbwrapTxd     txd;
        method ata0(txdata0) enable((*inhigh*) EN_txdata0);
        method ata1(txdata1) enable((*inhigh*) EN_txdata1);
        method ata2(txdata2) enable((*inhigh*) EN_txdata2);
        method ata3(txdata3) enable((*inhigh*) EN_txdata3);
        method atak0(txdatak0) enable((*inhigh*) EN_txdatak0);
        method atak1(txdatak1) enable((*inhigh*) EN_txdatak1);
        method atak2(txdatak2) enable((*inhigh*) EN_txdatak2);
        method atak3(txdatak3) enable((*inhigh*) EN_txdatak3);
        method eemph0(txdeemph0) enable((*inhigh*) EN_txdeemph0);
        method eemph1(txdeemph1) enable((*inhigh*) EN_txdeemph1);
        method eemph2(txdeemph2) enable((*inhigh*) EN_txdeemph2);
        method eemph3(txdeemph3) enable((*inhigh*) EN_txdeemph3);
        method etectrx0(txdetectrx0) enable((*inhigh*) EN_txdetectrx0);
        method etectrx1(txdetectrx1) enable((*inhigh*) EN_txdetectrx1);
        method etectrx2(txdetectrx2) enable((*inhigh*) EN_txdetectrx2);
        method etectrx3(txdetectrx3) enable((*inhigh*) EN_txdetectrx3);
    endinterface
    interface PcietbwrapTxe     txe;
        method lecidle0(txelecidle0) enable((*inhigh*) EN_txelecidle0);
        method lecidle1(txelecidle1) enable((*inhigh*) EN_txelecidle1);
        method lecidle2(txelecidle2) enable((*inhigh*) EN_txelecidle2);
        method lecidle3(txelecidle3) enable((*inhigh*) EN_txelecidle3);
    endinterface
    interface PcietbwrapTxm     txm;
        method argin0(txmargin0) enable((*inhigh*) EN_txmargin0);
        method argin1(txmargin1) enable((*inhigh*) EN_txmargin1);
        method argin2(txmargin2) enable((*inhigh*) EN_txmargin2);
        method argin3(txmargin3) enable((*inhigh*) EN_txmargin3);
    endinterface
    interface PcietbwrapTxs     txs;
        method wing0(txswing0) enable((*inhigh*) EN_txswing0);
        method wing1(txswing1) enable((*inhigh*) EN_txswing1);
        method wing2(txswing2) enable((*inhigh*) EN_txswing2);
        method wing3(txswing3) enable((*inhigh*) EN_txswing3);
    endinterface
    schedule (eidle.infersel0, eidle.infersel1, eidle.infersel2, eidle.infersel3, phy.status0, phy.status1, phy.status2, phy.status3, power.down0, power.down1, power.down2, power.down3, rx.in0, rx.in1, rx.in2, rx.in3, rxd.ata0, rxd.ata1, rxd.ata2, rxd.ata3, rxd.atak0, rxd.atak1, rxd.atak2, rxd.atak3, rxe.lecidle0, rxe.lecidle1, rxe.lecidle2, rxe.lecidle3, rxp.olarity0, rxp.olarity1, rxp.olarity2, rxp.olarity3, rxs.tatus0, rxs.tatus1, rxs.tatus2, rxs.tatus3, rxv.alid0, rxv.alid1, rxv.alid2, rxv.alid3, sim.ltssmstate, sim.pipe_pclk_in, sim.pipe_rate, simu.mode_pipe, test.in, tx.out0, tx.out1, tx.out2, tx.out3, txc.ompl0, txc.ompl1, txc.ompl2, txc.ompl3, txd.ata0, txd.ata1, txd.ata2, txd.ata3, txd.atak0, txd.atak1, txd.atak2, txd.atak3, txd.eemph0, txd.eemph1, txd.eemph2, txd.eemph3, txd.etectrx0, txd.etectrx1, txd.etectrx2, txd.etectrx3, txe.lecidle0, txe.lecidle1, txe.lecidle2, txe.lecidle3, txm.argin0, txm.argin1, txm.argin2, txm.argin3, txs.wing0, txs.wing1, txs.wing2, txs.wing3) CF (eidle.infersel0, eidle.infersel1, eidle.infersel2, eidle.infersel3, phy.status0, phy.status1, phy.status2, phy.status3, power.down0, power.down1, power.down2, power.down3, rx.in0, rx.in1, rx.in2, rx.in3, rxd.ata0, rxd.ata1, rxd.ata2, rxd.ata3, rxd.atak0, rxd.atak1, rxd.atak2, rxd.atak3, rxe.lecidle0, rxe.lecidle1, rxe.lecidle2, rxe.lecidle3, rxp.olarity0, rxp.olarity1, rxp.olarity2, rxp.olarity3, rxs.tatus0, rxs.tatus1, rxs.tatus2, rxs.tatus3, rxv.alid0, rxv.alid1, rxv.alid2, rxv.alid3, sim.ltssmstate, sim.pipe_pclk_in, sim.pipe_rate, simu.mode_pipe, test.in, tx.out0, tx.out1, tx.out2, tx.out3, txc.ompl0, txc.ompl1, txc.ompl2, txc.ompl3, txd.ata0, txd.ata1, txd.ata2, txd.ata3, txd.atak0, txd.atak1, txd.atak2, txd.atak3, txd.eemph0, txd.eemph1, txd.eemph2, txd.eemph3, txd.etectrx0, txd.etectrx1, txd.etectrx2, txd.etectrx3, txe.lecidle0, txe.lecidle1, txe.lecidle2, txe.lecidle3, txm.argin0, txm.argin1, txm.argin2, txm.argin3, txs.wing0, txs.wing1, txs.wing2, txs.wing3);
endmodule
