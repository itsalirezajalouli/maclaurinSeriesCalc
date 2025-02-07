// datapath module for ln(x + 1)
module lnDU (input clk, rst, cntUp, init0, ldX, ldT, initT1, ldLN, initLN1, selXR,
  input [15:0] xBus, output cnt8, output [17:0] rBus);

  // mid-level signals
  wire [2:0] cntOut;
  wire [17:0] lnOut, addOut;
  wire [15:0] lutOut, xOut, tOut, muxOut;
  wire [31:0] mulOut;
  wire isOdd;
  wire [31:0] xSquared;

  // module instantiations 
  cntReg cntr(clk, rst, cntUp, init0, cntOut);
  lnLUT lut(cntOut, lutOut);
  reg16 xReg(clk, rst, 1'b0, ldX, xBus, xOut); // no need to initialize
  reg16 tReg(clk, rst, initT1, ldT, mulOut[31:16], tOut); // t = 1 in the begining
  sinReg18 lnReg(clk, rst, initLN1, ldLN, {2'b00, xOut}, addOut, lnOut); // ln = xin in init 

  // add sub assignment: if it's odd cntOut[0] would be 1
  assign isOdd = cntOut[0]; // new

  // output assigning
  assign muxOut = (selXR == 1) ? xOut : lutOut; // mux
  assign mulOut = (muxOut * tOut); 
  assign addOut = (isOdd == 1) ? lnOut - {2'b00, tOut} : lnOut + {2'b00, tOut}; // new

  // final output
  assign rBus = lnOut;
  assign cnt8 = (cntOut == 3'b111) ? 1 : 0;

endmodule
