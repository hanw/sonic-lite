import SchedulerTypes::*;

interface NextSlot;
	method ActionValue#(ServerIndex) nextSlotForInterval10(Bit#(64) curr_time);
endinterface

module mkNextSlot (NextSlot);
	Reg#(Bit#(64)) counter_0 <- mkReg(0);
	Reg#(Bit#(64)) counter_2 <- mkReg(1);
	Reg#(Bit#(64)) counter_4 <- mkReg(2);
	Reg#(Bit#(64)) counter_6 <- mkReg(3);

	method ActionValue#(ServerIndex) nextSlotForInterval10(Bit#(64) curr_time);
		ServerIndex next_slot = fromInteger(valueof(NUM_OF_SERVERS));

		if (fromInteger(valueof(NUM_OF_SERVERS)) == 2)
			next_slot = 0;
		else
		begin
			Bit#(3) curr_time_lsb = curr_time[2:0]; //look at last 3 bits
			case (curr_time_lsb)
				0 : next_slot = truncate(counter_0);
				2 : next_slot = truncate(counter_2);
				4 : next_slot = truncate(counter_4);
				6 : next_slot = truncate(counter_6);
			endcase
			if (next_slot != fromInteger(valueof(NUM_OF_SERVERS)))
			begin
				if (next_slot >= (fromInteger(valueof(NUM_OF_SERVERS))-1))
				begin
					case (curr_time_lsb)
						0 : begin
							next_slot = truncate(counter_0 -
							            fromInteger(valueof(NUM_OF_SERVERS)) - 1);
							counter_0 <= zeroExtend(next_slot) + 4;
							end
						2 : begin
							next_slot = truncate(counter_2 -
							            fromInteger(valueof(NUM_OF_SERVERS)) - 1);
							counter_2 <= zeroExtend(next_slot) + 4;
							end
						4 : begin
							next_slot = truncate(counter_4 -
							            fromInteger(valueof(NUM_OF_SERVERS)) - 1);
							counter_4 <= zeroExtend(next_slot) + 4;
							end
						6 : begin
							next_slot = truncate(counter_6 -
							            fromInteger(valueof(NUM_OF_SERVERS)) - 1);
							counter_6 <= zeroExtend(next_slot) + 4;
							end
					endcase
				end
				else
				begin
					case (curr_time_lsb)
						0 : counter_0 <= counter_0 + 4;
						2 : counter_2 <= counter_2 + 4;
						4 : counter_4 <= counter_4 + 4;
						6 : counter_6 <= counter_6 + 4;
					endcase

				end
			end
		end

		return next_slot;
	endmethod
endmodule
