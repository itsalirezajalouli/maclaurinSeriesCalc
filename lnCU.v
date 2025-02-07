// controller unit module for ln (state machine)
module lnCU (input clk, rst, start, cnt8,
  output reg done, ldX, initT1, initLN1, ldT, ldLN, init0, cntUp, selXR);

  // states
  reg [2:0] pstate, nstate;
  parameter IDLE = 0, STARTING = 1, GETINPUT = 2, GETINPUT2 = 3, MULT1 = 4, MULT2 = 5, ADD = 6;

  // registers
  always @(posedge clk, posedge rst) begin
    if (rst == 1)
      pstate <= IDLE;
    else
      pstate <= nstate;
  end

  // combinational part
  always @(pstate, start, cnt8) begin
    nstate = IDLE; // default
    done = 0;
    {ldX, initT1, initLN1, ldT, ldLN, init0, cntUp, selXR} = 8'b0;
    // 1. State: IDLE
    if (pstate == IDLE) begin nstate = (start == 1) ? STARTING : IDLE;
      done = 1;
    end
    // 2. State: STARTING
    if (pstate == STARTING) begin 
      nstate = (start == 0) ? GETINPUT: STARTING;
    end
    // 3. State: GETINPUT
    if (pstate == GETINPUT) begin 
      nstate = GETINPUT2;
      ldX = 1; // new extra state for delay
    end
    // 4. State: GETINPUT2
    if (pstate == GETINPUT2) begin 
      nstate = MULT1;
      initT1 = 1; initLN1 = 1; init0 = 1; // ln = xin, term = 1
    end
    // 5. State: MULT1
    if (pstate == MULT1) begin 
      nstate = MULT2;
      selXR = 1; ldT = 1;
    end
    // 6. State: MULT2
    if (pstate == MULT2) begin 
      nstate = ADD;
      ldT = 1;
    end
    // 7. State: ADD 
    if (pstate == ADD) begin 
      nstate = (cnt8 == 1)? IDLE : MULT1;
      ldLN = 1; cntUp = 1;
    end
  end

endmodule
