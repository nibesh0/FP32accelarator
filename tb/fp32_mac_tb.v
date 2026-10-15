module fp32_mac_tb;
    reg [31:0] a,b,c; wire [31:0] result; wire [4:0] status;
    reg [31:0] vectors [0:2099]; integer i, failures;
    fp32_mac dut(.a(a),.b(b),.c(c),.result(result),.status(status));
    task check;
      input [31:0] av; input [31:0] bv; input [31:0] cv; input [31:0] expected;
      begin a=av; b=bv; c=cv; #1;
        if ((result !== expected) && !(result[30:23]==8'hff && expected[30:23]==8'hff && result[22:0]!=0 && expected[22:0]!=0)) begin
          $display("MAC FAIL a=%h b=%h c=%h got=%h exp=%h",a,b,c,result,expected); failures=failures+1;
        end
      end
    endtask
    initial begin
      failures=0; $readmemh("vectors/fp_mac_vectors.hex",vectors);
      check(32'h40000000,32'h40400000,32'h3f800000,32'h40e00000);
      check(32'h00000000,32'h7f800000,32'h3f800000,32'h7fc00000);
      for (i=0;i<515;i=i+1) check(vectors[i*4],vectors[i*4+1],vectors[i*4+2],vectors[i*4+3]);
      if (failures==0) $display("fp32_mac_tb PASS"); else $display("fp32_mac_tb FAILURES=%0d",failures);
      $finish;
    end
endmodule
