// Iterative rotation/vectoring CORDIC.
// Angle format: signed Q4.28 radians. Cartesian format: signed Q2.30.
// 28 iterations provide approximately 2^-27 radian convergence error.
module cordic (
    input clk, input reset, input start,
    input [1:0] mode,                 // 0=sin, 1=cos, 2=atan2
    input [31:0] angle,
    input [31:0] x_input, input [31:0] y_input,
    output reg [31:0] result,
    output reg [31:0] result_imag,
    output reg busy, output reg done, output reg valid,
    output reg [4:0] status
);
    localparam signed [31:0] PI       = 32'sh3243f6a9;
    localparam signed [31:0] TWO_PI   = 32'sh6487ed52;
    localparam signed [31:0] HALF_PI  = 32'sh1921fb54;
    localparam signed [31:0] CORDIC_K = 32'sh26dd3b6a; // 0.607252935 * 2^30

    wire signed [31:0] angle_fixed;
    wire signed [31:0] x_fixed, y_fixed;
    fp32_to_fixed #(.FRAC_BITS(28)) angle_conv (.value(angle),.fixed_value(angle_fixed));
    fp32_to_fixed #(.FRAC_BITS(30)) x_conv (.value(x_input),.fixed_value(x_fixed));
    fp32_to_fixed #(.FRAC_BITS(30)) y_conv (.value(y_input),.fixed_value(y_fixed));

    reg signed [31:0] x_reg, y_reg, z_reg;
    reg [4:0] iteration;
    reg [1:0] mode_reg;
    reg signed [31:0] start_z;
    reg signed [31:0] start_x, start_y;
    reg signed [31:0] next_x, next_y, next_z;
    reg signed [31:0] z_normal;
    reg signed [31:0] x_seed, y_seed;
    reg invalid_start;
    wire [31:0] sin_value, cos_value, atan_value;
    fixed_to_fp32 #(.FRAC_BITS(30)) sin_conv (.fixed_value(next_y),.value(sin_value));
    fixed_to_fp32 #(.FRAC_BITS(30)) cos_conv (.fixed_value(next_x),.value(cos_value));
    fixed_to_fp32 #(.FRAC_BITS(28)) atan_conv (.fixed_value(next_z),.value(atan_value));

    function signed [31:0] scale_cordic;
        input signed [31:0] value;
        reg signed [63:0] product_scale;
        begin
            product_scale = value * CORDIC_K;
            scale_cordic = product_scale >>> 30;
        end
    endfunction

    function signed [31:0] atan_constant;
        input [4:0] n;
        begin
            case (n)
              0: atan_constant=32'sh0c90fdaa; 1: atan_constant=32'sh076b19c1;
              2: atan_constant=32'sh03eb6ebf; 3: atan_constant=32'sh01fd5ba9;
              4: atan_constant=32'sh00ffaade; 5: atan_constant=32'sh007ff557;
              6: atan_constant=32'sh003ffeaa; 7: atan_constant=32'sh001fffd5;
              8: atan_constant=32'sh000ffffb; 9: atan_constant=32'sh0007ffff;
             10: atan_constant=32'sh00040000; 11: atan_constant=32'sh00020000;
             12: atan_constant=32'sh00010000; 13: atan_constant=32'sh00008000;
             14: atan_constant=32'sh00004000; 15: atan_constant=32'sh00002000;
             16: atan_constant=32'sh00001000; 17: atan_constant=32'sh00000800;
             18: atan_constant=32'sh00000400; 19: atan_constant=32'sh00000200;
             20: atan_constant=32'sh00000100; 21: atan_constant=32'sh00000080;
             22: atan_constant=32'sh00000040; 23: atan_constant=32'sh00000020;
             24: atan_constant=32'sh00000010; 25: atan_constant=32'sh00000008;
             26: atan_constant=32'sh00000004; 27: atan_constant=32'sh00000002;
             default: atan_constant=0;
            endcase
        end
    endfunction

    // One combinational iteration. Arithmetic is signed two's complement;
    // the shifts are the CORDIC's multiply-by-2^-i operations.
    always @(*) begin
        if (mode_reg == 2) begin
            if (y_reg >= 0) begin
                next_x = x_reg + (y_reg >>> iteration);
                next_y = y_reg - (x_reg >>> iteration);
                next_z = z_reg + atan_constant(iteration);
            end else begin
                next_x = x_reg - (y_reg >>> iteration);
                next_y = y_reg + (x_reg >>> iteration);
                next_z = z_reg - atan_constant(iteration);
            end
        end else begin
            if (z_reg >= 0) begin
                next_x = x_reg - (y_reg >>> iteration);
                next_y = y_reg + (x_reg >>> iteration);
                next_z = z_reg - atan_constant(iteration);
            end else begin
                next_x = x_reg + (y_reg >>> iteration);
                next_y = y_reg - (x_reg >>> iteration);
                next_z = z_reg + atan_constant(iteration);
            end
        end
    end

    always @(posedge clk) begin
        if (reset) begin
            busy <= 0; done <= 0; valid <= 0; result <= 0; result_imag <= 0;
            status <= 0; x_reg <= 0; y_reg <= 0; z_reg <= 0; iteration <= 0;
        end else begin
            done <= 0; valid <= 0;
            if (start && !busy) begin
                busy <= 1; iteration <= 0; mode_reg <= mode; status <= 0;
                if (mode == 2) begin
                    invalid_start <= (x_fixed == 0 && y_fixed == 0);
                    if (x_fixed < 0) begin
                        // Explicit two's-complement absolute values avoid
                        // context-dependent unary-minus sizing in Verilog.
                        x_reg <= scale_cordic((~x_fixed) + 32'd1);
                        y_reg <= scale_cordic((~y_fixed) + 32'd1);
                        z_reg <= (y_fixed >= 0) ? PI : -PI;
                    end else begin
                        x_reg <= scale_cordic(x_fixed); y_reg <= scale_cordic(y_fixed); z_reg <= 0;
                    end
                end else begin
                    // Reduce to the CORDIC convergence interval and rotate
                    // by pi when the original angle is in quadrants II/III.
                    z_normal = angle_fixed;
                    if (z_normal > PI) z_normal = z_normal - TWO_PI;
                    if (z_normal < -PI) z_normal = z_normal + TWO_PI;
                    x_seed = CORDIC_K; y_seed = 0;
                    if (z_normal > HALF_PI) begin z_normal=z_normal-PI; x_seed=-CORDIC_K; end
                    if (z_normal < -HALF_PI) begin z_normal=z_normal+PI; x_seed=-CORDIC_K; end
                    x_reg <= x_seed; y_reg <= y_seed; z_reg <= z_normal;
                    invalid_start <= 0;
                end
            end else if (busy) begin
                x_reg <= next_x; y_reg <= next_y; z_reg <= next_z;
                if (iteration == 27) begin
                    busy <= 0; done <= 1; valid <= 1;
                    if (mode_reg == 2) begin
                        result <= atan_value; result_imag <= 0;
                        status[0] <= invalid_start;
                    end else begin
                        result <= (mode_reg == 0) ? sin_value : cos_value;
                        result_imag <= 0;
                    end
                    iteration <= 0;
                end else iteration <= iteration + 1'b1;
            end
        end
    end
endmodule
