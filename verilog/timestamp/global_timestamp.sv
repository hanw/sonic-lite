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
   timestamp_maximum,
   // Inputs
   reset, clock, timestamp_p0, timestamp_p1, timestamp_p2, timestamp_p3
   ) ;
   input reset;
   input clock;
   input logic [52:0] timestamp_p0;
   input logic [52:0] timestamp_p1;
   input logic [52:0] timestamp_p2;
   input logic [52:0] timestamp_p3;

   output logic [52:0] timestamp_maximum;

   always_ff @ (posedge clock or posedge reset) begin
      if (reset) begin
         timestamp_maximum <= 0;
      end
      else begin
         timestamp_maximum <= comp_global(timestamp_p0, timestamp_p1, timestamp_p2, timestamp_p3);
      end
   end

   function [52:0] comp_global (input [52:0] timestamp_p0, timestamp_p1, timestamp_p2, timestamp_p3);
      logic [52:0]     tmp0;
      logic [52:0]     tmp1;
      if (timestamp_p0 > timestamp_p1) begin
         tmp0 = timestamp_p0;
      end
      else begin
         tmp0 = timestamp_p1;
      end

      if (timestamp_p2 > timestamp_p3) begin
         tmp1 = timestamp_p2;
      end
      else begin
         tmp1 = timestamp_p3;
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
