// Authors : Ali Abyaneh, Mahyar Emami
// Fall 2017, Computer Architecture

module wrapper(CLOCK_50, SW, UART_TXD, UART_RXD);
  input CLOCK_50, UART_RXD;
  input [17:0] SW;
  output UART_TXD;
  system INST(
              .clk(CLOCK_50),
              .rst(SW[0]),
              .RxD(UART_RXD),
              .TxD(UART_TXD)
              );
endmodule
