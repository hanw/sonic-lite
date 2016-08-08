import Clocks::*;
import DefaultValue::*;
import XilinxCells::*;
import GetPut::*;
import AxiBits::*;

(* always_ready, always_enabled *)
interface IregIcam;
    method Action      ie(Bit#(1) v);
    method Action      re(Bit#(1) v);
    method Action      se(Bit#(1) v);
    method Action      we(Bit#(1) v);
endinterface
(* always_ready, always_enabled *)
interface IregIcode;
    method Action      mode(Bit#(1) v);
endinterface
(* always_ready, always_enabled *)
interface IregIekey;
    method Action      msk(Bit#(288) v);
endinterface
(* always_ready, always_enabled *)
interface IregIent;
    method Action      add(Bit#(16) v);
endinterface
(* always_ready, always_enabled *)
interface IregIkey;
    method Action      dat(Bit#(288) v);
    method Action      pri(Bit#(7) v);
endinterface
(* always_ready, always_enabled *)
interface IregIreg;
    method Action      clus_sel(Bit#(3) v);
    method Action      dbg(Bit#(1) v);
    method Action      serc_mem_adr(Bit#(12) v);
    method Action      serc_mem_don(Bit#(1) v);
    method Action      serc_mem_sel(Bit#(5) v);
    method Action      serc_mem_wdt(Bit#(17) v);
    method Action      serc_mem_xrw(Bit#(1) v);
endinterface
(* always_ready, always_enabled *)
interface IregOekey;
    method Bit#(288)     msk();
endinterface
(* always_ready, always_enabled *)
interface IregOent;
    method Bit#(1)     err();
endinterface
(* always_ready, always_enabled *)
interface IregOkey;
    method Bit#(288)     dat();
    method Bit#(7)     pri();
endinterface
(* always_ready, always_enabled *)
interface IregOreg;
    method Bit#(17)     serc_mem_rdt();
endinterface
(* always_ready, always_enabled *)
interface IregOsrch;
    method Bit#(16)     ent_add();
endinterface
(* always_ready, always_enabled *)
interface IregOxmatch;
    method Bit#(1)     wait();
endinterface
(* always_ready, always_enabled *)
interface ICAM;
    interface IregIcam icam;
    interface IregIcode icode;
    interface IregIekey iekey;
    interface IregIent ient;
    interface IregIkey ikey;
    interface IregIreg ireg;
    method Bit#(wire)     oack();
    interface IregOekey oekey;
    interface IregOent oent;
    interface IregOkey okey;
    method Bit#(wire)     omhit();
    interface IregOreg oreg;
    method Bit#(wire)     oshit();
    interface IregOsrch osrch;
    interface IregOxmatch oxmatch;
endinterface
import "BVI" axonnerve =
module mkICAM#(Clock iclk, Reset iclk_reset, Reset ixrst)(ICAM#(P_CAM_Group, P_Entry_AdSize, P_FIFO_Depth, P_Key_Width, P_Pri_Size, P_Srch_RAM_AdSize, P_Srch_RAM_Num, P_Srch_RAM_Width));
    let P_CAM_Group = valueOf(P_CAM_Group);
    let P_Entry_AdSize = valueOf(P_Entry_AdSize);
    let P_FIFO_Depth = valueOf(P_FIFO_Depth);
    let P_Key_Width = valueOf(P_Key_Width);
    let P_Pri_Size = valueOf(P_Pri_Size);
    let P_Srch_RAM_AdSize = valueOf(P_Srch_RAM_AdSize);
    let P_Srch_RAM_Num = valueOf(P_Srch_RAM_Num);
    let P_Srch_RAM_Width = valueOf(P_Srch_RAM_Width);
    let wire = valueOf(wire);
    default_clock clk();
    default_reset rst();
    input_clock iclk(ICLK) = iclk;
    input_reset iclk_reset() = iclk_reset; /* from clock*/
    input_reset ixrst(IXRST) = ixrst;
    interface IregIcam     icam;
        method ie(ICAM_IE) enable((*inhigh*) EN_ICAM_IE);
        method re(ICAM_RE) enable((*inhigh*) EN_ICAM_RE);
        method se(ICAM_SE) enable((*inhigh*) EN_ICAM_SE);
        method we(ICAM_WE) enable((*inhigh*) EN_ICAM_WE);
    endinterface
    interface IregIcode     icode;
        method mode(ICODE_MODE) enable((*inhigh*) EN_ICODE_MODE);
    endinterface
    interface IregIekey     iekey;
        method msk(IEKEY_MSK) enable((*inhigh*) EN_IEKEY_MSK);
    endinterface
    interface IregIent     ient;
        method add(IENT_ADD) enable((*inhigh*) EN_IENT_ADD);
    endinterface
    interface IregIkey     ikey;
        method dat(IKEY_DAT) enable((*inhigh*) EN_IKEY_DAT);
        method pri(IKEY_PRI) enable((*inhigh*) EN_IKEY_PRI);
    endinterface
    interface IregIreg     ireg;
        method clus_sel(IREG_CLUS_SEL) enable((*inhigh*) EN_IREG_CLUS_SEL);
        method dbg(IREG_DBG) enable((*inhigh*) EN_IREG_DBG);
        method serc_mem_adr(IREG_SERC_MEM_ADR) enable((*inhigh*) EN_IREG_SERC_MEM_ADR);
        method serc_mem_don(IREG_SERC_MEM_DON) enable((*inhigh*) EN_IREG_SERC_MEM_DON);
        method serc_mem_sel(IREG_SERC_MEM_SEL) enable((*inhigh*) EN_IREG_SERC_MEM_SEL);
        method serc_mem_wdt(IREG_SERC_MEM_WDT) enable((*inhigh*) EN_IREG_SERC_MEM_WDT);
        method serc_mem_xrw(IREG_SERC_MEM_XRW) enable((*inhigh*) EN_IREG_SERC_MEM_XRW);
    endinterface
    method OACK oack();
    interface IregOekey     oekey;
        method OEKEY_MSK msk();
    endinterface
    interface IregOent     oent;
        method OENT_ERR err();
    endinterface
    interface IregOkey     okey;
        method OKEY_DAT dat();
        method OKEY_PRI pri();
    endinterface
    method OMHIT omhit();
    interface IregOreg     oreg;
        method OREG_SERC_MEM_RDT serc_mem_rdt();
    endinterface
    method OSHIT oshit();
    interface IregOsrch     osrch;
        method OSRCH_ENT_ADD ent_add();
    endinterface
    interface IregOxmatch     oxmatch;
        method OXMATCH_WAIT wait();
    endinterface
    schedule (icam.ie, icam.re, icam.se, icam.we, icode.mode, iekey.msk, ient.add, ikey.dat, ikey.pri, ireg.clus_sel, ireg.dbg, ireg.serc_mem_adr, ireg.serc_mem_don, ireg.serc_mem_sel, ireg.serc_mem_wdt, ireg.serc_mem_xrw, oack, oekey.msk, oent.err, okey.dat, okey.pri, omhit, oreg.serc_mem_rdt, oshit, osrch.ent_add, oxmatch.wait) CF (icam.ie, icam.re, icam.se, icam.we, icode.mode, iekey.msk, ient.add, ikey.dat, ikey.pri, ireg.clus_sel, ireg.dbg, ireg.serc_mem_adr, ireg.serc_mem_don, ireg.serc_mem_sel, ireg.serc_mem_wdt, ireg.serc_mem_xrw, oack, oekey.msk, oent.err, okey.dat, okey.pri, omhit, oreg.serc_mem_rdt, oshit, osrch.ent_add, oxmatch.wait);
endmodule
