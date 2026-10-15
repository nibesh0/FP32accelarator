// IEEE-754 single-precision multiplier.  The 24x24 multiply is explicit;
// only integer bit-vector operators are used in this synthesizable block.
module fp32_mul (
    input  [31:0] a, input [31:0] b,
    output [31:0] result, output [4:0] status
);
    reg sign_result;
    reg [7:0] exp_a, exp_b;
    reg [23:0] mant_a, mant_b;
    reg [47:0] product;
    reg signed [12:0] result_exp;
    reg [26:0] significand;
    reg [31:0] special_result;
    reg [4:0] special_status;
    reg special_case;
    wire [31:0] rounded_result;
    wire [4:0] rounded_status;
    integer normalize_step;

    fp32_round round_unit (
        .sign_in(sign_result), .exponent_in(result_exp),
        .significand_in(significand), .result(rounded_result),
        .status(rounded_status)
    );
    assign result = special_case ? special_result : rounded_result;
    assign status = special_case ? special_status : rounded_status;

    always @(*) begin
        sign_result = a[31] ^ b[31];
        exp_a = a[30:23]; exp_b = b[30:23];
        mant_a = (exp_a == 0) ? {1'b0,a[22:0]} : {1'b1,a[22:0]};
        mant_b = (exp_b == 0) ? {1'b0,b[22:0]} : {1'b1,b[22:0]};
        product = 0; result_exp = 0; significand = 0;
        special_result = 0; special_status = 0;
        special_case = 0;
        if ((exp_a == 8'hff && a[22:0] != 0) ||
            (exp_b == 8'hff && b[22:0] != 0)) begin
            special_case = 1;
            special_result = 32'h7fc00000; special_status[1] = 1;
        end else if (((exp_a == 8'hff) && (b[30:0] == 0)) ||
                     ((exp_b == 8'hff) && (a[30:0] == 0))) begin
            special_case = 1;
            special_result = 32'h7fc00000; special_status[0] = 1; special_status[1] = 1;
        end else if ((exp_a == 8'hff) || (exp_b == 8'hff)) begin
            special_case = 1;
            special_result = {sign_result,8'hff,23'h0}; special_status[2] = 1;
        end else if ((a[30:0] == 0) || (b[30:0] == 0)) begin
            special_case = 1;
            special_result = {sign_result,31'h0};
        end else begin
            // Extend operands before multiplication: Verilog otherwise uses
            // the operand width (24) for the expression result.
            product = {24'h0,mant_a} * {24'h0,mant_b};
            result_exp = ((exp_a == 0) ? 1 : exp_a) + ((exp_b == 0) ? 1 : exp_b) - 127;
            // A product with bit 47 set is already in [2,4); it is handled
            // by the right-shift/exp-increment path below. Only products
            // below 1.0 need left normalization here.
            for (normalize_step = 0; normalize_step < 46; normalize_step = normalize_step + 1)
                if ((product != 0) && !product[47] && !product[46] && (result_exp > 1)) begin
                    product = product << 1; result_exp = result_exp - 1;
                end
            if (product[47]) begin
                significand = product[47:21];
                if (|product[20:0]) significand[0] = 1'b1;
                result_exp = result_exp + 1;
            end else begin
                significand = product[46:20];
                if (|product[19:0]) significand[0] = 1'b1;
            end
        end
    end
endmodule
