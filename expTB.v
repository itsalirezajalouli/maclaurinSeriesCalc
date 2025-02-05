`timescale 1ns/1ps

module exp_tb;
    // Test bench signals
    reg clk;
    reg rst;
    reg start;
    reg [15:0] xBus;
    wire [17:0] rBus;
    wire done;

    // Expected values in Q2.16 format
    // exp(0) = 1.0                -> 18'h10000
    // exp(1) = 2.718281828...    -> 18'h2B7E1
    // exp(0.5) = 1.648721271...  -> 18'h1A612
    // exp(-0.5) = 0.606530659... -> 18'h09B63
    // exp(0.25) = 1.284025416... -> 18'h148B1
    // exp(0.75) = 2.117000017... -> 18'h21EB8

    // Instantiate the expTop module
    expTop dut (
        .clk(clk),
        .rst(rst),
        .start(start),
        .xBus(xBus),
        .rBus(rBus),
        .done(done)
    );

    // Clock generation
    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end

    // Function to check if result is within acceptable error margin
    function is_within_margin;
        input [17:0] actual;
        input [17:0] expected;
        input [17:0] margin;
        begin
            is_within_margin = ((actual <= expected + margin) && 
                              (actual >= expected - margin));
        end
    endfunction

    // Test stimulus
    initial begin
        // Add wave monitoring
        $dumpfile("exp_test.vcd");
        $dumpvars(0, exp_tb);

        // Initialize signals
        rst = 1;
        start = 0;
        xBus = 16'h0000;
        #20;
        rst = 0;
        #10;

        // Test Case 1: exp(0) should be 1.0
        $display("\nTest Case 1: exp(0)");
        xBus = 16'h0000;
        start = 1;
        @(posedge done);
        #10 start = 0;
        $display("Input x = 0.0");
        $display("Expected: 18'h10000 (1.0)");
        $display("Got:      18'h%h", rBus);
        $display("Status:   %s", is_within_margin(rBus, 18'h10000, 18'h0100) ? "PASS" : "FAIL");

        #50;

        // Test Case 2: exp(1)
        $display("\nTest Case 2: exp(1)");
        xBus = 16'hFFFF;
        start = 1;
        @(posedge done);
        #10 start = 0;
        $display("Input x = 1.0");
        $display("Expected: 18'h2B7E1 (2.718281828)");
        $display("Got:      18'h%h", rBus);
        $display("Status:   %s", is_within_margin(rBus, 18'h2B7E1, 18'h0100) ? "PASS" : "FAIL");

        #50;

        // Test Case 3: exp(0.5)
        $display("\nTest Case 3: exp(0.5)");
        xBus = 16'h8000;
        start = 1;
        @(posedge done);
        #10 start = 0;
        $display("Input x = 0.5");
        $display("Expected: 18'h1A612 (1.648721271)");
        $display("Got:      18'h%h", rBus);
        $display("Status:   %s", is_within_margin(rBus, 18'h1A612, 18'h0100) ? "PASS" : "FAIL");

        #50;

        // Test Case 4: exp(-0.5)
        $display("\nTest Case 4: exp(-0.5)");
        xBus = 16'h8000;
        start = 1;
        @(posedge done);
        #10 start = 0;
        $display("Input x = -0.5");
        $display("Expected: 18'h09B63 (0.606530659)");
        $display("Got:      18'h%h", rBus);
        $display("Status:   %s", is_within_margin(rBus, 18'h09B63, 18'h0100) ? "PASS" : "FAIL");

        #50;

        // Test Case 5: Reset during operation
        $display("\nTest Case 5: Reset during operation");
        xBus = 16'hFFFF;
        start = 1;
        #30;
        rst = 1;
        #10;
        rst = 0;
        start = 0;
        $display("Reset test completed");
        $display("Expected after reset: 18'h00000");
        $display("Got:                 18'h%h", rBus);
        $display("Status:              %s", (rBus == 18'h00000) ? "PASS" : "FAIL");

        #50;

        // Test Case 6: Back-to-back calculations
        $display("\nTest Case 6: Back-to-back calculations");
        // First calculation: exp(0.25)
        xBus = 16'h4000;
        start = 1;
        @(posedge done);
        #10;
        $display("First calculation (exp(0.25)):");
        $display("Expected: 18'h148B1 (1.284025416)");
        $display("Got:      18'h%h", rBus);
        $display("Status:   %s", is_within_margin(rBus, 18'h148B1, 18'h0100) ? "PASS" : "FAIL");
        
        // Second calculation: exp(0.75)
        xBus = 16'hC000;
        @(posedge done);
        #10 start = 0;
        $display("Second calculation (exp(0.75)):");
        $display("Expected: 18'h21EB8 (2.117000017)");
        $display("Got:      18'h%h", rBus);
        $display("Status:   %s", is_within_margin(rBus, 18'h21EB8, 18'h0100) ? "PASS" : "FAIL");

        // End simulation
        #100;
        $display("\nTestbench completed");
        $finish;
    end

    // Timeout watchdog
    initial begin
        #100000;
        $display("Timeout: Simulation took too long!");
        $finish;
    end

endmodule
