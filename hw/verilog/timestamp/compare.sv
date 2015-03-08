//

module compare (output logic le, gt,
                input logic [52:0] a, b);
   assign le = (a < b || a == b);
   assign gt = (a > b);
endmodule
