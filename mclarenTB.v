`timescale 1ns/1ps

module tb_funcSelector();

  // Declare testbench signals
  reg         clk;
  reg         rst;
  reg         start;
  reg  [15:0] xBus;
  reg  [1:0]  func;
  wire [17:0] rBus;
  wire        done;

  // Instantiate the top-level module (Unit Under Test)
  funcSelector uut (
      .clk(clk),
      .rst(rst),
      .start(start),
      .xBus(xBus),
      .func(func),
      .rBus(rBus),
      .done(done)
  );

  // Clock generation: 10ns period
  initial begin
    clk = 0;
    forever #5 clk = ~clk;
  end

  // Test stimulus
  initial begin
    // Initialize all signals
    rst   = 1;
    start = 0;
    xBus  = 16'h0000;
    func  = 2'b00;
    #15;
    rst   = 0;
    #10;

    // Test the exponential function (func = 0)
    func  = 2'b00;
    xBus  = 16'h0001; // example input value
    start = 1;
    #10;
    start = 0;
    wait(done); // wait until the module asserts done
    #20;
    
    // Test the sine function (func = 1)
    func  = 2'b01;
    xBus  = 16'h0002;
    start = 1;
    #10;
    start = 0;
    wait(done);
    #20;
    
    // Test the cosine function (func = 2)
    func  = 2'b10;
    xBus  = 16'h0003;
    start = 1;
    #10;
    start = 0;
    wait(done);
    #20;
    
    // Test the natural logarithm function (func = 3)
    func  = 2'b11;
    xBus  = 16'h0004;
    start = 1;
    #10;
    start = 0;
    wait(done);
    #20;
    
    $finish;
  end

  // Optional: Monitor signals
  initial begin
    $monitor("Time=%0t | rst=%b | start=%b | func=%b | xBus=%h | rBus=%h | done=%b",
              $time, rst, start, func, xBus, rBus, done);
  end

endmodule
