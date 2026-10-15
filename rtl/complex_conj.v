module complex_conj (
    input [31:0] ar, input [31:0] ai,
    output [31:0] rr, output [31:0] ri, output [4:0] status
);
    assign rr = ar;
    assign ri = {~ai[31],ai[30:0]};
    assign status = ((ar[30:23] == 8'hff && ar[22:0] != 0) ||
                     (ai[30:23] == 8'hff && ai[22:0] != 0)) ? 5'b00010 : 5'b0;
endmodule
