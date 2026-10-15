// Convert a signed fixed point number to FP32.  FRAC_BITS is a parameter so
// the same block handles CORDIC Cartesian Q2.30 and angle Q4.28 values.
module fixed_to_fp32 #(parameter FRAC_BITS = 30) (
    input signed [31:0] fixed_value,
    output reg [31:0] value
);
    reg sign;
    reg [63:0] magnitude;
    reg [63:0] work;
    reg [24:0] mantissa;
    reg sticky;
    reg guard;
    integer i;
    integer msb;
    integer unbiased;
    integer exponent_field;
    integer shift;
    reg [7:0] packed_exp;
    always @(*) begin
        sign = fixed_value[31];
        if (sign) magnitude = {32'b0, (~fixed_value + 32'd1)};
        else magnitude = {32'b0, fixed_value};
        value = 0; mantissa = 0; sticky = 0; guard = 0; msb = -1; packed_exp = 0;
        work = 0; shift = 0; unbiased = 0; exponent_field = 0;
        for (i = 63; i >= 0; i = i - 1)
            if ((msb < 0) && magnitude[i]) msb = i;
        if (msb >= 0) begin
            unbiased = msb - FRAC_BITS;
            exponent_field = unbiased + 127;
            if (msb > 23) begin
                shift = msb - 23;
                work = magnitude >> shift;
                mantissa = {1'b0,work[23:0]};
                guard = magnitude[shift-1];
                sticky = 0;
                for (i = 0; i < 64; i = i + 1)
                    if (i < shift-1) sticky = sticky | magnitude[i];
                if (guard && (sticky || mantissa[0])) mantissa = mantissa + 1;
            end else begin
                mantissa = magnitude << (23-msb);
            end
            if (mantissa[24]) begin
                packed_exp = exponent_field + 1;
                value = {sign,packed_exp,mantissa[23:1]};
            end else if (exponent_field >= 255) begin
                value = {sign,8'hff,23'h0};
            end else if (exponent_field <= 0) begin
                value = {sign,8'h00,mantissa[22:0]};
            end else begin
                value = {sign,exponent_field[7:0],mantissa[22:0]};
            end
        end else value = {sign,31'h0};
    end
endmodule
