// Authors : Ali Abyaneh, Mahyar Emami
// Fall 2017, Computer Architecture

`timescale 1ns / 1ns
module testbench();

  parameter SAMPLES_COUNT = 10,//total samples : 221184,
            WIDTH = 16,
            OUT_WIDTH = 38,
            LENGTH = 16;

  reg clk, rst, clk_emul, rst_emul;
  wire RxD, TxD;

  /*TopController #(.BITS(8), .FilterLENGTH(LENGTH), .FilterWIDTH(WIDTH))
                MUT(
                    .CLOCK_50(clk),
                    .UART_RXD(RxD),
                    .UART_TXD(TxD),
                    .SW(rst)
                  );*/
  system #(.UART_BITS(8), .FILTER_LENGTH(16), .INPUT_WIDTH(16))
          SysUT(
                .clk(clk),
                .rst(rst),
                .TxD(TxD),
                .RxD(RxD)
                );
  reg start;
  emulator #(.BITS(8))
              EMUL(
                    .clk(clk_emul),
                    .rst(rst_emul),
                    .RxD(TxD),
                    .TxD(RxD),
                    .send(start)
                  );
  always #4 clk = ~clk;
  always #2 clk_emul = ~clk_emul;
  initial
  begin
    clk = 0;
    start = 0;
    rst = 1;
    rst_emul = 1;
    #2 clk_emul = 0;
    #6 rst = 0;
    #10 rst_emul = 0;
    #100 start = 1;
    #110 start = 0;
    #1000000 $stop;
  end


endmodule
