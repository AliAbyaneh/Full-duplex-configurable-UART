// Authors : Ali Abyaneh, Mahyar Emami
// Fall 2017, Computer Architecture


`timescale 1ns / 1ns
`include "macros.v"

 module Baud_Rate_Generator (clk, baud);
  parameter  clk_rate = 50000000;
  parameter  baud_rate = 115200;
  input clk;
  output baud;
  localparam  ratio = clk_rate/baud_rate;
  localparam  Counter_Length = `LOG2_CEIL(ratio);

  reg [Counter_Length - 1 : 0] Counter = 0;
  always@(posedge clk)
  begin
    if(Counter == ratio)
      Counter <= 0;
    else
      Counter <= Counter + 1;
  end
  assign baud = (Counter == ratio) ? 1 : 0;
 endmodule // `
