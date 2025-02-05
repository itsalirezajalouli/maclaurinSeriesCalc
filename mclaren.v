
`timescale 1ns/1ps

module funcSelector (
    input         clk,
    input         rst,
    input         start,
    input  [15:0] xBus,
    input  [1:0]  func,   // 0: exp, 1: sin, 2: cos, 3: ln
    output [17:0] rBus,
    output        done
);

    // Internal wires for each module's outputs
    wire [17:0] rExp, rSin, rCos, rLn;
    wire        doneExp, doneSin, doneCos, doneLn;

    // Generate gated start signals: only the selected module sees a high start.
    wire startExp = start & (func == 2'b00);
    wire startSin = start & (func == 2'b01);
    wire startCos = start & (func == 2'b10);
    wire startLn  = start & (func == 2'b11);

    // Instantiate the exponential module
    expTop exp_inst (
        .clk   (clk),
        .rst   (rst),
        .start (startExp),
        .xBus  (xBus),
        .rBus  (rExp),
        .done  (doneExp)
    );

    // Instantiate the sine module
    sineTop sin_inst (
        .clk   (clk),
        .rst   (rst),
        .start (startSin),
        .xBus  (xBus),
        .rBus  (rSin),
        .done  (doneSin)
    );

    // Instantiate the cosine module
    cosTop cos_inst (
        .clk   (clk),
        .rst   (rst),
        .start (startCos),
        .xBus  (xBus),
        .rBus  (rCos),
        .done  (doneCos)
    );

    // Instantiate the natural logarithm module
    lnTop ln_inst (
        .clk   (clk),
        .rst   (rst),
        .start (startLn),
        .xBus  (xBus),
        .rBus  (rLn),
        .done  (doneLn)
    );

    // Multiplexer for rBus: select the output from the active function module
    assign rBus = (func == 2'b00) ? rExp :
                  (func == 2'b01) ? rSin :
                  (func == 2'b10) ? rCos :
                                    rLn;  // when func==2'b11

    // Multiplexer for done signal: select the done flag from the active module
    assign done = (func == 2'b00) ? doneExp :
                  (func == 2'b01) ? doneSin :
                  (func == 2'b10) ? doneCos :
                                    doneLn;  // when func==2'b11

endmodule
