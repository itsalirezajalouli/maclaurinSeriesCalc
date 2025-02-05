// Sin Module

`timescale 1ns/1ps

// --------------------------
// nBitReg: n–bit register with parameterized initial value
// --------------------------
module nBitReg #(
  parameter n = 16,
  parameter [n-1:0] INIT_VALUE = {n{1'b0}}
) (
  input                clk,
  input                rst,
  input                init,  // load constant INIT_VALUE
  input                load,  // load new value from 'in'
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

// --------------------------
// cntReg: m–bit counter (used to count iterations)
// --------------------------
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

// --------------------------
// sineLUT: Contains reciprocal factorial coefficients for sin(x)
// (The LUT coefficients assume fixed–point Q16 representation.)
//  address 0: 1/3! ≈ 0.16666 (16'h2AAA)
//  address 1: 1/5! ≈ 0.0083333 (16'h0222)
//  address 2: 1/7! ≈ 0.00019841 (16'h000D)
//  addresses 3–7: 0
// --------------------------
module sineLUT (
  input  [2:0] addr,
  output [15:0] out
);
  reg [15:0] dataOut;
  always @(*) begin
    case(addr)
      3'd0: dataOut = 16'h2AAA; // ~0.16666...
      3'd1: dataOut = 16'h0222; // ~0.008333...
      3'd2: dataOut = 16'h000D; // ~0.000198...
      default: dataOut = 16'h0000;
    endcase
  end
  assign out = dataOut;
endmodule

// --------------------------
// sineDataPathUnit: Implements the sine series evaluation
// Series: sin(x) = x - x^3/3! + x^5/5! - x^7/7! + ...
//
// It uses a two‐step update per term:
//    (a) Multiply the previous term by x^2.
//    (b) Multiply that result by the LUT coefficient (i.e. 1/((2n+2)(2n+3))).
//
// Two muxes are used:
//    - For tReg input: if initTsel is high, load x; else load the multiplication result.
//    - For sine accumulator: if initSsel is high, load {2'b0,x}; else load the adder output.
// --------------------------
module sineDataPathUnit (
    input         clk,
    input         rst,
    input         cntUp,
    input         init0,
    input         ldX,
    input         ldT,
    input         ldSine,
    input         selXorI,    // selects multiplier input: 1 selects x^2, 0 selects LUT
    input         sub,        // if asserted, subtract the term; else add
    input         initTsel,   // when high, load tReg with x from xReg
    input         initSsel,   // when high, load sineReg with {2'b0,x} (extended x)
    input  [15:0] xBus,
    output        cnt8,
    output [17:0] rBus
);
    wire [2:0] cntOut;
    wire [17:0] sineOut;
    wire [15:0] lutOut, xOut, tOut, muxOut;
    wire [31:0] multResult;
    wire [15:0] multOut;

    // Counter instance
    cntReg #(3) cntr (
        .clk(clk), .rst(rst), .cntUp(cntUp), .init0(init0), .cnt(cntOut)
    );
    
    // LUT for sine coefficients
    sineLUT lut (
        .addr(cntOut), .out(lutOut)
    );
    
    // x register: holds the input x value
    nBitReg #(16) xReg (
        .clk(clk), .rst(rst), .init(1'b0), .load(ldX),
        .in(xBus), .out(xOut)
    );
    
    // Compute x^2 (combinationally; take the upper 16 bits of the Q32 product)
    wire [31:0] xSq_full = xBus * xBus;
    wire [15:0] xSq = xSq_full[31:16];

    // tReg input multiplexer: if initTsel is high, use xOut; else use multOut.
    wire [15:0] t_in = (initTsel) ? xOut : multOut;
    // Term register: holds the current term in the series.
    nBitReg #(16) tReg (
        .clk(clk), .rst(rst), .init(1'b0), .load(ldT),
        .in(t_in), .out(tOut)
    );
    
    // Sine accumulator multiplexer: if initSsel is high, load {2'b0, xOut}; else use adder output.
    wire [17:0] sine_in = (initSsel) ? {2'b0, xOut} : addOut;
    // Sine accumulator register (18-bit)
    nBitReg #(18) sineReg (
        .clk(clk), .rst(rst), .init(1'b0), .load(ldSine),
        .in(sine_in), .out(sineOut)
    );
    
    // Multiplier input multiplexer: if selXorI is high, select x^2; else select LUT coefficient.
    assign muxOut = (selXorI) ? xSq : lutOut;
    
    // Multiply the current term (tOut) by the selected multiplier.
    assign multResult = tOut * muxOut;
    assign multOut = multResult[31:16];

    // Compute the new accumulator value:
    // Extend tOut to 18 bits and add (or subtract) it from the current sine accumulator.
    wire signed [17:0] termExtended = sub ? -{{2{tOut[15]}}, tOut} : {{2{tOut[15]}}, tOut};
    wire signed [17:0] sSineOut = sineOut;  // treat sine accumulator as signed
    wire signed [18:0] fullAdd = { sSineOut[17], sSineOut } + { termExtended[17], termExtended };
    wire signed [17:0] addOut =
        (fullAdd < 0) ? 18'd0 :
        (fullAdd > 18'd131071) ? 18'd131071 :
        fullAdd[17:0];

    assign cnt8 = (cntOut == 3'd7);
    assign rBus = sineOut;
endmodule

// --------------------------
// sineControlUnit: State machine for sin(x)
// States:
//   IDLE:   Waiting for start
//   INIT:   Load registers with x (and reset counter)
//   ITERATE1: Multiply previous term by x^2
//   ITERATE2: Multiply result by LUT coefficient
//   SINE:   Update accumulator with computed term and increment counter
//   DONE:   Finished series evaluation
// --------------------------
module sineControlUnit (
  input  clk,
  input  rst,
  input  start,
  input  cnt8,
  output reg ldX,
  output reg ldT,
  output reg initTsel,   // when high, load tReg with x from xReg
  output reg initSsel,   // when high, load sineReg with {2'b0,x}
  output reg init0,
  output reg ldSine,
  output reg selXorI,
  output reg cntUp,
  output reg done,
  output reg sub
);
  parameter [2:0]
    IDLE     = 3'd0,
    INIT     = 3'd1,
    ITERATE1 = 3'd2,
    ITERATE2 = 3'd3,
    SINE     = 3'd4,
    DONE     = 3'd5;
    
  reg [2:0] state, next;
  // sign flag: 1 means subtract the term; 0 means add.
  // (For sin(x), the first computed term should be subtracted.)
  reg sign;

  // State register and sign toggling.
  always @(posedge clk or posedge rst) begin
    if (rst) begin
      state <= IDLE;
      sign  <= 1'b1;
    end else begin
      state <= next;
      if (state == SINE)
        sign <= ~sign;
    end
  end

  // Next-state and output logic.
  always @(*) begin
    // Default all control signals to 0.
    next      = state;
    ldX       = 0;
    ldT       = 0;
    initTsel  = 0;
    initSsel  = 0;
    init0     = 0;
    ldSine    = 0;
    selXorI   = 0;
    cntUp     = 0;
    done      = 0;
    sub       = 0;
    
    case (state)
      IDLE: begin
        if (start)
          next = INIT;
      end
      INIT: begin
        // Load x into xReg, tReg, and sineReg, and reset counter.
        ldX       = 1;
        ldT       = 1;       // Load tReg with x.
        ldSine    = 1;       // Load sineReg with x.
        initTsel  = 1;       // Select x for tReg.
        initSsel  = 1;       // Select {2'b0,x} for sineReg.
        init0     = 1;       // Reset counter.
        next = ITERATE1;
      end
      ITERATE1: begin
        // Multiply previous term by x^2.
        selXorI = 1;  // Select x^2.
        ldT     = 1;  // Update tReg.
        next    = ITERATE2;
      end
      ITERATE2: begin
        // Multiply the result by the LUT coefficient.
        selXorI = 0;  // Select LUT coefficient.
        ldT     = 1;  // Update tReg.
        next    = SINE;
      end
      SINE: begin
        // Update the sine accumulator with the computed term (adding or subtracting).
        ldSine = 1;
        cntUp  = 1;
        sub    = sign;  // Use current sign flag.
        if (cnt8)
          next = DONE;
        else
          next = ITERATE1;
      end
      DONE: begin
        done = 1;
        if (~start)
          next = IDLE;
      end
      default: next = IDLE;
    endcase
  end
endmodule

// --------------------------
// sineTop: Top-level module for sin(x)
// --------------------------
module sineTop (
  input         clk,
  input         rst,
  input         start,
  input  [15:0] xBus,
  output [17:0] rBus,
  output        done
);
  wire ldX, ldT, initTsel, initSsel, init0, ldSine, selXorI, cntUp, cnt8, sub;

  sineControlUnit sineControl (
    .clk(clk), .rst(rst), .start(start), .cnt8(cnt8),
    .ldX(ldX), .ldT(ldT), .initTsel(initTsel), .initSsel(initSsel),
    .init0(init0), .ldSine(ldSine), .selXorI(selXorI),
    .cntUp(cntUp), .done(done), .sub(sub)
  );

  sineDataPathUnit sineDataPath (
    .clk(clk), .rst(rst), .cntUp(cntUp), .init0(init0),
    .ldX(ldX), .ldT(ldT), .ldSine(ldSine),
    .selXorI(selXorI), .sub(sub),
    .initTsel(initTsel), .initSsel(initSsel),
    .xBus(xBus), .cnt8(cnt8), .rBus(rBus)
  );
endmodule

