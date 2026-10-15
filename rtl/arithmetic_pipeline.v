// Five registered stages, one valid transaction per clock, no backpressure.
// S1 request; S2 four parallel products; S3 two component add/subtracts;
// S4 MAC accumulation; S5 result/status. Bypass registers have matching
// delays. All opcodes share the same four multipliers and four adders.
module arithmetic_pipeline (
    input clk, input reset, input valid_in, input [3:0] opcode,
    input [31:0] a,b,c,d,e,f,
    output reg valid_out, output reg [3:0] opcode_out,
    output reg [31:0] result, result_imag,
    output reg [7:0] error
);
    reg v1,v2,v3,v4;
    reg [3:0] op1,op2,op3,op4;
    reg [31:0] a1,b1,c1,d1,e1,f1;
    reg [31:0] a2,b2,c2,d2,e2,f2,p0,p1,p2,p3;
    reg [31:0] r3,i3,e3,f3,r4,i4;
    reg [4:0] s2,s3,s4;
    wire [31:0] m0,m1,m2,m3;
    wire [4:0] ms0,ms1,ms2,ms3;
    wire complex_product = (op1==6 || op1==7);
    fp32_mul mul0(.a(a1),.b(complex_product ? c1 : b1),.result(m0),.status(ms0));
    fp32_mul mul1(.a(b1),.b(d1),.result(m1),.status(ms1));
    fp32_mul mul2(.a(a1),.b(d1),.result(m2),.status(ms2));
    fp32_mul mul3(.a(b1),.b(c1),.result(m3),.status(ms3));
    wire [31:0] add0_a = (op2==3 || op2==6 || op2==7) ? p0 : a2;
    wire [31:0] add0_b = (op2==6 || op2==7) ? p1 : (op2==3 || op2==4 || op2==5) ? c2 : b2;
    wire [31:0] add1_a = (op2==6 || op2==7) ? p2 : b2;
    wire [31:0] add1_b = (op2==6 || op2==7) ? p3 : d2;
    wire [31:0] ar,ai,acc_r,acc_i;
    wire [4:0] asr,asi,csr,csi;
    fp32_add add0(.a(add0_a),.b(add0_b),.sub(op2==1 || op2==5 || op2==6 || op2==7),.result(ar),.status(asr));
    fp32_add add1(.a(add1_a),.b(add1_b),.sub(op2==5),.result(ai),.status(asi));
    fp32_add accum_r(.a(r3),.b(e3),.sub(1'b0),.result(acc_r),.status(csr));
    fp32_add accum_i(.a(i3),.b(f3),.sub(1'b0),.result(acc_i),.status(csi));
    wire [4:0] conj_status;
    wire [31:0] conj_r,conj_i;
    complex_conj conj(.ar(a2),.ai(b2),.rr(conj_r),.ri(conj_i),.status(conj_status));

    always @(posedge clk) begin
        if(reset) begin
            v1<=0;v2<=0;v3<=0;v4<=0;valid_out<=0;
            op1<=0;op2<=0;op3<=0;op4<=0;opcode_out<=0;
            a1<=0;b1<=0;c1<=0;d1<=0;e1<=0;f1<=0;
            a2<=0;b2<=0;c2<=0;d2<=0;e2<=0;f2<=0;
            p0<=0;p1<=0;p2<=0;p3<=0;r3<=0;i3<=0;e3<=0;f3<=0;r4<=0;i4<=0;
            s2<=0;s3<=0;s4<=0;result<=0;result_imag<=0;error<=0;
        end else begin
            v1<=valid_in;v2<=v1;v3<=v2;v4<=v3;valid_out<=v4;
            if(valid_in) begin
                op1<=opcode;a1<=a;b1<=b;c1<=c;d1<=d;e1<=e;f1<=f;
            end
            if(v1) begin
                op2<=op1;a2<=a1;b2<=b1;c2<=c1;d2<=d1;e2<=e1;f2<=f1;
                p0<=m0;p1<=m1;p2<=m2;p3<=m3;
                s2 <= complex_product ? (ms0|ms1|ms2|ms3) :
                      ((op1==2 || op1==3) ? ms0 : 5'b0);
            end
            if(v2) begin
                op3<=op2;e3<=e2;f3<=f2;i3<=0;s3<=s2;
                case(op2)
                    0,1: begin r3<=ar;s3<=asr;end
                    2: r3<=p0;
                    3: begin r3<=ar;s3<=s2|asr;end
                    4,5,6,7: begin r3<=ar;i3<=ai;s3<=s2|asr|asi;end
                    8: begin r3<=conj_r;i3<=conj_i;s3<=conj_status;end
                    default: begin r3<=32'h7fc00000;i3<=0;end
                endcase
            end
            if(v3) begin
                op4<=op3;
                if(op3==7) begin r4<=acc_r;i4<=acc_i;s4<=s3|csr|csi;end
                else begin r4<=r3;i4<=i3;s4<=s3;end
            end
            if(v4) begin
                opcode_out<=op4;result<=r4;result_imag<=i4;
                error<={2'b0,(op4>8),s4};
            end
        end
    end
endmodule
