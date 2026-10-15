// Serialized command interface around a streaming arithmetic pipeline and
// iterative CORDIC. See README for opcode/operand/status definitions.
module math_accelerator (
    input clk, reset, start, input [3:0] opcode,
    input [31:0] operand_a,operand_b,operand_c,operand_d,operand_e,operand_f,
    output reg [31:0] result,result_imag,
    output reg busy,done,valid, output reg [7:0] error
);
    wire accept = start && !busy;
    wire trig_request = opcode>=9 && opcode<=11;
    wire arithmetic_valid;
    wire [31:0] arithmetic_result,arithmetic_imag;
    wire [7:0] arithmetic_error;
    wire [3:0] arithmetic_opcode;
    arithmetic_pipeline arithmetic (
        .clk(clk),.reset(reset),.valid_in(accept && !trig_request),.opcode(opcode),
        .a(operand_a),.b(operand_b),.c(operand_c),.d(operand_d),.e(operand_e),.f(operand_f),
        .valid_out(arithmetic_valid),.opcode_out(arithmetic_opcode),
        .result(arithmetic_result),.result_imag(arithmetic_imag),.error(arithmetic_error)
    );
    reg cordic_start,trig_active;
    reg [1:0] mode_reg;
    reg [31:0] a_reg,b_reg;
    wire [31:0] cordic_result,cordic_imag;
    wire cordic_done,cordic_valid,cordic_busy;
    wire [4:0] cordic_status;
    cordic trig (
        .clk(clk),.reset(reset),.start(cordic_start),.mode(mode_reg),.angle(a_reg),
        .x_input(b_reg),.y_input(a_reg),.result(cordic_result),.result_imag(cordic_imag),
        .busy(cordic_busy),.done(cordic_done),.valid(cordic_valid),.status(cordic_status)
    );
    always @(posedge clk) begin
        if(reset) begin
            cordic_start<=0;trig_active<=0;mode_reg<=0;a_reg<=0;b_reg<=0;
            busy<=0;done<=0;valid<=0;result<=0;result_imag<=0;error<=0;
        end else begin
            done<=0;valid<=0;cordic_start<=0;
            if(accept) begin
                busy<=1;trig_active<=trig_request;
                if(trig_request) begin
                    mode_reg<=opcode-9; a_reg<=operand_a;b_reg<=operand_b;cordic_start<=1;
                end
            end
            if(busy && ((!trig_active && arithmetic_valid) || (trig_active && cordic_done))) begin
                busy<=0;done<=1;valid<=1;
                result<=trig_active ? cordic_result : arithmetic_result;
                result_imag<=trig_active ? cordic_imag : arithmetic_imag;
                error<=trig_active ? {3'b0,cordic_status} : arithmetic_error;
            end
        end
    end
endmodule
