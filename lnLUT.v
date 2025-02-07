// look up table module for ln(x+1)
module lnLUT (input [2:0]addr, output [15:0] data);
  reg [15:0] dataOut;
  always @(addr) begin
    case(addr)
      0: dataOut = 16'h8000; // 1/2
      1: dataOut = 16'h5555; // 1/3
      2: dataOut = 16'h4000; // 1/4
      3: dataOut = 16'h3333; // 1/5
      4: dataOut = 16'h2AAA; // 1/6
      5: dataOut = 16'h2492; // 1/7
      6: dataOut = 16'h2000; // 1/8
      7: dataOut = 16'h0000; // 1/9
    endcase
  end
  assign data = dataOut;
endmodule
