module cordic_tb;
    reg clk,reset,start; reg [1:0] mode; reg [31:0] angle,x,y;
    wire [31:0] result,result_imag; wire busy,done,valid; wire [4:0] status;
    integer failures,cycles;
    cordic dut(.clk(clk),.reset(reset),.start(start),.mode(mode),.angle(angle),.x_input(x),.y_input(y),
               .result(result),.result_imag(result_imag),.busy(busy),.done(done),.valid(valid),.status(status));
    always #5 clk=~clk;
    task run;
      input [1:0] m; input [31:0] av; input [31:0] expected;
      begin mode=m; angle=av; x=0; y=0; @(posedge clk); start=1; @(posedge clk); start=0;
        cycles=0; while (!done && cycles<40) begin @(posedge clk); cycles=cycles+1; end
        if (!done) begin $display("CORDIC timeout"); failures=failures+1; end
        else if ((result[30:23] == 8'hff) || (result[31:0] == 0 && expected != 0)) begin
          $display("CORDIC suspicious result=%h expected near=%h",result,expected); failures=failures+1;
        end
      end
    endtask
    task run_atan;
      input [31:0] xv; input [31:0] yv; input [31:0] expected;
      begin mode=2; angle=0; x=xv; y=yv; @(posedge clk); start=1; @(posedge clk); start=0;
        cycles=0; while (!done && cycles<40) begin @(posedge clk); cycles=cycles+1; end
        if (!done || result !== expected) begin
          $display("ATAN2 FAIL x=%h y=%h got=%h expected=%h",xv,yv,result,expected); failures=failures+1;
        end
      end
    endtask
    initial begin
      clk=0; reset=1; start=0; mode=0; angle=0; x=0; y=0; failures=0;
      repeat(2) @(posedge clk); reset=0;
      run(0,32'h00000000,32'h00000000);
      run(1,32'h00000000,32'h3f800000);
      run(0,32'h3f490fdb,32'h3f3504f3); // pi/4, approximately .707
      run(2,32'h00000000,32'h00000000); // atan2(0,0) status marks invalid
      run_atan(32'h00000000,32'h3f800000,32'h3fc90fdb);
      run_atan(32'hbf800000,32'h00000000,32'h40490fdb);
      run_atan(32'hbf800000,32'h3f800000,32'h4016cbe4);
      run_atan(32'hbf800000,32'hbf800000,32'hc016cbe4);
      if (failures==0) $display("cordic_tb PASS"); else $display("cordic_tb FAILURES=%0d",failures);
      $finish;
    end
endmodule
