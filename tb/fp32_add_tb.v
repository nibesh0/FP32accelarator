module fp32_add_tb;
    reg [31:0] a,b; reg sub; wire [31:0] result; wire [4:0] status;
    reg [31:0] vectors [0:1574]; integer i, failures;
    fp32_add dut(.a(a),.b(b),.sub(sub),.result(result),.status(status));
    task check;
      input [31:0] av; input [31:0] bv; input [31:0] expected; input sv;
      begin a=av; b=bv; sub=sv; #1;
        if ((result !== expected) && !(result[30:23]==8'hff && expected[30:23]==8'hff && result[22:0]!=0 && expected[22:0]!=0)) begin
          $display("ADD FAIL a=%h b=%h sub=%b got=%h exp=%h",a,b,sub,result,expected); failures=failures+1;
        end
      end
    endtask
    initial begin
      failures=0; $readmemh("vectors/fp_add_vectors.hex",vectors);
      check(32'h3f800000,32'h40000000,32'h40400000,0);
      check(32'h40b00000,32'h40100000,32'h40500000,1);
      check(32'h3f800000,32'h3f800000,32'h00000000,1);
      check(32'h7f800000,32'hff800000,32'h7fc00000,0);
      for (i=0;i<520;i=i+1) check(vectors[i*3],vectors[i*3+1],vectors[i*3+2],0);
      if (failures==0) $display("fp32_add_tb PASS"); else $display("fp32_add_tb FAILURES=%0d",failures);
      $finish;
    end
endmodule
