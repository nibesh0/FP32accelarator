module complex_add (
    input [31:0] ar, input [31:0] ai, input [31:0] br, input [31:0] bi,
    output [31:0] rr, output [31:0] ri, output [4:0] status
);
    wire [4:0] sr, si;
    fp32_add add_r (.a(ar),.b(br),.sub(1'b0),.result(rr),.status(sr));
    fp32_add add_i (.a(ai),.b(bi),.sub(1'b0),.result(ri),.status(si));
    assign status = sr | si;
endmodule
