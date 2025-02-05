// Exponential Test Bench

`timescale 1ns/1ps

module expTop_tb;
  reg clk, rst, start;
  reg [15:0] xBus;
  wire [17:0] rBus;
  wire done;

  // Instantiate the DUT (Device Under Test)
  expTop dut (
    .clk(clk),
    .rst(rst),
    .start(start),
    .xBus(xBus),
    .rBus(rBus),
    .done(done)
  );

  // Generate clock
  always #5 clk = ~clk; // 10ns period

  initial begin
    // Initialize signals
    clk = 0;
    rst = 1;
    start = 0;
    xBus = 16'h4000; // Example: 0.25 

    // Dump waveform data to a file
    $dumpfile("exp_test.vcd"); // Specify the output file
    $dumpvars(0, expTop_tb);   // Dump all variables in the testbench

    #10 rst = 0; // Release reset
    #10 start = 1; // Start computation
    #10 start = 0; // Deassert start


    // Wait for computation to complete
    wait(done);
    $display("exp(0.25) = 0X%h", rBus);

    #20 $finish;
  end
endmodule

