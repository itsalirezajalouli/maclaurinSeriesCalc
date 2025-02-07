// datapath module for sin 
module sinDU (input clk, rst, cntUp, init0, ldX, ldT, initT1, ldS, initS1, selXR,
  input [15:0] xBus, output cnt8, output [17:0] rBus);

  // mid-level signals
  wire [2:0] cntOut;
  wire [17:0] sOut, addOut;
  wire [15:0] lutOut, xOut, tOut, muxOut;
  wire [31:0] mulOut;
  wire isOdd;
  wire [31:0] xSquared;

  // module instantiations 
  cntReg cntr(clk, rst, cntUp, init0, cntOut);
  sinLUT lut(cntOut, lutOut);
  reg16 xReg(clk, rst, 1'b0, ldX, xBus, xOut); // no need to initialize
  sinReg16 tReg(clk, rst, initT1, ldT, xOut, mulOut[31:16], tOut); // new
  sinReg18 sReg(clk, rst, initS1, ldS, {2'b00, xOut}, addOut, sOut); // new

  // add sub assignment: if it's odd cntOut[0] would be 1
  assign isOdd = cntOut[0]; // new

  // output assigning
  assign xSquared = xOut * xOut; // new
  assign muxOut = (selXR == 1) ? xSquared[31:16] : lutOut; // mux
  assign mulOut = (muxOut * tOut); 
  assign addOut = (isOdd == 1) ? sOut - {2'b00, tOut} : sOut + {2'b00, tOut}; // new

  // final output
  assign rBus = sOut;
  assign cnt8 = (cntOut == 3'b111) ? 1 : 0;

endmodule
