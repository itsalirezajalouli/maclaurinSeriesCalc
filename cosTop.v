// top module for cos 
module cosTop (input clk, rst, start, input [15:0] xBus, output [17:0] rBus, output done);
  // 1-bit wires 
  wire cntUp, init0, ldX, ldT, initT1, initC1, selXR, cnt8;

  // datapath
  cosDU du(clk, rst, cntUp, init0, ldX, ldT, initT1, ldC, initC1, selXR, xBus, cnt8, rBus);

  // controller
  cosCU cp(clk, rst, start, cnt8, done, ldX, initT1, initC1, ldT, ldC, init0, cntUp, selXR);

endmodule
