interface Random;
	method Action init(Bit#(48) x);
	method ActionValue#(Bit#(32)) next();
endinterface

module mkRandom (Random);
	Reg#(Bit#(48)) seed <- mkReg(0);

	method Action init(Bit#(48) x);
		seed <= x;
	endmethod

	method ActionValue#(Bit#(32)) next();
		/* X_n+1 = (25214903917 * X + 11) mod 2^48. Java uses this. */
		Bit#(48) n_val = (25214903917 + seed + 11);
		seed <= n_val;
		return (n_val[31:0]);
	endmethod
endmodule
