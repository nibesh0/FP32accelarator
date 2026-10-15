// Combinational IEEE-754 add/subtract datapath.  Subtraction is selected by
// sub=1 and is implemented by sign inversion before the same magnitude path.
module fp32_add (
    input  [31:0] a,
    input  [31:0] b,
    input         sub,
    output [31:0] result,
    output [4:0]  status
);
    reg sign_a, sign_b;
    reg [7:0] exp_a, exp_b;
    reg [23:0] sig_a, sig_b;
    reg [26:0] wide_a, wide_b, aligned_a, aligned_b, magnitude;
    reg [27:0] sum;
    reg [7:0] ea, eb;
    reg sign_result;
    reg signed [12:0] result_exp;
    reg [31:0] special_result;
    reg [4:0] special_status;
    reg special_case;
    wire [31:0] rounded_result;
    wire [4:0] rounded_status;
    integer difference;

    function [26:0] shift_right_jam;
        input [26:0] value;
        input integer amount;
        integer j;
        reg lost;
        begin
            if (amount <= 0) shift_right_jam = value;
            else if (amount >= 27) shift_right_jam = (value != 0) ? 27'h1 : 27'h0;
            else begin
                lost = 0;
                for (j = 0; j < 27; j = j + 1)
                    if (j < amount) lost = lost | value[j];
                shift_right_jam = (value >> amount) | (lost ? 27'h1 : 27'h0);
            end
        end
    endfunction

    fp32_round round_unit (
        .sign_in(sign_result), .exponent_in(result_exp),
        .significand_in(magnitude), .result(rounded_result),
        .status(rounded_status)
    );
    assign result = special_case ? special_result : rounded_result;
    assign status = special_case ? special_status : rounded_status;

    always @(*) begin
        sign_a = a[31];
        sign_b = b[31] ^ sub;
        exp_a = a[30:23];
        exp_b = b[30:23];
        sig_a = (exp_a == 0) ? {1'b0, a[22:0]} : {1'b1, a[22:0]};
        sig_b = (exp_b == 0) ? {1'b0, b[22:0]} : {1'b1, b[22:0]};
        ea = (exp_a == 0) ? 1 : exp_a;
        eb = (exp_b == 0) ? 1 : exp_b;
        wide_a = {sig_a, 3'b000};
        wide_b = {sig_b, 3'b000};
        aligned_a = 0;
        aligned_b = 0;
        magnitude = 0;
        sum = 0;
        sign_result = 0;
        result_exp = 0;
        special_result = 0;
        special_status = 0;
        special_case = 0;
        difference = 0;

        if ((exp_a == 8'hff && a[22:0] != 0) ||
            (exp_b == 8'hff && b[22:0] != 0)) begin
            special_case = 1;
            special_result = 32'h7fc00000;
            special_status[1] = 1;
        end else if ((exp_a == 8'hff) || (exp_b == 8'hff)) begin
            special_case = 1;
            if ((exp_a == 8'hff && exp_b == 8'hff) && (sign_a != sign_b)) begin
                special_result = 32'h7fc00000;
                special_status[0] = 1;
                special_status[1] = 1;
            end else begin
                special_result = (exp_a == 8'hff) ? {sign_a,8'hff,23'h0} : {sign_b,8'hff,23'h0};
                special_status[2] = 1;
            end
        end else if ((a[30:0] == 0) && (b[30:0] == 0)) begin
            special_case = 1;
            special_result = {(sign_a & sign_b),31'h0};
        end else begin
            if (ea >= eb) begin
                result_exp = ea;
                difference = ea - eb;
                aligned_a = wide_a;
                aligned_b = shift_right_jam(wide_b, difference);
            end else begin
                result_exp = eb;
                difference = eb - ea;
                aligned_a = shift_right_jam(wide_a, difference);
                aligned_b = wide_b;
            end
            if (sign_a == sign_b) begin
                sum = {1'b0, aligned_a} + {1'b0, aligned_b};
                sign_result = sign_a;
                if (sum[27]) begin
                    magnitude = sum[27:1] | (sum[0] ? 27'h1 : 27'h0);
                    result_exp = result_exp + 1;
                end else magnitude = sum[26:0];
            end else begin
                if (aligned_a > aligned_b) begin
                    magnitude = aligned_a - aligned_b;
                    sign_result = sign_a;
                end else if (aligned_b > aligned_a) begin
                    magnitude = aligned_b - aligned_a;
                    sign_result = sign_b;
                end else begin
                    magnitude = 0;
                    sign_result = 0;
                end
            end
        end
    end
endmodule
