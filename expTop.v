// top module for exponential
module expTop (input clk, rst, start, input [15:0] xBus, output [17:0] rBus, output done);
  // 1-bit wires 
  wire cntUp, init0, ldX, ldT, initT1, initE1, selXR, cnt8;

  // datapath
  expDU du(clk, rst, cntUp, init0, ldX, ldT, initT1, ldE, initE1, selXR, xBus, cnt8, rBus);

  // controller
  expCU cp(clk, rst, start, cnt8, done, ldX, initT1, initE1, ldT, ldE, init0, cntUp, selXR);

endmodule
