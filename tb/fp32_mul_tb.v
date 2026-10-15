module fp32_mul_tb;
    reg [31:0] a,b; wire [31:0] result; wire [4:0] status;
    reg [31:0] vectors [0:1574]; integer i, failures;
    fp32_mul dut(.a(a),.b(b),.result(result),.status(status));
    task check;
      input [31:0] av; input [31:0] bv; input [31:0] expected;
      begin a=av; b=bv; #1;
        if ((result !== expected) && !(result[30:23]==8'hff && expected[30:23]==8'hff && result[22:0]!=0 && expected[22:0]!=0)) begin
          $display("MUL FAIL a=%h b=%h got=%h exp=%h",a,b,result,expected); failures=failures+1;
        end
      end
    endtask
    initial begin
      failures=0; $readmemh("vectors/fp_mul_vectors.hex",vectors);
      check(32'h3fc00000,32'h40000000,32'h40400000);
      check(32'h7f800000,32'h00000000,32'h7fc00000);
      check(32'h7f800000,32'h3f800000,32'h7f800000);
      for (i=0;i<520;i=i+1) check(vectors[i*3],vectors[i*3+1],vectors[i*3+2]);
      if (failures==0) $display("fp32_mul_tb PASS"); else $display("fp32_mul_tb FAILURES=%0d",failures);
      $finish;
    end
endmodule
