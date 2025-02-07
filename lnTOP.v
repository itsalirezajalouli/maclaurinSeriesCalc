// top module for ln
module lnTop (input clk, rst, start, input [15:0] xBus, output [17:0] rBus, output done);
  // 1-bit wires 
  wire cntUp, init0, ldX, ldT, initT1, initLN1, selXR, cnt8;

  // datapath
  lnDU du(clk, rst, cntUp, init0, ldX, ldT, initT1, ldLN, initLN1, selXR, xBus, cnt8, rBus);

  // controller
  lnCU cp(clk, rst, start, cnt8, done, ldX, initT1, initLN1, ldT, ldLN, init0, cntUp, selXR);

endmodule
