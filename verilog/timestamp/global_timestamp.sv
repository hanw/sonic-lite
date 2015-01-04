//                              -*- Mode: Verilog -*-
// Filename        : global_timestamp.sv
// Description     : Compute max of all input counters.
// Author          : Han Wang
// Created On      : Wed Sep 10 15:24:35 2014
// Last Modified By: Han Wang
// Last Modified On: Wed Sep 10 15:24:35 2014
// Update Count    : 0
// Status          : Unknown, Use with caution!


module global_timestamp (/*AUTOARG*/
   // Outputs
   global_ts,
   // Inputs
   reset, clock, ts0, ts1, ts2, ts3
   ) ;
   input reset;
   input clock;
   input logic [52:0] ts0;
   input logic [52:0] ts1;
   input logic [52:0] ts2;
   input logic [52:0] ts3;

   output logic [52:0] global_ts;

   always_ff @ (posedge clock or posedge reset) begin
      if (reset) begin
         global_ts <= 0;
      end
      else begin
         global_ts <= comp_global(ts0, ts1, ts2, ts3);
      end
   end

   function [52:0] comp_global (input [52:0] ts0, ts1, ts2, ts3);
      logic [52:0]     tmp0;
      logic [52:0]     tmp1;
      if (ts0 > ts1) begin
         tmp0 = ts0;
      end
      else begin
         tmp0 = ts1;
      end

      if (ts2 > ts3) begin
         tmp1 = ts2;
      end
      else begin
         tmp1 = ts3;
      end

      if (tmp0 > tmp1) begin
         comp_global = tmp0;
      end
      else begin
         comp_global = tmp1;
      end

      return comp_global;

   endfunction // comp_global
   endmodule // global_cnt
