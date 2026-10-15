// Non-fused MAC: explicit multiplier followed by an add stage.
module fp32_mac (
    input [31:0] a, input [31:0] b, input [31:0] c,
    output [31:0] result, output [4:0] status
);
    wire [31:0] product; wire [4:0] mul_status, add_status;
    fp32_mul mul (.a(a), .b(b), .result(product), .status(mul_status));
    fp32_add add (.a(product), .b(c), .sub(1'b0), .result(result), .status(add_status));
    assign status = mul_status | add_status;
endmodule
