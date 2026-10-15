module fp32_classify (
    input [31:0] value,
    output is_zero,
    output is_subnormal,
    output is_normal,
    output is_inf,
    output is_nan
);
    assign is_zero = (value[30:0] == 31'h0);
    assign is_subnormal = (value[30:23] == 8'h0) && (value[22:0] != 0);
    assign is_normal = (value[30:23] != 0) && (value[30:23] != 8'hff);
    assign is_inf = (value[30:23] == 8'hff) && (value[22:0] == 0);
    assign is_nan = (value[30:23] == 8'hff) && (value[22:0] != 0);
endmodule
