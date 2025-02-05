`timescale 1ns/1ps

module cosTop_tb;
  reg clk, rst, start;
  reg [15:0] xBus;
  wire [17:0] rBus;
  wire done;

  cosTop dut (
    .clk(clk),
    .rst(rst),
    .start(start),
    .xBus(xBus),
    .rBus(rBus),
    .done(done)
  );

  // Clock generation: 10ns period
  always #5 clk = ~clk;

  initial begin
    clk   = 0;
    rst   = 1;
    start = 0;
    xBus  = 16'h1000; // Example input (0.0625 in fixed-point)

    // Dump waveform data to a file
    $dumpfile("cos_test.vcd"); // Specify the output file
    $dumpvars(0, cosTop_tb);   // Dump all variables in the testbench

    #10 rst = 0;      // Release reset
    #10 start = 1;    // Start the computation
    #10 start = 0;    // Deassert start

    wait(done);      // Wait for the computation to finish
    $display("cos(0.625) = 0x%h", rBus);

    #20 $finish;
  end
endmodule
