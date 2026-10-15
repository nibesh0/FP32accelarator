// Complex MAC, X*Y+Z. Four products run in parallel, followed by two
// component add/subtract trees and two accumulation adders.
module complex_mac (
    input [31:0] ar, input [31:0] ai, input [31:0] br, input [31:0] bi,
    input [31:0] cr, input [31:0] ci,
    output [31:0] rr, output [31:0] ri, output [4:0] status
);
    wire [31:0] ac,bd,ad,bc,rp,ip; wire [4:0] s0,s1,s2,s3,s4,s5,s6,s7;
    fp32_mul m0 (.a(ar),.b(br),.result(ac),.status(s0));
    fp32_mul m1 (.a(ai),.b(bi),.result(bd),.status(s1));
    fp32_mul m2 (.a(ar),.b(bi),.result(ad),.status(s2));
    fp32_mul m3 (.a(ai),.b(br),.result(bc),.status(s3));
    fp32_add p0 (.a(ac),.b(bd),.sub(1'b1),.result(rp),.status(s4));
    fp32_add p1 (.a(ad),.b(bc),.sub(1'b0),.result(ip),.status(s5));
    fp32_add a0 (.a(rp),.b(cr),.sub(1'b0),.result(rr),.status(s6));
    fp32_add a1 (.a(ip),.b(ci),.sub(1'b0),.result(ri),.status(s7));
    assign status = s0|s1|s2|s3|s4|s5|s6|s7;
endmodule
