// look up table module for cos 
module cosLUT (input [2:0]addr, output [15:0] data);
  reg [15:0] dataOut;
  always @(addr) begin
    case(addr)
      0: dataOut = 16'h8000; // 1/2!
      1: dataOut = 16'h0AAB; // 1/4!
      2: dataOut = 16'h005B; // 1/6!
      3: dataOut = 16'h0002; // 1/8!
      4: dataOut = 16'h0000; // 1/10! ~= 0
      5: dataOut = 16'h0000; // 1/12! ~= 0
      6: dataOut = 16'h0000; // 1/14! ~= 0
      7: dataOut = 16'h0000; // 1/16! ~= 0
    endcase
  end
  assign data = dataOut;
endmodule
