// Authors : Ali Abyaneh, Mahyar Emami
// Fall 2017, Computer Architecture

	module Tx_test_FPGA(CLOCK_50, SW, UART_TXD, UART_RXD);


  input CLOCK_50;
  input [17:0]SW;
  output UART_TXD;
  input UART_RXD;
  wire rst, BaudTick, Busy, TxD, data_ready;
  assign rst = SW[0];
  reg [7:0] data_reg [0:7];
  reg [2:0] address;
  reg TxD_start;
  reg [7:0] TxD_data;
  wire [7:0] RXD_data;
  reg data1, RXD,data2;
  always @(posedge CLOCK_50)
  begin
	data1 <= UART_RXD;
	data2 <= data1;
	RXD <= data2;
	if(data_ready)
	begin
		TxD_data <= RXD_data;
		TxD_start <= 1'b1;
	end
	else
		TxD_start <= 1'b0;
  end

  assign UART_TXD = TxD;
  Tx #(8) TxUnit  (
                .clk(CLOCK_50),
                .rst(rst),
                .BaudTick(BaudTick),
                .TxD_data(TxD_data),
                .TxD(TxD),
                .Busy(Busy),
                .TxD_start(TxD_start)
                );
	Baud_Rate_Generator BRGUnit (
										  .clk(CLOCK_50),
										  .baud(BaudTick)
										  );

	Rx RXUnit(.BaudTick(BaudTick),
				 .RxD(RXD),
				 .data_ready(data_ready),
				 .RxD_data(RXD_data),
				 .clk(CLOCK_50),
				 .rst(rst)
				 );

endmodule
