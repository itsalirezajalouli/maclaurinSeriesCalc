// top module for sin 
module sinTop (input clk, rst, start, input [15:0] xBus, output [17:0] rBus, output done);
  // 1-bit wires 
  wire cntUp, init0, ldX, ldT, initT1, initS1, selXR, cnt8;

  // datapath
  sinDU du(clk, rst, cntUp, init0, ldX, ldT, initT1, ldS, initS1, selXR, xBus, cnt8, rBus);

  // controller
  sinCU cp(clk, rst, start, cnt8, done, ldX, initT1, initS1, ldT, ldS, init0, cntUp, selXR);

endmodule
