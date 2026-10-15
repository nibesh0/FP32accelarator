module complex_tb;
    reg [31:0] ar,ai,br,bi,cr,ci; wire [31:0] rr,ri; wire [4:0] status;
    wire [31:0] sr,si,pr,pi,qr,qi; wire [4:0] ss,ps,qs;
    integer failures;
    complex_add u0(.ar(ar),.ai(ai),.br(br),.bi(bi),.rr(sr),.ri(si),.status(ss));
    complex_mul u1(.ar(ar),.ai(ai),.br(br),.bi(bi),.rr(pr),.ri(pi),.status(ps));
    complex_conj u2(.ar(ar),.ai(ai),.rr(qr),.ri(qi),.status(qs));
    initial begin
      failures=0; ar=32'h3f800000; ai=32'h40000000; br=32'h40400000; bi=32'h40800000; #1;
      if (sr!==32'h40800000 || si!==32'h40c00000) failures=failures+1; // 4+j6
      if (pr!==32'hc0a00000 || pi!==32'h41200000) failures=failures+1; // -5+j10
      if (qr!==ar || qi!==32'hc0000000) failures=failures+1;
      if (failures==0) $display("complex_tb PASS"); else $display("complex_tb FAILURES=%0d",failures);
      $finish;
    end
endmodule
