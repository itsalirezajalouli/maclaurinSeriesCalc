
`timescale 1ns/1ps

module sineTop_tb;
  reg         clk, rst, start;
  reg  [15:0] xBus;
  wire [17:0] rBus;
  wire        done;

  // Instantiate the sineTop module.
  sineTop dut (
    .clk(clk),
    .rst(rst),
    .start(start),
    .xBus(xBus),
    .rBus(rBus),
    .done(done)
  );

  // Clock generation: 10 ns period.
  always #5 clk = ~clk;

  initial begin
    clk   = 0;
    rst   = 1;
    start = 0;
    xBus  = 16'h1000; // Example input: 0.0625 in fixed–point (4096/65536)

    // Dump waveform data to a file.
    $dumpfile("sin_test.vcd");
    $dumpvars(0, sineTop_tb);

    #10 rst = 0;      // Release reset.
    #10 start = 1;    // Start the computation.
    #10 start = 0;    // Deassert start.

    wait(done);      // Wait for the computation to finish.
    $display("sin(0.0625) = 0x%h", rBus);

    #20 $finish;
  end
endmodule
