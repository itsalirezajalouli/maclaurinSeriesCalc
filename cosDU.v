// datapath module for sin 
module cosDU (input clk, rst, cntUp, init0, ldX, ldT, initT1, ldC, initC1, selXR,
  input [15:0] xBus, output cnt8, output [17:0] rBus);

  // mid-level signals
  wire [2:0] cntOut;
  wire [17:0] cOut, addOut;
  wire [15:0] lutOut, xOut, tOut, muxOut;
  wire [31:0] mulOut;
  wire isOdd;
  wire [31:0] xSquared;

  // module instantiations 
  cntReg cntr(clk, rst, cntUp, init0, cntOut);
  cosLUT lut(cntOut, lutOut);
  reg16 xReg(clk, rst, 1'b0, ldX, xBus, xOut); // no need to initialize
  reg16 tReg(clk, rst, initT1, ldT, mulOut[31:16], tOut); // back to exp style (init to 1)
  reg18 cReg(clk, rst, initC1, ldC, addOut, cOut); // back to exp style

  // add sub assignment: if it's odd cntOut[0] would be 1
  assign isOdd = cntOut[0]; // new

  // output assigning
  assign xSquared = xOut * xOut; // new
  assign muxOut = (selXR == 0) ? xSquared[31:16] : lutOut; // mux
  assign mulOut = (muxOut * tOut); 
  assign addOut = (isOdd == 1) ? cOut - {2'b00, tOut} : cOut + {2'b00, tOut}; // new

  // final output
  assign rBus = cOut;
  assign cnt8 = (cntOut == 3'b111) ? 1 : 0;

endmodule
