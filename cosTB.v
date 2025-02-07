// test bech for cos module
`timescale 1ns/1ns

module cosTB ();
  reg clk = 0;
  reg rst = 0;
  reg start = 0;
  reg [15:0] xBus;
  wire done;
  wire [17:0] rBus;

  cosTop cos(clk, rst, start, xBus, rBus, done);

  // generating clock behaviour
  always #5 clk <= ~clk;
  initial begin
    // Dump waveform data to a file.
    $dumpfile("cos_sim.vcd");
    $dumpvars(0, cosTB);

    // x = 0 rad => cos(x) = 1.0 rad
    #5;
    rst = 1;

    #5;
    #5;
    rst = 0;
    xBus = 0;
    start = 1;

    #5;
    #5;
    start = 0;

    #300;

    // x = 0.125 rad => cos(x) = 0.992197 rad
    #5;
    rst = 1;

    #5;
    #5;
    rst = 0;
    xBus = 16'h2000; // 0.125
    start = 1;

    #5;
    #5;
    start = 0;

    #300;

    // x = 0.25 rad => cos(x) = 0.96891 rad
    #5;
    rst = 1;

    #5;
    #5;
    rst = 0;
    xBus = 16'h4000; // 0.25
    start = 1;

    #5;
    #5;
    start = 0;

    #300;
    // x = 0.5 rad => cos(x) = 0.877582 rad
    #5;
    rst = 1;

    #5;
    #5;
    rst = 0;
    xBus = 16'h8000; // 0.5
    start = 1;

    #5;
    #5;
    start = 0;

    #300;
    // x = 1 rad => cos(x) = 0.54030 rad
    #5;
    rst = 1;

    #5;
    #5;
    rst = 0;
    xBus = 16'hFFFF; // 1 
    start = 1;

    #5;
    #5;
    start = 0;

    #300;

    // x = 1.5 rad => cos(x) ≈ 0.07074
    #5; rst = 1;
    #5; #5; rst = 0; xBus = 16'h18000; start = 1;
    #5; #5; start = 0;
    #300;

    // x = 2 rad => cos(x) ≈ -0.41615
    #5; rst = 1;
    #5; #5; rst = 0; xBus = 16'h20000; start = 1;
    #5; #5; start = 0;
    #300;

    // x = 2.5 rad => cos(x) ≈ -0.80114
    #5; rst = 1;
    #5; #5; rst = 0; xBus = 16'h28000; start = 1;
    #5; #5; start = 0;
    #300;

    // x = 3 rad => cos(x) ≈ -0.98999
    #5; rst = 1;
    #5; #5; rst = 0; xBus = 16'h30000; start = 1;
    #5; #5; start = 0;
    #300;

    // x = 3.5 rad => cos(x) ≈ -0.93646
    #5; rst = 1;
    #5; #5; rst = 0; xBus = 16'h38000; start = 1;
    #5; #5; start = 0;
    #300;

    $finish; 
  end

endmodule
