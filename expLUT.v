// look up table module for exponential
module expLUT (input [2:0]addr, output [15:0] data);
  reg [15:0] dataOut;
  always @(addr) begin
    case(addr)
      0: dataOut = 16'hFFFF; // 1/1!
      1: dataOut = 16'h8000; // 1/2!
      2: dataOut = 16'h2AAB; // 1/3!
      3: dataOut = 16'h0AAB; // 1/4!
      4: dataOut = 16'h0222; // 1/5!
      5: dataOut = 16'h005B; // 1/6!
      6: dataOut = 16'h000D; // 1/7!
      7: dataOut = 16'h0002; // 1/8!
    endcase
  end
  assign data = dataOut;
endmodule
