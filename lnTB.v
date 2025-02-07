// test bech for ln module
`timescale 1ns/1ns

module lnTB ();
  reg clk = 0;
  reg rst = 0;
  reg start = 0;
  reg [15:0] xBus;
  wire done;
  wire [17:0] rBus;

  lnTop ln(clk, rst, start, xBus, rBus, done);

  // generating clock behaviour
  always #5 clk <= ~clk;
  initial begin
    // Dump waveform data to a file.
    $dumpfile("ln_sim.vcd");
    $dumpvars(0, lnTB);

    // x = 0 => ln(x + 1) = ln(1.0) = 0.0 
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

    // x = 0.125 => ln(x + 1) = ln(1.125) = 0.117783
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

    // x = 0.25 => ln(x + 1) = ln(1.25) = 0.223143
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
    // x = 0.5 => ln(x + 1) = ln(1.5) = 0.405465
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
    // x = 1 => ln(x + 1) = ln(2) = 0.69314
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

    // x = 1.5 => ln(2.5) ≈ 0.91629
    #5; rst = 1;
    #5; #5; rst = 0; xBus = 16'h18000; start = 1;
    #5; #5; start = 0;
    #300;

    // x = 2 => ln(3) ≈ 1.0986
    #5; rst = 1;
    #5; #5; rst = 0; xBus = 16'h20000; start = 1;
    #5; #5; start = 0;
    #300;

    // x = 2.5 => ln(3.5) ≈ 1.2528
    #5; rst = 1;
    #5; #5; rst = 0; xBus = 16'h28000; start = 1;
    #5; #5; start = 0;
    #300;

    // x = 3 => ln(4) ≈ 1.3863
    #5; rst = 1;
    #5; #5; rst = 0; xBus = 16'h30000; start = 1;
    #5; #5; start = 0;
    #300;

    // x = 3.5 => ln(4.5) ≈ 1.5041
    #5; rst = 1;
    #5; #5; rst = 0; xBus = 16'h38000; start = 1;
    #5; #5; start = 0;
    #300;


    $finish; 
  end

endmodule
