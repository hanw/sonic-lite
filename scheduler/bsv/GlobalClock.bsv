interface GlobalClock;
    method Bit#(64) currTime();
endinterface

module mkGlobalClock (GlobalClock);
    Reg#(Bit#(64)) clk <- mkReg(0);

    rule counter;
        clk <= clk + 1;
    endrule

    method Bit#(64) currTime();
        return clk;
    endmethod
endmodule
