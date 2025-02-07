// datapath module for exponential
module expDU (input clk, rst, cntUp, init0, ldX, ldT, initT1, ldE, initE1, selXR,
  input [15:0] xBus, output cnt8, output [17:0] rBus);

  // mid-level signals
  wire [2:0] cntOut;
  wire [17:0] eOut, addOut;
  wire [15:0] lutOut, xOut, tOut, muxOut;
  wire [31:0] mulOut;

  // module instantiations 
  cntReg cntr(clk, rst, cntUp, init0, cntOut);
  expLUT lut(cntOut, lutOut);
  reg16 xReg(clk, rst, 1'b0, ldX, xBus, xOut); // no need to initialize
  reg16 tReg(clk, rst, initT1, ldT, mulOut[31:16], tOut);
  reg18 eReg(clk, rst, initE1, ldE, addOut, eOut);

  // output assigning
  assign muxOut = (selXR == 1) ? xOut: lutOut; // mux
  assign addOut = eOut + {2'b00, tOut};
  assign mulOut = (muxOut * tOut); 

  // final output
  assign rBus = eOut;
  assign cnt8 = (cntOut == 3'b111) ? 1 : 0;

endmodule
