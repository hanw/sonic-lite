//                              -*- Mode: Verilog -*-
// Filename        : clocksync_sm.sv
// Description     : clock synchronization state machine
// Author          : Han Wang
// Created On      : Tue Apr 29 17:03:50 2014
// Last Modified By: Han Wang
// Last Modified On: Tue Apr 29 17:03:50 2014
// Update Count    : 0
// Status          : Unknown, Use with caution!

module clocksync_sm (/*AUTOARG*/
   // Outputs
   c_local_o, clksync_dataout, export_data, export_valid,
   export_delay,
   // Inputs
   reset, clock, link_ok, clear, disable_filter, thres, mode,
   encoded_datain, decoded_dataout, init_timeout, sync_timeout,
   c_global
   ) ;

   input reset;
   input clock;

   input link_ok;
   input logic clear;
   input logic disable_filter;
   input logic [31:0] thres;

   // 0 for NIC mode, 1 for switch mode
   input logic mode /*synthesis keep = 1*/;

   input logic [65:0] encoded_datain;
   input logic [65:0] decoded_dataout;
   input logic [31:0] init_timeout;
   input logic [31:0] sync_timeout;
   input logic [52:0] c_global;
   output logic [52:0] c_local_o;

   output logic [65:0] clksync_dataout;

   output logic [511:0] export_data;
   output logic         export_valid;
   output logic [15:0]  export_delay;

   parameter INIT_TYPE=2'b01, ACK_TYPE=2'b10, BEACON_TYPE=2'b11;
   parameter C_GLOBAL_DELAY=3;
   parameter C_NEXT_CYCLE=1;

   enum                 logic [2:0] {INIT = 3'b001,
                                     SENT = 3'b010,
                                     SYNC = 3'b100} State /* synthesis keep = 1 */, Next /* synthesis keep = 1 */, Prev /* synthesis keep = 1 */;
   logic                timeout_sync /* synthesis keep = 1 */;
   logic                timeout_init /* synthesis keep = 1 */;
   logic [31:0]         timeout_count_sync;
   logic [31:0]         timeout_count_sync_next;
   logic [31:0]         timeout_count_init;
   logic [31:0]         timeout_count_init_next;
   logic [52:0]         delay /* synthesis keep = 1 */;
   logic [52:0]         temp /* synthesis keep = 1 */;
   logic [1:0]          stp_ctrl, stp_ctrl_next /* synthesis keep = 1 */;
   logic                to_sync /* synthesis keep = 1 */;
   logic                init_rcvd /* synthesis keep = 1 */;
   logic                ack_rcvd /* synthesis keep = 1 */;
   logic                beacon_rcvd /* synthesis keep = 1 */;
   logic [52:0]         c_remote /* synthesis keep = 1 */;
   logic [1:0]          mux_sel, mux_sel_next;
   logic [65:0]         mux_datain;
   logic                is_idle, is_idle_next;
   logic [52:0]         c_local /* synthesis keep = 1 */;
   logic [52:0]         c_local_prev /* synthesis keep = 1 */;

   logic [52:0]         ref_cnt;

   logic [31:0]         error_cnt /* synthesis keep = 1 */;

   logic                parity /* synthesis keep = 1 */;

   assign to_sync = timeout_sync /* synthesis keep = 1 */;
   assign export_delay = delay[15:0];

   /*
    * Generate STP message based on current state
    */
   // incur one clock cycle of delay
   always_ff @ (posedge clock) begin
      is_idle <= is_idle_next;
      mux_sel <= mux_sel_next;
      mux_datain <= encoded_datain;
   end

   always_comb begin
      parity = ^c_local[52:0];
   end

   xgmii_mux mux (
                  .data0x(mux_datain),
                  .data1x({c_local, parity, INIT_TYPE, mux_datain[9:0]}),
                  .data2x({c_local, parity, ACK_TYPE, mux_datain[9:0]}),
                  .data3x({c_local, parity, BEACON_TYPE, mux_datain[9:0]}),
                  .sel(mux_sel),
                  .clock(clock),
                  .result(clksync_dataout)
                  );

   // wait until next available idle frame to send STP message
   always_comb begin
      is_idle_next = 0;
      mux_sel_next = 0;
      if (encoded_datain[9:2] == 8'h1e) begin
         if (stp_ctrl_next != 0) begin
            mux_sel_next = stp_ctrl_next;
         end
         is_idle_next = 1'b1;
      end
   end

   logic remote_parity /* synthesis keep = 1 */;

   always_comb begin
      remote_parity = ^decoded_dataout[65:13];
   end

   /*
    * Receive STP message from incoming IDLE frames.
    */
   always_ff @ (posedge clock) begin
      if (decoded_dataout[9:2] == 8'h1e && decoded_dataout[11:10] == INIT_TYPE) begin
         init_rcvd <= 1'b1;
         ack_rcvd <= 1'b0;
         beacon_rcvd <= 1'b0;
         if (remote_parity == decoded_dataout[12]) begin
            c_remote <= decoded_dataout[65:13];
         end
      end
      else if (decoded_dataout[9:2] == 8'h1e && decoded_dataout[11:10] == ACK_TYPE) begin
         init_rcvd <= 1'b0;
         ack_rcvd <= 1'b1;
         beacon_rcvd <= 1'b0;
         if (remote_parity == decoded_dataout[12]) begin
            c_remote <= decoded_dataout[65:13];
         end
      end
      else if (decoded_dataout[9:2] == 8'h1e && decoded_dataout[11:10] == BEACON_TYPE) begin
         init_rcvd <= 1'b0;
         ack_rcvd <= 1'b0;
         beacon_rcvd <= 1'b1;
         if (remote_parity == decoded_dataout[12]) begin
            c_remote <= decoded_dataout[65:13];
         end
      end
      else begin
         init_rcvd <= 1'b0;
         ack_rcvd <= 1'b0;
         beacon_rcvd <= 1'b0;
         c_remote <= 53'h0;
      end
   end

   /*
    * Maintain STP state machine
    */
   always_ff @ (posedge clock or posedge reset) begin
      if (reset) State <= INIT;
      else State <= Next;
   end

   // state transition
   always_comb begin: set_next_state
      Next = State;  // the default for each branch below
      Prev = State;
      unique case (State)
        INIT: begin
           if (link_ok && timeout_init && is_idle)
             Next = SENT;
           else if (init_rcvd)
             Next = INIT;
           else
             Next = INIT;
        end
        SENT: begin
           if (!link_ok)
             Next = INIT;
           else if (init_rcvd)
             Next = SENT;
           else if (ack_rcvd)
             Next = SYNC;
           else if (timeout_init)
             Next = INIT;
           else
             Next = SENT;
        end
        SYNC: begin
           if (!link_ok)
             Next = INIT;
           else if (init_rcvd)
             Next = SYNC;
           else
             Next = SYNC;
        end
        default: begin
           Next = INIT;
        end
      endcase
   end

   logic local_gt_remote /* synthesis keep = 1 */, local_le_remote /* synthesis keep = 1 */;
   logic global_gt_local /* synthesis keep = 1 */, global_le_local /* synthesis keep = 1 */;
   logic global_gt_remote /* synthesis keep = 1 */, global_le_remote /* synthesis keep = 1 */;

   compare lrc (
      .le(local_le_remote),
      .gt(local_gt_remote),
      .a(c_local + C_NEXT_CYCLE),
      .b(c_remote + delay)
   );

   compare grc (
      .le(global_le_remote),
      .gt(global_gt_remote),
      .a(c_global + C_GLOBAL_DELAY),
      .b(c_remote + delay)
   );

   compare glc (
      .le(global_le_local),
      .gt(global_gt_local),
      .a(c_global + C_GLOBAL_DELAY),
      .b(c_local + C_NEXT_CYCLE)
   );

   logic remote_good /* synthesis keep = 1*/;
   logic remote_valid /* synthesis keep = 1*/;

   assign remote_good = remote_valid | disable_filter;

   always_comb begin
      remote_valid = (c_remote < (c_local + C_NEXT_CYCLE + {5'h0, thres, 16'h0}));
   end

   logic [52:0] c_local_next;
   logic [7:0] c_local_sel /* synthesis keep = 1 */;

   assign c_local_sel = {remote_good, mode, global_gt_remote, global_le_remote,
                         local_gt_remote, local_le_remote,
                         global_gt_local, global_le_local};

   always_comb begin
      casez (c_local_sel)
         8'b10??10??: c_local_next = c_local + C_NEXT_CYCLE;
         8'b10??01??: c_local_next = c_remote + delay;
         8'b1110??10: c_local_next = c_global + C_GLOBAL_DELAY;
         8'b11??1001: c_local_next = c_local + C_NEXT_CYCLE;
         8'b110101??: c_local_next = c_remote + delay;
         default:   c_local_next = c_local + C_NEXT_CYCLE;
      endcase
   end

   /*
    * Compute local counter and measured delay
    */
   always_ff @ (posedge clock or posedge reset or posedge clear) begin
      if (reset == 1'b1 || clear == 1'b1) begin
         c_local <= 53'h0;
         c_local_prev <= 53'h0;
         c_local_o <= 53'h0;
      end
      else begin
         // remember c_local from last clock cycle.
         c_local_o <= c_local;
         c_local_prev <= c_local;

         // update c_local, based on what the state machine computed.
         // global computation has two cycles delay
         unique case (State)
           INIT: begin
              if (init_rcvd) begin
                 c_local <= c_local_next;
              end
              else begin
                 c_local <= c_local + C_NEXT_CYCLE;
              end
           end
           SENT: begin
              if (init_rcvd || ack_rcvd) begin
                 c_local <= c_local_next;
              end
              else begin
                 c_local <= c_local + C_NEXT_CYCLE;
              end
           end
           SYNC: begin
              if (beacon_rcvd) begin
                 c_local <= c_local_next;
              end
              else begin
                 c_local <= c_local + C_NEXT_CYCLE;
              end
           end
           default: begin
              c_local <= 0;
           end
         endcase
      end
   end

   /*
    * Measure Delay
    */
   always_ff @ (posedge clock or posedge reset) begin
      if (reset == 1'b1) begin
         temp <= 53'h0;
         delay <= 53'h0;
      end
      else begin
         case (State)
           INIT: begin
              if (timeout_init) begin
                 temp <= c_local;
              end
           end
           SENT: begin
              if (ack_rcvd) begin
                 delay <= comp_delay(c_local, temp);
              end
           end
         endcase
      end // else: !if(reset == 1'b1)
   end

   always_ff @ (posedge clock or posedge reset or posedge clear) begin
      if (reset || clear) begin
         error_cnt <= 0;
      end
      else if (c_local > c_local_prev + 1) begin
         error_cnt <= error_cnt + 1;
      end
   end

   logic export_ctrl;

   always_comb begin : set_export_ctrl
      if (State == SYNC && beacon_rcvd == 1'b1) begin
         export_ctrl = 1;
      end
      else if (init_rcvd == 1'b1) begin
         export_ctrl = 1;
      end
      else if (ack_rcvd == 1'b1) begin
         export_ctrl = 1;
      end
      else if (mux_sel_next != 0) begin
         export_ctrl = 1;
      end
      else begin
         export_ctrl = 0;
      end
   end

   /*
    * export data
    */
   always_comb begin
      if (export_ctrl) begin
         export_data[511:256] = {64'h0, 64'h0, 64'h0, 32'h0, error_cnt};
         export_data[255:0] = {export_delay[7:0], 3'h0, ref_cnt,
                                Prev,  8'h0, c_local_prev,
                                State, 8'h0, c_local,
                                beacon_rcvd, init_rcvd, ack_rcvd, mux_sel_next, 6'h0, c_remote};
         export_valid = 1'b1;
      end
      else begin
         export_data = 512'h0;
         export_valid = 1'b0;
      end
   end

   /*
    * maintain local ref_cnt
    */
   always_ff @ (posedge clock or posedge reset or posedge clear) begin
      if (reset || clear) begin
         ref_cnt <= 0;
      end
      else begin
         ref_cnt <= ref_cnt + 1;
      end
   end

   /*
    * Timeout, generate trigger for STP message transmission
    * STP_CTRL is encoded as follows:
    * 2'h00: default Ethernet mode
    * 2'h01: send INIT frame
    * 2'h10: send ACK frame
    * 2'h11: send BEACON frame
    */
   always_ff @ (posedge clock or posedge reset or negedge link_ok) begin
      if (!link_ok || reset) begin
         timeout_count_init <= 32'b0;
         timeout_count_sync <= 32'b0;
         stp_ctrl <= 2'b0;
      end
      else begin
         timeout_count_init <= timeout_count_init_next;
         timeout_count_sync <= timeout_count_sync_next;
         stp_ctrl <= stp_ctrl_next;
      end
   end

   // manage timeout signal
   always_comb begin
      timeout_sync = 1'b0;
      timeout_init = 1'b0;
      stp_ctrl_next = 2'b00;

      if (!link_ok || reset) begin
         timeout_count_init_next = 32'b0;
         timeout_count_sync_next = 32'b0;
      end
      else begin
         timeout_count_init_next = timeout_count_init;
         timeout_count_sync_next = timeout_count_sync;
      end

      unique case(State)
        INIT: begin
           if (timeout_count_init > init_timeout) begin
              if (is_idle) begin
                 timeout_count_init_next = 32'b0;
              end
              timeout_init = 1'b1;
              stp_ctrl_next = 2'b01; //send INIT
           end
           else if (init_rcvd) begin
              stp_ctrl_next = 2'b10; // send ACK
           end
           else begin
              timeout_count_init_next = timeout_count_init_next + 1;
           end
        end
        SENT: begin
           if (timeout_count_init > init_timeout) begin
              if (is_idle) begin
                 timeout_count_init_next = 32'b0;
              end
              timeout_init = 1'b1;
              stp_ctrl_next = 2'b01; // send INIT
           end
           else if (init_rcvd) begin
              stp_ctrl_next = 2'b10; // send ACK
           end
           else begin
              timeout_count_init_next = timeout_count_init_next + 1;
           end
        end
        SYNC: begin
           // generate two clock cycles of ctrl signal
           if (timeout_count_sync >= sync_timeout) begin
              if (is_idle) begin
                 timeout_count_sync_next = 32'b0;
              end
              timeout_sync = 1'b1;
              stp_ctrl_next = 2'b11; // send BEACON
           end
           else if (init_rcvd) begin
              stp_ctrl_next = 2'b10; // send ACK
           end
           else begin
              timeout_count_sync_next = timeout_count_sync_next + 1;
           end
        end
        default: begin
        end
      endcase
   end

   /*
    * Misc function to compute c_local and delay
    */
   // compute delay = new local counter - temp
   function [52:0] comp_delay (input[52:0] c_local, input[52:0] temp);
      // subtract 2 from RTT to compensate for the delay through MUX.
      comp_delay = (c_local - temp - 2) >> 1;
      //$display("The value of new local delay is %d", new_delay);
      return comp_delay;
   endfunction

   function [31:0] comp_error_cntr (input [52:0] c_local, input [52:0] c_local_prev);
      if (c_local > c_local_prev + 1) begin
         comp_error_cntr = 32'h1;
      end
      else begin
         comp_error_cntr = 32'h0;
      end;
      return comp_error_cntr;
   endfunction

endmodule // clocksync_sm
