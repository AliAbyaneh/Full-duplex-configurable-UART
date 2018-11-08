`timescale 1ns / 1ns
module RX_test ();
  reg rst, TxD_start;
  reg [7:0] TxD_data;
  wire BaudTick,Busy, TxD;
  reg clk = 0;
  Tx uut1(.TxD_start(TxD_start), .TxD_data(TxD_data), .BaudTick(BaudTick), .Busy(Busy), .TxD(TxD), .clk(clk), .rst(rst));
  Baud_Rate_Generator uut2(.clk(clk), .baud(BaudTick));
  always #1 clk = ~clk;
  initial begin
  rst = 1;
    #100
    rst = 0;
    TxD_start = 1;
    TxD_data = 8'b01010101;
    #1000
    TxD_start = 0;
    #1000000
    $stop;

  end
endmodule // RX_test
