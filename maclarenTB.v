
`timescale 1ns/1ps

module testbench;

  // Declare testbench signals
  reg         clk;
  reg         rst;
  reg         start;
  reg  [15:0] xBus;
  reg  [1:0]  func;  // 00: exp, 01: sin, 10: cos, 11: ln(x+1)
  wire        done;
  wire [17:0] rBus;

  // Instantiate the top–top module
  maclaurinSeriesCalculator msc (
    .clk(clk),
    .rst(rst),
    .start(start),
    .xBus(xBus),
    .func(func),
    .Done(done),
    .rBus(rBus)
  );

  // Clock generation: 10ns period (100MHz clock)
  initial begin
    $dumpfile("simulation.vcd");
    $dumpvars(0, testbench);
    
    rst   = 1;
    start = 0;
    xBus  = 16'h4000;  // approximately 0.25 in Q0.16
    func  = 2'b00;     // start with exponential calculation

    #20;
    rst = 0;
    
    // Test exp(x)
    func = 2'b00; // exp(x)
    start = 1;
    #10;          // hold start one clock cycle
    start = 0;
    // Wait long enough for several iterations (try 1000 ns)
    #1000;
    $display("exp(x) result: %h at time %t", rBus, $time);
    #20;
    
    // Test sin(x)
    func = 2'b01; // sin(x)
    start = 1;
    #10;
    start = 0;
    #1000;
    $display("sin(x) result: %h at time %t", rBus, $time);
    #20;
    
    // Test cos(x)
    func = 2'b10; // cos(x)
    start = 1;
    #10;
    start = 0;
    #1000;
    $display("cos(x) result: %h at time %t", rBus, $time);
    #20;
    
    // Test ln(x+1)
    func = 2'b11; // ln(x+1)
    start = 1;
    #10;
    start = 0;
    #1000;
    $display("ln(x+1) result: %h at time %t", rBus, $time);
    #20;
    
    $finish;
  end

endmodule
