`define DEBOUNCE_VALUE 16'hf00f
 module edge_detector (

iCLK,
iRST_n,
iTrigger_in,
oFalling_edge,
oRising_edge,
oDebounce_out,
rst_cnt
);

input iCLK;
input iRST_n;

input iTrigger_in;
output oFalling_edge;
output oRising_edge;
output reg oDebounce_out;

reg  [1:0] in_delay_reg;


always@(posedge iCLK or negedge iRST_n)
	begin
		if (!iRST_n)
			begin
				in_delay_reg <= 0;
			end
		else
			begin
				in_delay_reg <= {in_delay_reg[0],iTrigger_in};	
			end	
	end
	
			 
assign oFalling_edge = (in_delay_reg == 2'b01) ? 1'b1 : 1'b0;	
assign oRISING_edge = (in_delay_reg == 2'b10) ? 1'b1 : 1'b0;	


output reg [15:0] rst_cnt;

always@(posedge iCLK or negedge iRST_n)
	begin
		if (!iRST_n)
			begin
				rst_cnt <= 0;
			end
		else if (rst_cnt == `DEBOUNCE_VALUE)
			rst_cnt <= 0;
		else if (cnt_enable)
			begin 
				rst_cnt <= rst_cnt + 1;
			end
	end		
			
reg cnt_enable;
			
always@(posedge iCLK or negedge iRST_n)
	begin
		if (!iRST_n)
			begin
				cnt_enable <= 1'b0;
			end
		else if (oFalling_edge)
			begin
				cnt_enable <= 1'b1;
			end
		else if (rst_cnt == `DEBOUNCE_VALUE)
			begin
				cnt_enable <= 1'b0;
			end 
	end




always@(posedge iCLK or negedge iRST_n)
	begin
		if (!iRST_n)
			begin
				oDebounce_out <= 1'b0;
			end
		else if (oFalling_edge && ~cnt_enable)
			begin
				oDebounce_out <= 1'b1;
			end
		else 
			oDebounce_out <= 1'b0;
		
	end		
			
endmodule 
