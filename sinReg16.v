// 16-bit register with initialization for sin
module sinReg16 (input clk, rst, init1, load, input [15:0] initVal, 
  input [15:0] in, output reg [15:0] out);
  always @ (posedge clk, posedge rst) begin
    if (rst == 1)
      out <= 0;
    else begin
      if (init1 == 1)
        out <= initVal;
      else begin
        if (load == 1)
          out <= in;
      end
    end
  end
endmodule

