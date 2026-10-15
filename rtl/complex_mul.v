// (a+jb)(c+jd) = (ac-bd) + j(ad+bc), using shared scalar datapaths.
module complex_mul (
    input [31:0] ar, input [31:0] ai, input [31:0] br, input [31:0] bi,
    output [31:0] rr, output [31:0] ri, output [4:0] status
);
    wire [31:0] ac,bd,ad,bc; wire [4:0] s_ac,s_bd,s_ad,s_bc,s_r,s_i;
    fp32_mul m_ac (.a(ar),.b(br),.result(ac),.status(s_ac));
    fp32_mul m_bd (.a(ai),.b(bi),.result(bd),.status(s_bd));
    fp32_mul m_ad (.a(ar),.b(bi),.result(ad),.status(s_ad));
    fp32_mul m_bc (.a(ai),.b(br),.result(bc),.status(s_bc));
    fp32_add a_r (.a(ac),.b(bd),.sub(1'b1),.result(rr),.status(s_r));
    fp32_add a_i (.a(ad),.b(bc),.sub(1'b0),.result(ri),.status(s_i));
    assign status = s_ac|s_bd|s_ad|s_bc|s_r|s_i;
endmodule
