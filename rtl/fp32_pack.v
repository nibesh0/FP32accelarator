// Small explicit pack stage used by integration code and documentation.
// Rounding/normalization is performed by fp32_round before this interface.
module fp32_pack (
    input sign,
    input [7:0] exponent,
    input [22:0] fraction,
    output [31:0] value
);
    assign value = {sign,exponent,fraction};
endmodule
