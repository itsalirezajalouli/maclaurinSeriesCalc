// 3-bit counter module
module cntReg (input clk, rst, cntUp, init0, output reg [2:0] cnt);
  always @ (posedge clk, posedge rst) begin
    if (rst == 1)
      cnt <= 0;
    else begin
      if (init0 == 1)
        cnt <= 0;
      else begin
        if (cntUp == 1)
          cnt <= cnt + 1;
      end
    end
  end
endmodule
