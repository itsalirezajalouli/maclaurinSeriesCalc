// Cos Module

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

// cos(x) = 1 - x^2/2! + x^4/4! - x^6/6! + ...
module cosLUT (
  input  [2:0] addr,
  output [15:0] out
);
  reg [15:0] dataOut;
  always @(*) begin
    case(addr)
      3'd0: dataOut = 16'hFFFF; // 1.0000000000 (1/1!)
      3'd1: dataOut = 16'h8000; // 0.5000000000 (1/2!)
      3'd2: dataOut = 16'h2AAB; // 0.0416666667 (1/4!)
      3'd3: dataOut = 16'h0811; // 0.0013888889 (1/6!)
      3'd4: dataOut = 16'h0028; // 0.0000198413 (1/8!)
      3'd5: dataOut = 16'h0001; // 0.0000002480 (1/10!)
      3'd6: dataOut = 16'h0000; // ~zero (1/12!)
      3'd7: dataOut = 16'h0000; // ~zero (1/14!)
      default: dataOut = 16'h0000;
    endcase
  end
  assign out = dataOut;
endmodule

module cosDataPathUnit (
    input         clk,
    input         rst,
    input         cntUp,
    input         init0,
    input         ldX,
    input         ldT,
    input         initT1,
    input         initCos1,
    input         ldCos,
    input         selXorI,
    input         sub,
    input  [15:0] xBus,
    output        cnt8,
    output [17:0] rBus
);
    wire [2:0] cntOut;
    wire [17:0] cosOut;
    wire [15:0] lutOut, xOut, tOut, muxOut;
    wire [31:0] multResult;
    wire [15:0] multOut;

    cntReg #(3) cntr (.clk(clk), .rst(rst), .cntUp(cntUp), .init0(init0), .cnt(cntOut));
    cosLUT lut (.addr(cntOut), .out(lutOut));
    nBitReg #(16) xReg (.clk(clk), .rst(rst), .init(1'b0), .load(ldX), .in(xBus), .out(xOut));
    nBitReg #(16, 16'hFFFF) tReg (.clk(clk), .rst(rst), .init(initT1), .load(ldT), .in(multOut), .out(tOut));
    nBitReg #(18, 18'h10000) cosReg (.clk(clk), .rst(rst), .init(initCos1), .load(ldCos), .in(addOut), .out(cosOut));

    assign muxOut = (selXorI) ? xOut : lutOut;
    assign multResult = tOut * muxOut;
    assign multOut = multResult[31:16];

    wire signed [17:0] termExtended = sub ? -{{2{tOut[15]}}, tOut} : {{2{tOut[15]}}, tOut};
    wire signed [17:0] sCosOut = cosOut;  // treat cosOut as signed
    wire signed [18:0] fullAdd = { sCosOut[17], sCosOut } + { termExtended[17], termExtended };
    wire signed [17:0] addOut =
        (fullAdd < 0) ? 18'd0 :
        (fullAdd > 18'd131071) ? 18'd131071 :
        fullAdd[17:0];

    assign cnt8 = (cntOut == 3'd7);
    assign rBus = cosOut;
endmodule

module cosControlUnit (
  input  clk,
  input  rst,
  input  start,
  input  cnt8,
  output reg ldX,
  output reg initT1,
  output reg initCos1,  
  output reg init0,
  output reg ldT,
  output reg ldCos,
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
    COS      = 3'd4,
    DONE     = 3'd5;
    
  reg [2:0] state, next;
  // sign register: 1 means subtract the term, 0 means add.
  reg sign;

  // State register
  always @(posedge clk or posedge rst)
    if (rst) begin
      state <= IDLE;
      sign  <= 1'b1;  // First term after 1 will be subtracted.
    end else begin
      state <= next;
      if(state == COS)
        sign <= ~sign;
    end

  // Next-state and output logic
  always @(*) begin
    next     = state;
    ldX      = 0;
    initT1   = 0;
    initCos1 = 0;
    init0    = 0;
    ldT      = 0;
    ldCos    = 0;
    selXorI  = 0;
    cntUp    = 0;
    done     = 0;
    sub      = 0;
    
    case (state)
      IDLE: begin
        if(start)
          next = INIT;
        else
          next = IDLE;
      end
      INIT: begin
        initT1   = 1;  // load term register with 1.0
        initCos1 = 1;  // load cos accumulator with 1.0
        init0    = 1;  // reset counter
        ldX      = 1;  // load x register
        next     = ITERATE1;
      end
      ITERATE1: begin
        // Multiply previous term by x^2.
        selXorI = 1;  // select x (assumed to be pre-squared)
        ldT     = 1;
        next    = ITERATE2;
      end
      ITERATE2: begin
        // Multiply by LUT coefficient (1/factorial) to adjust magnitude.
        selXorI = 0;  // select LUT output
        ldT     = 1;
        next    = COS;
      end
      COS: begin
        ldCos   = 1;
        cntUp   = 1;
        sub     = sign;  // use current sign flag to decide add/subtract
        if(cnt8)
          next = DONE;
        else
          next = ITERATE1;
      end
      DONE: begin
        done = 1;
        if(~start)
          next = IDLE;
        else
          next = DONE;
      end
      default: next = IDLE;
    endcase
  end
endmodule

module cosTop (
  input         clk,
  input         rst,
  input         start,
  input  [15:0] xBus,
  output [17:0] rBus,
  output        done
);
  wire ldX, initT1, initCos1, init0, ldT, ldCos, selXorI, cntUp, cnt8, sub;

  cosControlUnit cosControl (
    .clk(clk), .rst(rst), .start(start), .cnt8(cnt8),
    .ldX(ldX), .initT1(initT1), .initCos1(initCos1), .init0(init0),
    .ldT(ldT), .ldCos(ldCos), .selXorI(selXorI),
    .cntUp(cntUp), .done(done), .sub(sub)
  );

  cosDataPathUnit cosDataPath (
    .clk(clk), .rst(rst), .cntUp(cntUp), .init0(init0),
    .ldX(ldX), .ldT(ldT), .initT1(initT1), .initCos1(initCos1),
    .ldCos(ldCos), .selXorI(selXorI), .sub(sub), .xBus(xBus),
    .cnt8(cnt8), .rBus(rBus)
  );
endmodule

