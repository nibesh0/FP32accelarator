// IEEE-754 single precision field extraction.  This module contains no
// arithmetic and is useful at the front of every FP datapath.
module fp32_unpack (
    input  [31:0] value,
    output        sign,
    output [7:0]  exponent,
    output [22:0] fraction,
    output        is_zero,
    output        is_subnormal,
    output        is_normal,
    output        is_inf,
    output        is_nan
);
    assign sign = value[31];
    assign exponent = value[30:23];
    assign fraction = value[22:0];
    assign is_zero = (value[30:23] == 8'h00) && (value[22:0] == 23'h0);
    assign is_subnormal = (value[30:23] == 8'h00) && (value[22:0] != 23'h0);
    assign is_normal = (value[30:23] != 8'h00) && (value[30:23] != 8'hff);
    assign is_inf = (value[30:23] == 8'hff) && (value[22:0] == 23'h0);
    assign is_nan = (value[30:23] == 8'hff) && (value[22:0] != 23'h0);
endmodule
