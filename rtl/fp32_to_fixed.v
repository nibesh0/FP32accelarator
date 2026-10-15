// Convert FP32 to a signed fixed point integer.  The default format is
// Q4.28, used for angles by CORDIC.  Conversion is truncating; CORDIC's
// iterative error is much larger than the final discarded bit.
module fp32_to_fixed #(parameter FRAC_BITS = 28) (
    input [31:0] value,
    output reg signed [31:0] fixed_value
);
    reg [23:0] mantissa;
    reg [63:0] magnitude;
    integer exponent;
    integer shift;
    always @(*) begin
        mantissa = (value[30:23] == 0) ? {1'b0,value[22:0]} : {1'b1,value[22:0]};
        magnitude = 0;
        if ((value[30:23] != 8'hff) && (value[30:0] != 0)) begin
            exponent = (value[30:23] == 0) ? -126 : value[30:23] - 127;
            shift = exponent - 23 + FRAC_BITS;
            magnitude = mantissa;
            if (shift >= 0) magnitude = magnitude << shift;
            else magnitude = magnitude >> (-shift);
        end
        if (value[30:0] == 0) fixed_value = 0;
        else if (value[31]) fixed_value = -$signed(magnitude[31:0]);
        else fixed_value = magnitude[31:0];
    end
endmodule
