// Round-to-nearest-even and pack.  sig_in is a 27-bit significand with
// three low guard/round/sticky bits and bit 26 as the normal hidden bit.
module fp32_round (
    input             sign_in,
    input signed [12:0] exponent_in,
    input      [26:0]  significand_in,
    output reg [31:0]  result,
    output reg [4:0]   status
);
    reg signed [12:0] e;
    reg [26:0] s;
    reg [23:0] mantissa;
    reg [12:0] shift_count;
    reg increment;
    reg [24:0] rounded;
    integer normalize_step;

    function [26:0] shift_right_jam;
        input [26:0] value;
        input integer amount;
        integer k;
        reg sticky;
        begin
            if (amount <= 0)
                shift_right_jam = value;
            else if (amount >= 27)
                shift_right_jam = (value != 0) ? 27'h1 : 27'h0;
            else begin
                sticky = 1'b0;
                for (k = 0; k < 27; k = k + 1)
                    if (k < amount)
                        sticky = sticky | value[k];
                shift_right_jam = (value >> amount) | (sticky ? 27'h1 : 27'h0);
            end
        end
    endfunction

    always @(*) begin
        result = 32'h0;
        status = 5'h0;
        e = exponent_in;
        s = significand_in;
        mantissa = 0;
        shift_count = 0;
        increment = 0;
        rounded = 0;

        if (s == 0) begin
            result = {sign_in, 31'h0};
        end else begin
            // Normalize a cancellation or a product whose leading bit is low.
            for (normalize_step = 0; normalize_step < 26; normalize_step = normalize_step + 1)
                if (!s[26] && (e > 1)) begin
                    s = s << 1;
                    e = e - 1;
                end
            if (e <= 0) begin
                shift_count = 1 - e;
                s = shift_right_jam(s, shift_count);
                e = 1;
            end

            increment = s[2] && (s[1] || s[0] || s[3]);
            mantissa = s[26:3];
            rounded = {1'b0, mantissa} + (increment ? 25'h1 : 25'h0);
            if (rounded[24]) begin
                mantissa = rounded[24:1];
                e = e + 1;
            end else begin
                mantissa = rounded[23:0];
            end

            if (e >= 255) begin
                result = {sign_in, 8'hff, 23'h0};
                status[3] = 1'b1;
                status[2] = 1'b1;
            end else if ((e == 1) && !mantissa[23]) begin
                result = {sign_in, 8'h00, mantissa[22:0]};
                // IEEE tininess-after-rounding: exact subnormals do not
                // raise underflow; tiny AND inexact results do.
                status[4] = |s[2:0];
            end else begin
                result = {sign_in, e[7:0], mantissa[22:0]};
            end
        end
    end
endmodule
