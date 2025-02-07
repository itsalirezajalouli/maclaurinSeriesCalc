module maclaurinSeriesCalc (
    input clk, rst, start,
    input [15:0] xBus,
    input [1:0] func,
    output [17:0] rBus,
    output done
);
    
    // Internal signals
    wire done_exp, done_sin, done_cos, done_ln;
    wire [17:0] rBus_exp, rBus_sin, rBus_cos, rBus_ln;
    
    // Instantiating the four function modules
    expTop exp_module (.clk(clk), .rst(rst), .start(start & (func == 2'b00)), .xBus(xBus), .rBus(rBus_exp), .done(done_exp));
    sinTop sin_module (.clk(clk), .rst(rst), .start(start & (func == 2'b01)), .xBus(xBus), .rBus(rBus_sin), .done(done_sin));
    cosTop cos_module (.clk(clk), .rst(rst), .start(start & (func == 2'b10)), .xBus(xBus), .rBus(rBus_cos), .done(done_cos));
    lnTop  ln_module  (.clk(clk), .rst(rst), .start(start & (func == 2'b11)), .xBus(xBus), .rBus(rBus_ln),  .done(done_ln));
    
    // Output selection based on function
    assign rBus = (func == 2'b00) ? rBus_exp :
                  (func == 2'b01) ? rBus_sin :
                  (func == 2'b10) ? rBus_cos :
                                   rBus_ln;
    
    assign done = (func == 2'b00) ? done_exp :
                  (func == 2'b01) ? done_sin :
                  (func == 2'b10) ? done_cos :
                                   done_ln;
    
endmodule

