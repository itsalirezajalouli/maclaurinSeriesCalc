
`timescale 1ns/1ps

// =============================================================================
// nBitReg: n–bit register with parameterized initial value
// =============================================================================
module nBitReg #(
  parameter n = 16,
  parameter [n-1:0] INIT_VALUE = {n{1'b0}}
) (
  input                clk,
  input                rst,
  input                init,  // load initial value
  input                load,  // load new value
  input  [n - 1:0]     in,
  output reg [n - 1:0] out
);
  always @(posedge clk or posedge rst)
    if (rst)
      out <= 0;
    else if (init)
      out <= INIT_VALUE;
    else if (load)
      out <= in;
endmodule

// =============================================================================
// cntReg: m–bit counter (used to count iterations)
// =============================================================================
module cntReg #(
  parameter m = 3
) (
  input              clk,
  input              rst,
  input              cntUp,
  input              init0,
  output reg [m - 1:0] cnt
);
  always @(posedge clk or posedge rst)
    if (rst)
      cnt <= 0;
    else if (init0)
      cnt <= 0;
    else if (cntUp)
      cnt <= cnt + 1;
endmodule

// =============================================================================
// -------------------------- EXPONENTIAL MODULES -----------------------------
// =============================================================================

// expLUT: Provides reciprocal values for i = 1..8
// For index 0 the LUT returns 1.0.
module expLUT (
  input  [2:0] addr,
  output [15:0] out
);
  reg [15:0] dataOut;
  always @(*) begin
    case(addr)
      3'd0: dataOut = 16'hFFFF; // 1.0
      3'd1: dataOut = 16'h8000; // 0.5000000000
      3'd2: dataOut = 16'h5555; // 0.3333333333
      3'd3: dataOut = 16'h4000; // 0.2500000000
      3'd4: dataOut = 16'h3333; // 0.2000000000
      3'd5: dataOut = 16'h2AAB; // 0.1666666667 (more precise)
      3'd6: dataOut = 16'h2492; // 0.1428571429
      3'd7: dataOut = 16'h2000; // 0.1250000000
      default: dataOut = 16'h0000;
    endcase
  end
  assign out = dataOut;
endmodule

// expDataPathUnit: Computes exp(x)= 1 + x + x^2/2! + x^3/3! + …
// The accumulator is 18-bit (Q2.16) and the term register is 16-bit.
module expDataPathUnit (
    input         clk,
    input         rst,
    input         cntUp,
    input         init0,
    input         ldX,
    input         ldT,
    input         initT1,
    input         initExp1,
    input         ldExp,
    input         selXorI,
    input  [15:0] xBus,
    output        cnt8,
    output [17:0] rBus
);
    wire [2:0] cntOut;
    wire [17:0] expOut, addOut;
    wire [15:0] lutOut, xOut, tOut, muxOut;
    wire [31:0] multResult;  // Full 32-bit multiplication result
    wire [15:0] multOut;
    
    // Counter
    cntReg #(3) cntr (
        .clk(clk), .rst(rst), .cntUp(cntUp), .init0(init0), .cnt(cntOut)
    );
    
    // LUT instantiation
    expLUT lut (
        .addr(cntOut), .out(lutOut)
    );
    
    // x register
    nBitReg #(16) xReg (
        .clk(clk), .rst(rst), .init(1'b0), .load(ldX),
        .in(xBus), .out(xOut)
    );
    
    // Term register (16-bit) initialized to 1.0 (16'hFFFF)
    nBitReg #(16, 16'hFFFF) tReg (
        .clk(clk), .rst(rst), .init(initT1), .load(ldT),
        .in(multOut), .out(tOut)
    );
    
    // Exponential accumulator (18-bit); 1.0 = 18'h10000
    nBitReg #(18, 18'h10000) eReg (
        .clk(clk), .rst(rst), .init(initExp1), .load(ldExp),
        .in(addOut), .out(expOut)
    );
    
    assign muxOut = (selXorI) ? xOut : lutOut;
    
    // Full precision multiplication
    assign multResult = tOut * muxOut;
    assign multOut = multResult[31:16];  // Take correct bits for Q0.16 result
    
    // Proper addition with saturation
    wire [18:0] fullAdd = {1'b0, expOut} + {3'b000, tOut};
    assign addOut = fullAdd[18] ? 18'h3FFFF : fullAdd[17:0];
    
    assign cnt8 = (cntOut == 3'd7);
    assign rBus = expOut;

endmodule

// expControlUnit: Revised FSM for exp(x)
// FSM states: IDLE, INIT, ITERATE1, ITERATE2, ACCUM, DONE.
//
module expControlUnit (
  input clk,
  input rst,
  input start,
  input cnt8,
  output reg ldX,
  output reg initT1,
  output reg initExp1,  // accumulator initialization
  output reg init0,
  output reg ldT,
  output reg ldExp,
  output reg selXorI,
  output reg cntUp,
  output reg done
);
  parameter [2:0]
    IDLE      = 3'd0,
    INIT      = 3'd1,
    ITERATE1  = 3'd2,
    ITERATE2  = 3'd3,
    ACCUM     = 3'd4,
    DONE      = 3'd5;
    
  reg [2:0] state, next;
  
  // State register
  always @(posedge clk or posedge rst)
    if (rst) state <= IDLE; else state <= next;
    
  // Next-state and output logic
  always @(*) begin
    next = state;
    // Set default signal values (all 0 by default)
    ldX      = 0;
    initT1   = 0;
    initExp1 = 0;
    init0    = 0;
    ldT      = 0;
    ldExp    = 0;
    selXorI  = 0;
    cntUp    = 0;
    done     = 0;  // <--- default done = 0

    case (state)
      IDLE: begin
         // DONE should not be asserted in IDLE.
         if (start)
           next = INIT;
         else
           next = IDLE;
      end
      INIT: begin
         // Initialize: load term with 1.0, accumulator with 1.0, reset counter, load x.
         initT1   = 1;
         initExp1 = 1;
         init0    = 1;
         ldX      = 1;
         next = ITERATE1;
      end
      ITERATE1: begin
         // Multiply previous term by x.
         selXorI = 1;  // select x
         ldT     = 1;
         next    = ITERATE2;
      end
      ITERATE2: begin
         // Multiply by LUT factor (divide by factorial factor).
         selXorI = 0;  // select LUT output
         ldT     = 1;
         next    = ACCUM;
      end
      ACCUM: begin
         // Add computed term to accumulator and increment counter.
         ldExp = 1;
         cntUp = 1;
         if (cnt8)
           next = DONE;
         else
           next = ITERATE1;
      end
      DONE: begin
         done = 1;  // done asserted only here.
         if (~start)
           next = IDLE;
         else
           next = DONE;
      end
      default: next = IDLE;
    endcase
  end
endmodule

// expTop: Top-level module for exp(x)
module expTop (
  input         clk,
  input         rst,
  input         start,
  input  [15:0] xBus,
  output [17:0] rBus,
  output        done
);
  wire ldX, initT1, initExp1, init0, ldT, ldExp, selXorI, cntUp, cnt8;
  
  expControlUnit expControl (
    .clk(clk), .rst(rst), .start(start), .cnt8(cnt8),
    .ldX(ldX), .initT1(initT1), .initExp1(initExp1), .init0(init0),
    .ldT(ldT), .ldExp(ldExp), .selXorI(selXorI),
    .cntUp(cntUp), .done(done)
  );
  
  expDataPathUnit expDataPath (
    .clk(clk), .rst(rst), .cntUp(cntUp), .init0(init0),
    .ldX(ldX), .ldT(ldT), .initT1(initT1), .initExp1(initExp1),
    .ldExp(ldExp), .selXorI(selXorI), .xBus(xBus),
    .cnt8(cnt8), .rBus(rBus)
  );
endmodule

