`timescale 1ns/1ps

module lnTop_tb;
  reg         clk, rst, start;
  reg  [15:0] xBus;
  wire [17:0] rBus;
  wire        done;

  // Instantiate the DUT (Device Under Test)
  lnTop dut (
    .clk(clk),
    .rst(rst),
    .start(start),
    .xBus(xBus),
    .rBus(rBus),
    .done(done)
  );

  // Generate clock: 10ns period
  always #5 clk = ~clk;

  initial begin
    // Initialize signals
    clk   = 0;
    rst   = 1;
    start = 0;
    // Example: xBus representing 0.25 (so ln(1+0.25) = ln(1.25))
    xBus  = 16'h4000;  

    // Release reset and start computation
    #10 rst   = 0; 
    #10 start = 1; 
    #10 start = 0; 

    // Wait for the computation to complete
    wait(done);
    $display("ln(1+0.25) = 0x%h", rBus);

    #20 $finish;
  end
endmodule
