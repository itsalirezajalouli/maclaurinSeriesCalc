// Ln (x+1) Module

`timescale 1ns/1ps

// nBitReg: n–bit register with parameterized initial value
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

// cntReg: m–bit counter (used to count iterations)
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

// lnLUT: ln(x + 1)= x - x^2/2 + x^3/3 ...
module lnLUT (
    input  [2:0] addr,
    output [15:0] out
);
    reg [15:0] dataOut;
    always @(*) begin
      case(addr)
        3'd0: dataOut = 16'h0000; // Not used
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

module lnDataPathUnit (
    input         clk,
    input         rst,
    input         cntUp,
    input         init0,
    input         ldX,
    input         ldT,
    input         initT1,
    input         initLn0,
    input         ldLn,
    input         selXorI,
    input  [15:0] xBus,
    output        cnt8,
    output [17:0] rBus
);
    wire [2:0] cntOut;
    wire [17:0] lnOut, addOut;
    wire [15:0] lutOut, xOut, tOut, muxOut;
    wire [31:0] multResult;  
    wire [15:0] multOut;
    wire        signToggle;
    
    // Counter
    cntReg #(3) cntr (
        .clk(clk), .rst(rst), .cntUp(cntUp), .init0(init0), .cnt(cntOut)
    );
    
    // LUT instantiation for series term denominators
    lnLUT lut (
        .addr(cntOut), .out(lutOut)
    );
    
    // x register
    nBitReg #(16) xReg (
        .clk(clk), .rst(rst), .init(1'b0), .load(ldX),
        .in(xBus), .out(xOut)
    );
    
    // Term register (16-bit) initialized to x
    nBitReg #(16) tReg (
        .clk(clk), .rst(rst), .init(initT1), .load(ldT),
        .in(multOut), .out(tOut)
    );
    
    // Initialize with 0.0 not 1.0
    nBitReg #(18, 18'h00000) lnReg (
        .clk(clk), .rst(rst), .init(initLn0), .load(ldLn),
        .in(addOut), .out(lnOut)
    );
    
    // To check if it's odd
    assign signToggle = (cntOut[0] == 1'b1);
    
    // Multiplexer to select between x or lut
    assign muxOut = (selXorI) ? xOut : lutOut;
    
    // Full precision multiplication
    assign muxOut = (selXorI) ? xOut : lutOut;
    assign multResult = tOut * muxOut;
    assign multOut = multResult[31:16];  // Take top 16 bits
    
    // Adder with sign alternation
    wire [18:0] fullAdd = signToggle ? 
        {1'b0, lnOut} - {3'b000, tOut} : 
        {1'b0, lnOut} + {3'b000, tOut};
    
    // Saturation 
    assign addOut = fullAdd[18] ? 18'h3FFFF : fullAdd[17:0];
    
    assign cnt8 = (cntOut == 3'd7);
    assign rBus = lnOut;
endmodule

// lnControlUnit: Revised FSM for exp(x)
// States: IDLE, INIT, ITERATE1(mult1), ITERATE2(mult2), LN, DONE.
module expControlUnit (
  input clk,
  input rst,
  input start,
  input cnt8,
  output reg ldX,
  output reg initT1,
  output reg initExp1,  
  output reg init0,
  output reg ldT,
  output reg ldLN,
  output reg selXorI,
  output reg cntUp,
  output reg done
);
  parameter [2:0]
    IDLE      = 3'd0,
    INIT      = 3'd1,
    ITERATE1  = 3'd2,
    ITERATE2  = 3'd3,
    LN = 3'd4,
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
    ldLN= 0;
    selXorI  = 0;
    cntUp    = 0;
    done     = 0;  // <--- default done = 0

    case (state)
      IDLE: begin
         if (start)
           next = INIT;
         else
           next = IDLE;
      end
      INIT: begin
         // Initialize: load term = 1.0, exp = 1.0, reset counter, load x.
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
         // Multiply by LUT (divide by factorial).
         selXorI = 0;  // select LUT 
         ldT     = 1;
         next    = LN;
      end
      LN: begin
         // Add computed term to exp and increment counter.
         ldLN = 1;
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
         else
           next = DONE;
      end
      default: next = IDLE;
    endcase
  end
endmodule

// top module
module lnTop (
    input         clk,
    input         rst,
    input         start,
    input  [15:0] xBus,
    output [17:0] rBus,
    output        done
);
    wire cnt8, ldX, initT1, initLn0, ldT, ldLn, selXorI, cntUp, init0;
    
    // Datapath Unit
    lnDataPathUnit datapath (
        .clk(clk),
        .rst(rst),
        .cntUp(cntUp),
        .init0(init0),
        .ldX(ldX),
        .ldT(ldT),
        .initT1(initT1),
        .initLn0(initLn0),
        .ldLn(ldLn),
        .selXorI(selXorI),
        .xBus(x_in),
        .cnt8(cnt8),
        .rBus(ln_result)
    );
    
    // Control Unit
    expControlUnit controller (
        .clk(clk),
        .rst(rst),
        .start(start),
        .cnt8(cnt8),
        .ldX(ldX),
        .initT1(initT1),
        .initExp1(initLn0),  // Using initExp1 for initLn0 in this context
        .init0(init0),
        .ldT(ldT),
        .ldLN(ldLn),
        .selXorI(selXorI),
        .cntUp(cntUp),
        .done(done)
    );
endmodule

