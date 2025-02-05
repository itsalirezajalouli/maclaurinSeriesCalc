
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
  input         initT1,    // load tReg with 1.0
  input         initExp1,  // load accumulator with 1.0
  input         ldExp,
  input         selXorI,   // 1: multiply by x; 0: multiply by LUT factor
  input  [15:0] xBus,
  output        cnt8,
  output [17:0] rBus
);
  wire [2:0] cntOut;
  wire [17:0] expOut, addOut;
  wire [15:0] lutOut, xOut, tOut, muxOut;
  wire [31:0] multResult;  // New: full multiplication result
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
  
  // Exponential accumulator (18-bit); in Q2.16, 1.0 = 18'h0FFFF.
  nBitReg #(18, 18'h0FFFF) eReg (
    .clk(clk), .rst(rst), .init(initExp1), .load(ldExp),
    .in(addOut), .out(expOut)
  );
  
  assign muxOut = (selXorI) ? xOut : lutOut;
  assign multResult = tOut * muxOut;  // Full 32-bit multiplication
  assign multOut = multResult[31:16]; // Take proper bits after multiplication

  wire [17:0] nextExp;
  assign nextExp = expOut + {2'b00, tOut};
  wire overflow = (nextExp[17] && !expOut[17] && !tOut[15]) ||
                 (!nextExp[17] && expOut[17] && tOut[15]);
  
  assign addOut = overflow ? (nextExp[17] ? 18'h00000 : 18'h3FFFF) : nextExp;
  assign cnt8 = (cntOut == 3'd7);
  assign rBus = expOut;
endmodule

// expControlUnit: Revised FSM for exp(x)
// FSM states: IDLE, INIT, ITERATE1, ITERATE2, ACCUM, DONE.
module expControlUnit (
  input clk,
  input rst,
  input start,
  input cnt8,
  output reg ldX,
  output reg initT1,
  output reg initExp1,  // new signal for accumulator initialization
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
    // Default signal assignments
    ldX      = 0;
    initT1   = 0;
    initExp1 = 0;
    init0    = 0;
    ldT      = 0;
    ldExp    = 0;
    selXorI  = 0;
    cntUp    = 0;
    done     = 0;
    
    case (state)
      IDLE: begin
         done = 1;
         if (start)
           next = INIT;
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
         // Multiply by LUT factor (i.e. divide by factorial).
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
         done = 1;
         if (~start)
           next = IDLE;
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

// =============================================================================
// ---------------------------- SINE MODULES ----------------------------------
// =============================================================================

// sinLUT: For sin(x)= x - x^3/3! + x^5/5! - …
// For the first term the LUT returns 1.0 so that the term remains x.
module sinLUT (
  input  [2:0] addr,
  output [15:0] out
);
  reg [15:0] dataOut;
  always @(*) begin
    case(addr)
      3'd0: dataOut = 16'hFFFF; // 1.0
      3'd1: dataOut = 16'h0555; // 1/3!
      3'd2: dataOut = 16'h0111; // 1/5!
      3'd3: dataOut = 16'h0016; // 1/7!
      3'd4: dataOut = 16'h0003; // 1/9!
      3'd5: dataOut = 16'h0001; // 1/11!
      default: dataOut = 16'h0000;
    endcase
  end
  assign out = dataOut;
endmodule

// sinDataPathUnit: Computes sin(x)= x - x^3/3! + x^5/5! - …
// The accumulator is 18-bit; for the first update we load x.
module sinDataPathUnit (
  input         clk,
  input         rst,
  input         cntUp,
  input         init0,
  input         ldX,
  input         ldT,
  input         initT,    // load term register with x initially
  input         ldSin,
  input         addSub,   // 0: add, 1: subtract
  input  [15:0] xBus,
  output        cnt8,
  output [17:0] rBus,
  output        signBit,
  output        firstTerm
);
  wire [2:0] cntOut;
  wire [15:0] lutOut;
  wire [15:0] xOut, tOut;
  wire [15:0] xSquared, computedTerm, multOut;
  wire [17:0] sinOut, addSubOut;
  
  cntReg #(3) cntr (
    .clk(clk), .rst(rst), .cntUp(cntUp), .init0(init0), .cnt(cntOut)
  );
  
  sinLUT lut (
    .addr(cntOut), .out(lutOut)
  );
  
  nBitReg #(16) xReg (
    .clk(clk), .rst(rst), .init(1'b0), .load(ldX),
    .in(xBus), .out(xOut)
  );
  
  nBitReg #(16) tReg (
    .clk(clk), .rst(rst), .init(initT), .load(ldT),
    .in(multOut), .out(tOut)
  );
  
  // 18-bit accumulator for sin
  nBitReg #(18, 18'h0000) sinReg (
    .clk(clk), .rst(rst), .init(1'b0), .load(ldSin),
    .in(addSubOut), .out(sinOut)
  );
  
  assign xSquared = (xOut * xOut) >> 16;
  // For cnt==0, use x; otherwise, update term = (previous_term * xSquared) >> 16.
  assign computedTerm = (cntOut == 3'd0) ? xOut : ((tOut * xSquared) >> 16);
  // Multiply by LUT factor.
  assign multOut = (computedTerm * lutOut) >> 16;
  
  // For the first term, load accumulator with x; otherwise add/subtract term.
  assign addSubOut = (cntOut == 3'd0) ? {2'b00, xOut} :
                     (addSub ? (sinOut - {2'b00, tOut})
                             : (sinOut + {2'b00, tOut}));
  
  assign rBus = sinOut;
  assign signBit = cntOut[0];  // use counter LSB to alternate sign
  assign firstTerm = (cntOut == 3'd0);
  assign cnt8 = (cntOut == 3'd7);
endmodule

// sinControlUnit: Revised FSM for sin(x)
module sinControlUnit (
  input  clk,
  input  rst,
  input  start,
  input  cnt8,
  input  signBit,
  output reg ldX,
  output reg initT,   // load term register with x initially
  output reg ldT,
  output reg ldSin,
  output reg addSub,  // use signBit for alternating add/sub
  output reg cntUp,
  output reg done
);
  parameter [2:0]
    IDLE     = 3'd0,
    INIT     = 3'd1,
    ITERATE1 = 3'd2,
    ITERATE2 = 3'd3,
    ACCUM    = 3'd4,
    DONE     = 3'd5;
    
  reg [2:0] state, next;
  always @(posedge clk or posedge rst)
    if (rst) state <= IDLE; else state <= next;
    
  always @(*) begin
    next = state;
    ldX    = 0;
    initT  = 0;
    ldT    = 0;
    ldSin  = 0;
    addSub = 0;
    cntUp  = 0;
    done   = 0;
    case (state)
      IDLE: begin
         done = 1;
         if (start)
           next = INIT;
      end
      INIT: begin
         initT = 1;  // load term register with x
         ldX   = 1;
         next  = ITERATE1;
      end
      ITERATE1: begin
         ldT = 1;
         next = ITERATE2;
      end
      ITERATE2: begin
         next = ACCUM;
      end
      ACCUM: begin
         ldSin = 1;
         cntUp = 1;
         addSub = signBit;
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

// sinTop: Top-level module for sin(x)
module sinTop (
  input         clk,
  input         rst,
  input         start,
  input  [15:0] xBus,
  output [17:0] rBus,
  output        done
);
  wire ldX, initT, ldT, ldSin, cntUp, cnt8, signBit;
  
  sinControlUnit sinControl (
    .clk(clk), .rst(rst), .start(start), .cnt8(cnt8),
    .signBit(signBit),
    .ldX(ldX), .initT(initT), .ldT(ldT), .ldSin(ldSin),
    .addSub(signBit),  // using signBit to alternate
    .cntUp(cntUp), .done(done)
  );
  
  sinDataPathUnit sinDataPath (
    .clk(clk), .rst(rst), .cntUp(cntUp), .init0(1'b0),
    .ldX(ldX), .ldT(ldT), .initT(initT), .ldSin(ldSin),
    .addSub(signBit), .xBus(xBus),
    .cnt8(cnt8), .rBus(rBus),
    .signBit(signBit), .firstTerm()
  );
endmodule

// =============================================================================
// ---------------------------- COSINE MODULES --------------------------------
// =============================================================================

// cosLUT: For cos(x)= 1 - x^2/2! + x^4/4! - …
// Index 0 returns 1.0.
module cosLUT (
  input  [2:0] addr,
  output [15:0] out
);
  reg [15:0] dataOut;
  always @(*) begin
    case(addr)
      3'd0: dataOut = 16'hFFFF; // 1.0
      3'd1: dataOut = 16'h4000; // 1/2!
      3'd2: dataOut = 16'h0555; // 1/4!
      3'd3: dataOut = 16'h0095; // 1/6!
      3'd4: dataOut = 16'h0010; // 1/8!
      3'd5: dataOut = 16'h0004; // 1/10!
      3'd6: dataOut = 16'h0001; // 1/12!
      default: dataOut = 16'h0000;
    endcase
  end
  assign out = dataOut;
endmodule

// cosDataPathUnit: Computes cos(x)= 1 - x^2/2! + x^4/4! - …
// The accumulator is 18-bit and should be initialized to 1.0.
module cosDataPathUnit (
  input         clk,
  input         rst,
  input         cntUp,
  input         init0,
  input         ldX,
  input         ldT,
  input         initT1,   // load term reg with 1.0 initially
  input         initCos1, // load accumulator with 1.0
  input         ldCos,
  input         selPow,   // selects multiplication by x^2 (not used separately here)
  input         addSub,   // alternates add/subtract
  input  [15:0] xBus,
  output        cnt8,
  output [17:0] rBus,
  output        signBit
);
  wire [2:0] cntOut;
  wire [15:0] lutOut, xOut, tOut;
  wire [15:0] xSquared, computedTerm, multOut;
  wire [17:0] cosOut, addSubOut;
  
  cntReg #(3) cntr (
    .clk(clk), .rst(rst), .cntUp(cntUp), .init0(init0), .cnt(cntOut)
  );
  
  cosLUT lut (
    .addr(cntOut), .out(lutOut)
  );
  
  nBitReg #(16) xReg (
    .clk(clk), .rst(rst), .init(1'b0), .load(ldX),
    .in(xBus), .out(xOut)
  );
  
  nBitReg #(16, 16'hFFFF) tReg (
    .clk(clk), .rst(rst), .init(initT1), .load(ldT),
    .in(multOut), .out(tOut)
  );
  
  // 18-bit accumulator for cos; now use initCos1 to load 1.0.
  nBitReg #(18, 18'h0FFFF) cosReg (
    .clk(clk), .rst(rst), .init(initCos1), .load(ldCos),
    .in(addSubOut), .out(cosOut)
  );
  
  assign xSquared = (xOut * xOut) >> 16;
  // For cnt==0, use 1.0; otherwise, update term using xSquared.
  assign computedTerm = (cntOut == 3'd0) ? 16'hFFFF : ((tOut * xSquared) >> 16);
  assign multOut = (computedTerm * lutOut) >> 16;
  assign addSubOut = (addSub) ? (cosOut - {2'b00, tOut})
                             : (cosOut + {2'b00, tOut});
  
  assign rBus = cosOut;
  assign cnt8 = (cntOut == 3'd7);
  assign signBit = cntOut[0];
endmodule

// cosControlUnit: Revised FSM for cos(x)
module cosControlUnit (
  input  clk,
  input  rst,
  input  start,
  input  cnt8,
  input  signBit,
  output reg ldX,
  output reg initT1,
  output reg initCos1,  // new signal to initialize cos accumulator
  output reg init0,
  output reg ldT,
  output reg ldCos,
  output reg selPow,
  output reg addSub,
  output reg cntUp,
  output reg done
);
  parameter [2:0]
    IDLE     = 3'd0,
    INIT     = 3'd1,
    ITERATE1 = 3'd2,
    ITERATE2 = 3'd3,
    ACCUM    = 3'd4,
    DONE     = 3'd5;
    
  reg [2:0] state, next;
  always @(posedge clk or posedge rst)
    if (rst) state <= IDLE; else state <= next;
    
  always @(*) begin
    next = state;
    ldX     = 0;
    initT1  = 0;
    initCos1 = 0;
    init0   = 0;
    ldT     = 0;
    ldCos   = 0;
    selPow  = 0;
    addSub  = 0;
    cntUp   = 0;
    done    = 0;
    case (state)
      IDLE: begin
         done = 1;
         if (start)
           next = INIT;
      end
      INIT: begin
         initT1  = 1;
         initCos1 = 1; // initialize accumulator to 1.0
         init0   = 1;
         ldX     = 1;
         next    = ITERATE1;
      end
      ITERATE1: begin
         selPow = 1;
         ldT    = 1;
         next   = ITERATE2;
      end
      ITERATE2: begin
         ldT    = 1;
         next   = ACCUM;
      end
      ACCUM: begin
         ldCos = 1;
         cntUp = 1;
         addSub = signBit;
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

// cosTop: Top-level module for cos(x)
module cosTop (
  input         clk,
  input         rst,
  input         start,
  input  [15:0] xBus,
  output [17:0] rBus,
  output        done
);
  wire ldX, initT1, initCos1, init0, ldT, ldCos, selPow, addSub, cntUp, cnt8, signBit;
  
  cosControlUnit cosControl (
    .clk(clk), .rst(rst), .start(start), .cnt8(cnt8), .signBit(signBit),
    .ldX(ldX), .initT1(initT1), .initCos1(initCos1), .init0(init0),
    .ldT(ldT), .ldCos(ldCos), .selPow(selPow), .addSub(addSub),
    .cntUp(cntUp), .done(done)
  );
  
  cosDataPathUnit cosDataPath (
    .clk(clk), .rst(rst), .cntUp(cntUp), .init0(init0),
    .ldX(ldX), .ldT(ldT), .initT1(initT1),
    .ldCos(ldCos), .selPow(selPow), .addSub(addSub),
    .xBus(xBus), .cnt8(cnt8), .rBus(rBus),
    .signBit(signBit)
  );
endmodule

// =============================================================================
// -------------------------- LN(x+1) MODULES ---------------------------------
// =============================================================================

// lnLUT: For ln(1+x)= x - x^2/2 + x^3/3 - x^4/4 + …
// Index 0 returns 1.0 so that the first term is x.
module lnLUT (
  input  [2:0] addr,
  output [15:0] out
);
  reg [15:0] dataOut;
  always @(*) begin
    case(addr)
      3'd0: dataOut = 16'hFFFF; // 1.0
      3'd1: dataOut = 16'h8000; // 1/2
      3'd2: dataOut = 16'h5555; // 1/3
      3'd3: dataOut = 16'h4000; // 1/4
      3'd4: dataOut = 16'h3333; // 1/5
      3'd5: dataOut = 16'h2AAA; // 1/6
      3'd6: dataOut = 16'h2492; // 1/7
      3'd7: dataOut = 16'h2000; // 1/8
      default: dataOut = 16'h0000;
    endcase
  end
  assign out = dataOut;
endmodule

// lnDataPathUnit: Computes ln(1+x)= x - x^2/2 + x^3/3 - …
// The accumulator is 18-bit; for cnt==0 we load x.
module lnDataPathUnit (
  input         clk,
  input         rst,
  input         cntUp,
  input         init0,
  input         ldX,
  input         ldTerm,
  input         initTerm,  // load term register with x initially
  input         ldSum,
  input         selSign,   // 0: add, 1: subtract
  input  [15:0] xBus,
  output        cnt8,
  output [17:0] lnOut,
  output        signBit
);
  wire [2:0] cntOut;
  wire [15:0] lutOut;
  wire [15:0] xOut, termOut;
  wire [15:0] product, newTerm;
  wire [17:0] sumCalc;
  
  cntReg #(3) cntr (
    .clk(clk), .rst(rst), .cntUp(cntUp), .init0(init0), .cnt(cntOut)
  );
  
  lnLUT lut (
    .addr(cntOut), .out(lutOut)
  );
  
  nBitReg #(16) xReg (
    .clk(clk), .rst(rst), .init(1'b0), .load(ldX),
    .in(xBus), .out(xOut)
  );
  
  nBitReg #(16, 16'h0000) termReg (
    .clk(clk), .rst(rst), .init(initTerm), .load(ldTerm),
    .in(newTerm), .out(termOut)
  );
  
  // 18-bit accumulator for ln
  nBitReg #(18, 18'h0000) sumReg (
    .clk(clk), .rst(rst), .init(1'b0), .load(ldSum),
    .in(sumCalc), .out(lnOut)
  );
  
  // newTerm = (term*x*LUT) >> 16.
  assign product = (termOut * xOut) >> 16;
  assign newTerm = (product * lutOut) >> 16;
  
  // If cnt==0, load accumulator with x; otherwise add/subtract newTerm.
  assign sumCalc = (cntOut == 3'd0) ? {2'b00, xOut} :
                   (selSign ? (lnOut - {2'b00, newTerm})
                            : (lnOut + {2'b00, newTerm}));
  
  assign signBit = cntOut[0];
  assign cnt8 = (cntOut == 3'd7);
endmodule

// lnControlUnit: Revised FSM for ln(1+x)
module lnControlUnit (
  input         clk,
  input         rst,
  input         start,
  input         cnt8,
  input         signBit,
  output reg    ldX,
  output reg    initTerm,  // load term register with x
  output reg    ldTerm,
  output reg    ldSum,
  output reg    selSign,
  output reg    cntUp,
  output reg    init0,
  output reg    done
);
  parameter [2:0]
    IDLE     = 3'd0,
    INIT     = 3'd1,
    ITERATE1 = 3'd2,
    ITERATE2 = 3'd3,
    ACCUM    = 3'd4,
    DONE     = 3'd5;
    
  reg [2:0] state, next;
  always @(posedge clk or posedge rst)
    if (rst) state <= IDLE; else state <= next;
    
  always @(*) begin
    next = state;
    ldX      = 0;
    initTerm = 0;
    ldTerm   = 0;
    ldSum    = 0;
    selSign  = 0;
    cntUp    = 0;
    init0    = 0;
    done     = 0;
    case (state)
      IDLE: begin
         done = 1;
         if (start)
           next = INIT;
      end
      INIT: begin
         initTerm = 1;
         init0    = 1;
         ldX      = 1;
         next = ITERATE1;
      end
      ITERATE1: begin
         ldTerm = 1;
         next = ITERATE2;
      end
      ITERATE2: begin
         next = ACCUM;
      end
      ACCUM: begin
         ldSum   = 1;
         cntUp   = 1;
         selSign = signBit;
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

// lnTop: Top-level module for ln(1+x)
module lnTop (
  input         clk,
  input         rst,
  input         start,
  input  [15:0] xBus,
  output [17:0] lnOut,
  output        done
);
  wire ldX, initTerm, ldTerm, ldSum, selSign, cntUp, init0, cnt8, signBit;
  
  lnControlUnit lnControl (
    .clk(clk), .rst(rst), .start(start), .cnt8(cnt8), .signBit(signBit),
    .ldX(ldX), .initTerm(initTerm), .ldTerm(ldTerm),
    .ldSum(ldSum), .selSign(selSign), .cntUp(cntUp), .init0(init0),
    .done(done)
  );
  
  lnDataPathUnit lnDataPath (
    .clk(clk), .rst(rst), .cntUp(cntUp), .init0(init0),
    .ldX(ldX), .ldTerm(ldTerm), .initTerm(initTerm),
    .ldSum(ldSum), .selSign(selSign), .xBus(xBus),
    .cnt8(cnt8), .lnOut(lnOut), .signBit(signBit)
  );
endmodule

// =============================================================================
// ------------------------ TOP–TOP MODULE ------------------------------------
// =============================================================================

module maclaurinSeriesCalculator (
  input         clk,
  input         rst,
  input         start,
  input  [15:0] xBus,
  input  [1:0]  func,   // 00: exp, 01: sin, 10: cos, 11: ln(x+1)
  output        Done,
  output [17:0] rBus
);
  wire expDone, sinDone, cosDone, lnDone;
  wire [17:0] expRBus, sinRBus, cosRBus, lnRBus;
  
  // Gated start signals for each function.
  wire startExp = start & (func == 2'b00);
  wire startSin = start & (func == 2'b01);
  wire startCos = start & (func == 2'b10);
  wire startLn  = start & (func == 2'b11);
  
  expTop expInst (
    .clk(clk), .rst(rst), .start(startExp),
    .xBus(xBus), .rBus(expRBus), .done(expDone)
  );
  
  sinTop sinInst (
    .clk(clk), .rst(rst), .start(startSin),
    .xBus(xBus), .rBus(sinRBus), .done(sinDone)
  );
  
  cosTop cosInst (
    .clk(clk), .rst(rst), .start(startCos),
    .xBus(xBus), .rBus(cosRBus), .done(cosDone)
  );
  
  lnTop lnInst (
    .clk(clk), .rst(rst), .start(startLn),
    .xBus(xBus), .lnOut(lnRBus), .done(lnDone)
  );
  
  assign Done = (func == 2'b00) ? expDone :
                (func == 2'b01) ? sinDone :
                (func == 2'b10) ? cosDone : lnDone;
                
  assign rBus = (func == 2'b00) ? expRBus :
                (func == 2'b01) ? sinRBus :
                (func == 2'b10) ? cosRBus : lnRBus;
endmodule
