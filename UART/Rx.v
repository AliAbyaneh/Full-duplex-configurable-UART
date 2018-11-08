// Authors : Ali Abyaneh, Mahyar Emami
// Fall 2017, Computer Architecture

`include "macros.v"
module Rx(BaudTick, RxD, data_ready, RxD_data, clk, rst);
  parameter BITS = 8, RATE_MULTIPLIER= 4, BAUD_RATE = 115200, CLOCK_RATE = 50000000;
  localparam LOG_BITS = `LOG2_CEIL(BITS), LOG_RATE = `LOG2_CEIL(RATE_MULTIPLIER);
  localparam LOG_RATE2 = LOG_RATE / 2;
  input BaudTick, RxD, clk, rst;
  output reg data_ready;
  output reg [BITS-1:0] RxD_data;
  reg [BITS:0] RxD_reg;
  //assign RxD_data = RxD_reg;
  reg [2:0] ps, ns;
  reg [LOG_BITS:0] countBits;
  reg [LOG_RATE - 1:0] countTicks;
  reg [LOG_RATE2:0] countEdge;
  reg rstCountBits, enCountBits, shiftData, rstCountTicks, enCountTicks, rstCountEdge, enCounEdge, ldOut;
  reg sample;
  wire countBitsDone, countTicksDone, countEdgeDone;
  wire SampleTick;
  Baud_Rate_Generator #(
                        .baud_rate(BAUD_RATE * RATE_MULTIPLIER),
                        .clk_rate(CLOCK_RATE)
                        )TickGen(
                                .clk(clk),
                                .baud(SampleTick)
                                );

  localparam IDLE = 0, SET = 1, PASS = 2, SAMPLE = 3, ALIGN = 4, DATAREADY = 5, DONE = 6;
  integer i;
  always @(posedge clk)
  begin
    if(rst)
    begin
      countBits <= 0;
      countTicks <= 0;
	    countEdge <= 0;
      RxD_reg <= 0;
      ps <= IDLE;
	  RxD_data <= 0;
    end
    else
    begin
      ps <= ns;
      if(rstCountBits)
        countBits <= 0;
      else if(enCountBits)
        countBits <= countBits + 1;
      if(rstCountTicks)
        countTicks <= 0;
      else if(enCountTicks)
        countTicks <= countTicks + 1;
	    if(rstCountEdge)
		    countEdge <= 0;
	    else if(enCounEdge)
		    countEdge <= countEdge + 1;
      if(shiftData)
      begin
        for(i = 1; i < BITS + 1 ; i = i + 1)
          RxD_reg[i - 1] <= RxD_reg[i];
        RxD_reg[BITS] <= sample;
      end
	  if(ldOut)
		RxD_data <= RxD_reg[BITS-1:0];
    end
  end
  always@(*)
  begin
    case (ps)
      IDLE:   if (!RxD) ns = SET;   else ns = IDLE;
      SET:    if (RxD)  ns = IDLE;  else if(countEdgeDone) ns = PASS; else ns = SET;
      PASS:   if (countTicksDone) ns = SAMPLE;  else ns = PASS;
      SAMPLE: ns = ALIGN;
      ALIGN: if(SampleTick && ~countBitsDone) ns = PASS; else if(SampleTick && countBitsDone) ns = DATAREADY; else ns = ALIGN;
      DATAREADY: ns = DONE;
      DONE: if(BaudTick) ns = IDLE; else ns = DONE;
      default: ns = IDLE;
    endcase
  end
  always@(*)
  begin
  rstCountBits = 0;
  rstCountEdge = 0;
  rstCountTicks = 0;
  enCounEdge = 0;
  enCountBits = 0;
  enCountTicks = 0;
  shiftData = 0;
  data_ready = 0;
  sample = 0;
  ldOut = 0;
  case (ps)
    IDLE   : begin rstCountEdge = 1; rstCountBits = 1; rstCountBits = 1; end
    SET    : begin enCounEdge = SampleTick; end
    PASS   : begin enCountTicks = SampleTick; end
    SAMPLE : begin sample = RxD; enCountBits = 1; rstCountTicks = 1; shiftData = 1;end
    DATAREADY: begin ldOut = 1; end//RxD_data = RxD_reg[BITS-1:0];end
    DONE: if(BaudTick) data_ready = 1; else data_ready = 0;
    default:
    begin
      rstCountBits = 0;
      rstCountEdge = 0;
      rstCountTicks = 0;
      enCounEdge = 0;
      enCountBits = 0;
      enCountTicks = 0;
      shiftData = 0;
      data_ready = 0;
      sample = 0;
	    ldOut = 0;
    end
  endcase
  end
  //assign RxD_data = RxD_reg;
  assign countBitsDone = (countBits == BITS + 1);
  assign countTicksDone = (countTicks == RATE_MULTIPLIER - 1);
  assign countEdgeDone = (countEdge == RATE_MULTIPLIER/2);
endmodule
