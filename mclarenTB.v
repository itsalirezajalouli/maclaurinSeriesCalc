`timescale 1ns/1ns

module maclaurinSeriesCalcTB ();
  reg clk = 0;
  reg rst = 0;
  reg start = 0;
  reg [15:0] xBus;
  reg [1:0] func;
  wire done;
  wire [17:0] rBus;

  maclaurinSeriesCalc dut(clk, rst, start, xBus, func, rBus, done);

  // generating clock behaviour
  always #5 clk <= ~clk;
  initial begin
    // Dump waveform data to a file.
    $dumpfile("maclaurin_sim.vcd");
    $dumpvars(0, maclaurinSeriesCalcTB);

    // Test for different function selections with various x values
    
    // exp(x) for x = 0
    #5; rst = 1;
    #5; rst = 0; xBus = 16'h0000; func = 2'b00; start = 1;
    #5; start = 0;
    #300;
    
    // sin(x) for x = 0.125
    #5; rst = 1;
    #5; rst = 0; xBus = 16'h2000; func = 2'b01; start = 1;
    #5; start = 0;
    #300;
    
    // cos(x) for x = 0.25
    #5; rst = 1;
    #5; rst = 0; xBus = 16'h4000; func = 2'b10; start = 1;
    #5; start = 0;
    #300;
    
    // ln(x+1) for x = 0.5
    #5; rst = 1;
    #5; rst = 0; xBus = 16'h8000; func = 2'b11; start = 1;
    #5; start = 0;
    #300;

    // exp(x) for x = 1
    #5; rst = 1;
    #5; rst = 0; xBus = 16'hFFFF; func = 2'b00; start = 1;
    #5; start = 0;
    #300;

    $finish; 
  end

endmodule
