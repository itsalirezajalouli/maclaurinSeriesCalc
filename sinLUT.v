// look up table module for sin 
module sinLUT (input [2:0]addr, output [15:0] data);
  reg [15:0] dataOut;
  always @(addr) begin
    case(addr)
      0: dataOut = 16'hFFFF; // 1/1!
      1: dataOut = 16'h2AAB; // 1/3!
      2: dataOut = 16'h0222; // 1/5!
      3: dataOut = 16'h000D; // 1/7!
      4: dataOut = 16'h0000; // 1/9! ~= 0
      5: dataOut = 16'h0000; // 1/11! ~= 0
      6: dataOut = 16'h0000; // 1/13! ~= 0
      7: dataOut = 16'h0000; // 1/15! ~= 0
    endcase
  end
  assign data = dataOut;
endmodule
