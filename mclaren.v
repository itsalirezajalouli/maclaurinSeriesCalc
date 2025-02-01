// n bit register cause we need both 16 bit and 18 bit register
module nBitReg #(parameter n) (input clk,
                               input rst,
                               input init1,
                               input load,
                               input [n - 1:0]in,                // n-1 -> 16 bit : [15:0]
                               output reg [n - 1:0]out);
  // triggered on rising edge of clk and rst -> async
  always @ (posedge clk or posedge rst) begin
    if (rst == 1)
      out <= 0;
    else begin
      if (init1 == 1)
        out <= 1;
      else:
          if (load == 1)
            out <= in;
    end
  end
endmodule

// count register for the number of iterations
module cntReg #(parameter m) (input clk,
                              input rst,
                              input cntUp,    // cntUp is a flage to increment the counter
                              input init0,
                              output reg [m - 1:0]cnt);

  always @ (posedge clk or posedge rst) begin
    if (rst == 1)
      cnt <= 0;
    else begin
      if (init0 == 1)
        cnt <= 0;
      else 
        if (cntUp == 1)
          cnt <= cnt + 1;
    end
  end
endmodule

// LUT: Look Up Table for making 1/i (just till 1/8 for the maximum accuracy of 8)
module expLUT(input [2:0]addr,
           output [15:0]out);
  reg [15:0]dataOut;
  always @ (addr) begin
    case(addr) 
      0 : dataOut = 16'hFFFF; // returns 1
      1 : dataOut = 16'h8000; // returns 1/2
      2 : dataOut = 16'h5555; // returns 1/3
      3 : dataOut = 16'h4000; // returns 1/4
      4 : dataOut = 16'h3333; // returns 1/5
      5 : dataOut = 16'h2AAA; // returns 1/6
      6 : dataOut = 16'h2492; // returns 1/7
      7 : dataOut = 16'h2000; // returns 1/8
    endcase
  end
  assign out = dataOut;
endmodule

// Data path
module expDataPathUnit(input clk,
                input rst,
                input cntUp,
                input init0,
                input ldX,
                input ldT,
                input initT1,
                input initExp1,
                input ldExp,
                input selXorI,
                input [15:0] xBus,
                output cnt8,
                output [17:0] rBus,
);

  wire [2:0] cntOut; // output of counter register
  wire [17:0] expOut, addOut; // output of aff & exponential
  wire [15:0] lutOut, xOut, tOut, muxOut, multOut;

  // registers and memmory
  cntReg cntr(clk, rst, 1b'0, ldX, init0, cntOut); // set counter to not count up as idle
  expLUT lut(cntOut, lutOut);
  nBitReg #(16) xReg(clk, rst, 1b'0, ldX, xBus, xOut) // 1b'0 -> don't initialize yet
  nBitReg #(16) tReg(clk, rst, initT1, ldT, multOut, tOut) 
  nBitReg #(18) eReg(clk, rst, initExp1, ldExp, addOut, expOut) 

  // outputs
  assign muxOut = (selXorI == 1)? xOut:lutOut;
  assign addOut = expOut + {2b'00, tOut};
  assign multOut = (tOut * muxOut) >> 16; // to clip to 16 bit

endmodule

// Control Unit
module expControlUnit(
    input clk,
    input rst,
    input start,
    input cnt8,
    output reg ldX,
    output reg initT1,
    output reg initExp1,
    output reg init0,
    output reg ldT,
    output reg ldExp,
    output reg selXorI,
    output reg cntUp,
    output reg done
);

    // State encoding
    parameter [2:0] 
        IDLE = 3'b000,
        STARTING = 3'b001,
        GET_INPUTS = 3'b010,
        MULT1 = 3'b011,
        MULT2 = 3'b100,
        MULT3 = 3'b101;

    reg [2:0] current_state, next_state;

    // State register
    always @(posedge clk or posedge rst) begin
        if (rst)
            current_state <= IDLE;
        else
            current_state <= next_state;
    end

    // Next state logic
    always @(*) begin
        case (current_state)
            IDLE: begin
                if (start)
                    next_state = STARTING;
                else
                    next_state = IDLE;
            end
            STARTING: begin
                if (start)
                    next_state = STARTING;
                else
                    next_state = GET_INPUTS;
            end
            GET_INPUTS: begin
                next_state = MULT1;
            end
            MULT1: begin
                next_state = MULT2;
            end
            MULT2: begin
                next_state = MULT3;
            end
            MULT3: begin
                if (cnt8)
                    next_state = IDLE;
                else
                    next_state = MULT1;
            end
            default: next_state = IDLE;
        endcase
    end

    // Output logic
    always @(*) begin
        // Default values
        ldX = 0; initT1 = 0; initExp1 = 0; init0 = 0;
        ldT = 0; ldExp = 0; selXorI = 0; cntUp = 0; done = 0;

        case (current_state)
            IDLE: begin
                done = 1;
            end
            STARTING: begin
                // Initialize registers
                initT1 = 1;
                initExp1 = 1;
                init0 = 1;
            end
            GET_INPUTS: begin
                ldX = 1;
            end
            MULT1: begin
                selXorI = 1;
                ldT = 1;
            end
            MULT2: begin
                selXorI = 0;
                ldT = 1;
            end
            MULT3: begin
                ldExp = 1;
                cntUp = 1;
            end
        endcase
    end

endmodule

// Top module connecting datapath and control unit
module expCalculator(
    input clk,
    input rst,
    input start,
    input [15:0] xBus,
    output [17:0] rBus,
    output done
);

    // Internal signals
    wire ldX, initT1, initExp1, init0, ldT, ldExp, selXorI, cntUp, cnt8;

    // Instantiate control unit
    expControlUnit controller(
        .clk(clk),
        .rst(rst),
        .start(start),
        .cnt8(cnt8),
        .ldX(ldX),
        .initT1(initT1),
        .initExp1(initExp1),
        .init0(init0),
        .ldT(ldT),
        .ldExp(ldExp),
        .selXorI(selXorI),
        .cntUp(cntUp),
        .done(done)
    );

    // Instantiate datapath unit
    expDataPathUnit datapath(
        .clk(clk),
        .rst(rst),
        .cntUp(cntUp),
        .init0(init0),
        .ldX(ldX),
        .ldT(ldT),
        .initT1(initT1),
        .initExp1(initExp1),
        .ldExp(ldExp),
        .selXorI(selXorI),
        .xBus(xBus),
        .cnt8(cnt8),
        .rBus(rBus)
    );

endmodule

// LUT for factorials (3!, 5!, 7!)
module sinLUT(input [2:0]addr,
           output [15:0]out);
  reg [15:0]dataOut;
  always @ (addr) begin
    case(addr) 
      0 : dataOut = 16'h0555; // returns 1/6 (1/3!)
      1 : dataOut = 16'h0111; // returns 1/120 (1/5!)
      2 : dataOut = 16'h0016; // returns 1/5040 (1/7!)
      default : dataOut = 16'h0000;
    endcase
  end
  assign out = dataOut;
endmodule

// Data path for sin(x)
module sinDataPathUnit(
    input clk,
    input rst,
    input cntUp,
    input init0,
    input ldX,
    input ldT,
    input initT1,
    input initSin1,
    input ldSin,
    input selPow,
    input addSub,
    input [15:0] xBus,
    output cnt3,
    output [17:0] rBus
);
    wire [1:0] cntOut;
    wire [17:0] sinOut, addSubOut;
    wire [15:0] lutOut, xOut, tOut, xPowOut, multOut;
    wire [15:0] xSquared;
    
    // registers and memory
    cntReg #(2) cntr(clk, rst, cntUp, init0, cntOut);
    sinLUT lut(cntOut, lutOut);
    nBitReg #(16) xReg(clk, rst, 1'b0, ldX, xBus, xOut);
    nBitReg #(16) tReg(clk, rst, initT1, ldT, multOut, tOut);
    nBitReg #(18) sinReg(clk, rst, initSin1, ldSin, addSubOut, sinOut);
    
    // Computation logic
    assign xSquared = (xOut * xOut) >> 16; // x²
    assign xPowOut = selPow ? ((tOut * xSquared) >> 16) : xOut; // Either x or t*x²
    assign multOut = (xPowOut * lutOut) >> 16;
    assign addSubOut = addSub ? (sinOut - {2'b00, tOut}) : (sinOut + {2'b00, tOut});
    
    // outputs
    assign cnt3 = (cntOut == 2'b11);
    assign rBus = sinOut;
endmodule

// Modified Control Unit for sin(x)
module sinControlUnit(
    input clk,
    input rst,
    input start,
    input cnt3,
    output reg ldX,
    output reg initT1,
    output reg initSin1,
    output reg init0,
    output reg ldT,
    output reg ldSin,
    output reg selPow,
    output reg addSub,
    output reg cntUp,
    output reg done
);
    // State encoding
    parameter [2:0] 
        IDLE = 3'b000,
        STARTING = 3'b001,
        GET_INPUTS = 3'b010,
        CALC_TERM = 3'b011,
        UPDATE_SUM = 3'b100;

    reg [2:0] current_state, next_state;

    // State register
    always @(posedge clk or posedge rst) begin
        if (rst)
            current_state <= IDLE;
        else
            current_state <= next_state;
    end

    // Next state logic
    always@(current_state or start or cnt3) begin
        case (current_state)
            IDLE: begin
                if (start)
                    next_state = STARTING;
                else
                    next_state = IDLE;
            end
            STARTING: begin
                next_state = GET_INPUTS;
            end
            GET_INPUTS: begin
                next_state = CALC_TERM;
            end
            CALC_TERM: begin
                next_state = UPDATE_SUM;
            end
            UPDATE_SUM: begin
                if (cnt3)
                    next_state = IDLE;
                else
                    next_state = CALC_TERM;
            end
            default: next_state = IDLE;
        endcase
    end

    // Output logic
    always@(current_state or start or cnt3) begin
        // Default values
        ldX = 0; initT1 = 0; initSin1 = 0; init0 = 0;
        ldT = 0; ldSin = 0; selPow = 0; addSub = 0; 
        cntUp = 0; done = 0;

        case (current_state)
            IDLE: begin
                done = 1;
            end
            STARTING: begin
                initT1 = 1;
                initSin1 = 1;
                init0 = 1;
            end
            GET_INPUTS: begin
                ldX = 1;
                selPow = 0; // First term uses x directly
            end
            CALC_TERM: begin
                ldT = 1;
                selPow = (cntOut != 0); // Use x for first term, x³, x⁵, x⁷ for others
            end
            UPDATE_SUM: begin
                ldSin = 1;
                addSub = cntOut[0]; // Alternate between adding and subtracting
                cntUp = 1;
            end
        endcase
    end
endmodule

// Top module for sin(x) calculator
module sinCalculator(
    input clk,
    input rst,
    input start,
    input [15:0] xBus,
    output [17:0] rBus,
    output done
);
    wire ldX, initT1, initSin1, init0, ldT, ldSin, selPow, addSub, cntUp, cnt3;

    sinControlUnit controller(
        .clk(clk),
        .rst(rst),
        .start(start),
        .cnt3(cnt3),
        .ldX(ldX),
        .initT1(initT1),
        .initSin1(initSin1),
        .init0(init0),
        .ldT(ldT),
        .ldSin(ldSin),
        .selPow(selPow),
        .addSub(addSub),
        .cntUp(cntUp),
        .done(done)
    );

    sinDataPathUnit datapath(
        .clk(clk),
        .rst(rst),
        .cntUp(cntUp),
        .init0(init0),
        .ldX(ldX),
        .ldT(ldT),
        .initT1(initT1),
        .initSin1(initSin1),
        .ldSin(ldSin),
        .selPow(selPow),
        .addSub(addSub),
        .xBus(xBus),
        .cnt3(cnt3),
        .rBus(rBus)
    );
endmodule

// LUT for factorial (2!, 4!, 6!)
module cosLUT(input [2:0]addr,
           output [15:0]out);
  reg [15:0]dataOut;
  always @ (addr) begin
    case(addr) 
      0 : dataOut = 16'h4000; // returns 1/2 (1/2!)
      1 : dataOut = 16'h0555; // returns 1/24 (1/4!)
      2 : dataOut = 16'h0095; // returns 1/720 (1/6!)
      default : dataOut = 16'h0000;
    endcase
  end
  assign out = dataOut;
endmodule

// Modified Data path for cos(x)
module cosDataPathUnit(
    input clk,
    input rst,
    input cntUp,
    input init0,
    input ldX,
    input ldT,
    input initT1,
    input initCos1,
    input ldCos,
    input selPow,
    input addSub,
    input [15:0] xBus,
    output cnt3,
    output [17:0] rBus
);
    wire [1:0] cntOut;
    wire [17:0] cosOut, addSubOut;
    wire [15:0] lutOut, xOut, tOut, xPowOut, multOut;
    wire [15:0] xSquared;
    
    // Registers and memory
    cntReg #(2) cntr(clk, rst, cntUp, init0, cntOut);
    cosLUT lut(cntOut, lutOut);
    nBitReg #(16) xReg(clk, rst, 1'b0, ldX, xBus, xOut);
    nBitReg #(16) tReg(clk, rst, initT1, ldT, multOut, tOut);
    nBitReg #(18) cosReg(clk, rst, initCos1, ldCos, addSubOut, cosOut);
    
    // Computation logic
    assign xSquared = (xOut * xOut) >> 16; // x²
    assign xPowOut = selPow ? ((tOut * xSquared) >> 16) : 16'h8000; // Either 1 or t*x²
    assign multOut = (xPowOut * lutOut) >> 16;
    assign addSubOut = addSub ? (cosOut - {2'b00, tOut}) : (cosOut + {2'b00, tOut});
    
    // Outputs
    assign cnt3 = (cntOut == 2'b11);
    assign rBus = cosOut;
endmodule

// Control Unit for cos(x)
module cosControlUnit(
    input clk,
    input rst,
    input start,
    input cnt3,
    output reg ldX,
    output reg initT1,
    output reg initCos1,
    output reg init0,
    output reg ldT,
    output reg ldCos,
    output reg selPow,
    output reg addSub,
    output reg cntUp,
    output reg done
);
    // State encoding
    parameter [2:0] 
        IDLE = 3'b000,
        STARTING = 3'b001,
        GET_INPUTS = 3'b010,
        CALC_TERM = 3'b011,
        UPDATE_SUM = 3'b100;

    reg [2:0] current_state, next_state;

    // State register
    always @(posedge clk or posedge rst) begin
        if (rst)
            current_state <= IDLE;
        else
            current_state <= next_state;
    end

    // Next state logic
    always@(current_state or start or cnt3) begin
        case (current_state)
            IDLE: begin
                if (start)
                    next_state = STARTING;
                else
                    next_state = IDLE;
            end
            STARTING: begin
                next_state = GET_INPUTS;
            end
            GET_INPUTS: begin
                next_state = CALC_TERM;
            end
            CALC_TERM: begin
                next_state = UPDATE_SUM;
            end
            UPDATE_SUM: begin
                if (cnt3)
                    next_state = IDLE;
                else
                    next_state = CALC_TERM;
            end
            default: next_state = IDLE;
        endcase
    end

    // Output logic
    // always @(*) begin
    always@(current_state or start or cnt3) begin
        // Default values
        ldX = 0; initT1 = 0; initCos1 = 0; init0 = 0;
        ldT = 0; ldCos = 0; selPow = 0; addSub = 0; 
        cntUp = 0; done = 0;

        case (current_state)
            IDLE: begin
                done = 1;
            end
            STARTING: begin
                initT1 = 1;
                initCos1 = 1;  // Initialize cos to 1
                init0 = 1;
            end
            GET_INPUTS: begin
                ldX = 1;
            end
            CALC_TERM: begin
                ldT = 1;
                selPow = 1;  // Always use x² based terms
            end
            UPDATE_SUM: begin
                ldCos = 1;
                addSub = cntOut[0];  // Alternate between adding and subtracting
                cntUp = 1;
            end
        endcase
    end
endmodule

// Top module for cos(x) calculator
module cosCalculator(
    input clk,
    input rst,
    input start,
    input [15:0] xBus,
    output [17:0] rBus,
    output done
);
    wire ldX, initT1, initCos1, init0, ldT, ldCos, selPow, addSub, cntUp, cnt3;

    cosControlUnit controller(
        .clk(clk),
        .rst(rst),
        .start(start),
        .cnt3(cnt3),
        .ldX(ldX),
        .initT1(initT1),
        .initCos1(initCos1),
        .init0(init0),
        .ldT(ldT),
        .ldCos(ldCos),
        .selPow(selPow),
        .addSub(addSub),
        .cntUp(cntUp),
        .done(done)
    );

    cosDataPathUnit datapath(
        .clk(clk),
        .rst(rst),
        .cntUp(cntUp),
        .init0(init0),
        .ldX(ldX),
        .ldT(ldT),
        .initT1(initT1),
        .initCos1(initCos1),
        .ldCos(ldCos),
        .selPow(selPow),
        .addSub(addSub),
        .xBus(xBus),
        .cnt3(cnt3),
        .rBus(rBus)
    );
endmodule
