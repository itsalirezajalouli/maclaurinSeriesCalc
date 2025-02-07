// test bech for exponential module
`timescale 1ns/1ns

module expTB ();
  reg clk = 0;
  reg rst = 0;
  reg start = 0;
  reg [15:0] xBus;
  wire done;
  wire [17:0] rBus;

  expTop exp(clk, rst, start, xBus, rBus, done);

  // generating clock behaviour
  always #5 clk <= ~clk;
  initial begin
    // Dump waveform data to a file.
    $dumpfile("exp_sim.vcd");
    $dumpvars(0, expTB);

    // x = 0 => e^x = 1.0
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

    // x = 0.125 => e^x = 1.1331
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

    // x = 0.25 => e^x = 1.2840
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
    // x = 0.5 => e^x = 1.6487
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
    // x = 1 => e^x = 2.7183
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

    // x = 1.5 => e^1.5 ≈ 4.4817
    #5; rst = 1;
    #5; #5; rst = 0; xBus = 16'h18000; start = 1;
    #5; #5; start = 0;
    #300;

    // x = 2 => e^2 ≈ 7.3891
    #5; rst = 1;
    #5; #5; rst = 0; xBus = 16'h20000; start = 1;
    #5; #5; start = 0;
    #300;

    // x = 2.5 => e^2.5 ≈ 12.1825
    #5; rst = 1;
    #5; #5; rst = 0; xBus = 16'h28000; start = 1;
    #5; #5; start = 0;
    #300;

    // x = 3 => e^3 ≈ 20.0855
    #5; rst = 1;
    #5; #5; rst = 0; xBus = 16'h30000; start = 1;
    #5; #5; start = 0;
    #300;

    // x = 3.5 => e^3.5 ≈ 33.1155
    #5; rst = 1;
    #5; #5; rst = 0; xBus = 16'h38000; start = 1;
    #5; #5; start = 0;
    #300;

    $finish; 
  end

endmodule
