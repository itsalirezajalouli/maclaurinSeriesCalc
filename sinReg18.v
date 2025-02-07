// 18 bit registers for sin
module sinReg18 (input clk, rst, init1, load, input [17:0] initS, input [17:0] in, output reg [17:0] out);
  always @ (posedge clk, posedge rst) begin
    if (rst == 1)
      out <= 0;
    else begin
      if (init1 == 1)
        out <= initS;
      else begin
        if (load == 1)
          out <= in;
      end
    end
  end
endmodule
