// Authors : Ali Abyaneh, Mahyar Emami
// Fall 2017, Computer Architecture

`timescale 1 ps / 1 ps
module setupSystem(CLOCK_50, SW, UART_TXD, UART_RXD, LEDR);
	input CLOCK_50;
	input [17:0]SW;
	output UART_TXD;
	input UART_RXD;
	output [17:0]LEDR;
	wire CLOCK_100;
	system systemUnit(
			 .clk(CLOCK_100),
			 .rst(SW[0]),
			 .TxD(UART_TXD),
			 .RxD(UART_RXD)
			);
	//TopController ut(CLOCK_50, SW[0], UART_TXD, UART_RXD);

	PLL PLLUnit(
					.areset(SW[0]),
					.inclk0(CLOCK_50),
					.c0(CLOCK_100),
					.locked(LEDR[0])
					);
endmodule
