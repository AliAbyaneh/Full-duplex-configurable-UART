// Authors : Ali Abyaneh, Mahyar Emami
// Fall 2017, Computer Architecture

`include "macros.v"
module Tx(TxD_start, TxD_data, BaudTick, Busy, TxD, clk, rst);
  parameter BITS = 8;
  localparam LOG_BITS = `LOG2_CEIL(BITS);
  input TxD_start, BaudTick, clk, rst;
  input [BITS-1:0] TxD_data;
  reg [BITS-1:0] TxD_reg;
  output reg TxD, Busy;

  reg [LOG_BITS - 1:0] countBits;
  reg [1:0] ps, ns;

  reg rstCountBits, enCountBits, ldTxD;
  wire done;
  assign done = (countBits == (BITS - 1));
  always @(posedge clk)
  begin
    if(rst)
    begin
      ps <= 0;
      countBits <= 0;
    end
    else
    begin
      ps <= ns;
      if(rstCountBits)
        countBits <= 0;
      else if(enCountBits)
        countBits <= countBits + 1;
    end
  end
  localparam WAIT = 0, START = 1, SEND = 2, STOP = 3;
  always @(*)
  begin
    TxD = 1'b1; Busy = 1'b0; enCountBits = 1'b0; rstCountBits = 1'b0; ldTxD = 1'b0;
    case (ps)
      WAIT: begin TxD = 1'b1; Busy = 1'b0; end
      START: begin TxD = 1'b0; Busy = 1'b1; rstCountBits = 1'b1; ldTxD = 1'b1; end
      SEND: begin TxD = TxD_data[countBits]; Busy = 1'b1; if(BaudTick) enCountBits = 1'b1; end
      STOP: Busy = 1'b1;
      default:begin TxD = 1'b1; Busy = 1'b0; enCountBits = 1'b0; rstCountBits = 1'b0; end
    endcase
  end
  always @(*)
  begin
    ns = WAIT;
    case(ps)
      WAIT: if(TxD_start) ns = START; else ns = WAIT;
      START:if(BaudTick == 1'b1) ns = SEND; else ns = START;
      SEND: if(done && BaudTick) ns = STOP; else ns = SEND;
      STOP: if(BaudTick) ns = WAIT; else ns = STOP;
      default: ns = WAIT;
    endcase
  end



endmodule
