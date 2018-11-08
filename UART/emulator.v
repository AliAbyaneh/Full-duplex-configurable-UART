// Authors : Ali Abyaneh, Mahyar Emami
// Fall 2017, Computer Architecture

`include "macros.v"
module emulator (clk, rst, RxD, TxD, send);
  parameter BUFFERSIZE = 10,
            BITS = 8,
            FCLK = 100000000,
            SAMPLES_COUNT = 10;
  localparam LOG2_BUFFERSIZE = `LOG2_CEIL(BUFFERSIZE);
  localparam LOG2_SAMPLES_COUNT = `LOG2_CEIL(SAMPLES_COUNT);
  input clk, rst, RxD, send;
  output TxD;
  reg [BITS-1:0] Rx_buffer [0:BUFFERSIZE-1];
  //reg Rx_buffer_valid [0:BUFFERSIZE-1];
  reg [LOG2_BUFFERSIZE-1:0] Rx_buffer_ptr;
  reg [2*BITS-1:0] RAM [0:SAMPLES_COUNT-1];
  reg [LOG2_SAMPLES_COUNT-1:0] RAM_ptr;
  reg [BITS-1:0] TxD_data;
  wire TxD_start;
  wire BusyTxD;
  wire TxD, BaudTick;
  Tx #(.BITS(BITS)) TXUnit (.clk(clk),
                            .rst(rst),
                            .TxD_data(TxD_data),
                            .TxD_start(TxD_start),
                            .BaudTick(BaudTick),
                            .Busy(BusyTxD),
                            .TxD(TxD)
                            );
  Baud_Rate_Generator #(.baud_rate(115200), .clk_rate(FCLK))
                      BaudGen (.clk(clk), .baud(BaudTick));
  wire data_ready;
  wire [BITS-1:0] RxD_data;
  Rx #(.BITS(BITS), .RATE_MULTIPLIER(4), .BAUD_RATE(115200), .CLOCK_RATE(FCLK))
                    RXUnit(
                            .clk(clk),
                            .BaudTick(BaudTick),
                            .RxD(RxD),
                            .RxD_data(RxD_data),
                            .data_ready(data_ready),
                            .rst(rst)
                          );
  reg [2*BITS-1:0] input_samples [0:SAMPLES_COUNT-1];
  initial begin
    $readmemb("inputs.bin", input_samples);
  end
  localparam IDLE = 0, INIT = 1,TRANSMIT1 = 2, TRANSMIT2 = 3, RECEIVE = 4, MOVE = 5;
  reg [31:0] sample_counter;
  //reg [1:0] inc;
  reg [31:0] ptr;
  reg [2:0] state;
  reg [2:0] prev_state;
  //reg [BITS-1:0] FIFO [1:0];
  integer i;
  always @(posedge clk)
  begin
    if(rst)
    begin
      for(i = 0; i < BUFFERSIZE; i = i + 1)
      begin
        Rx_buffer[i] <= 0;
        //Rx_buffer_valid[i] <= 0;
      end
      Rx_buffer_ptr <= 0;
      state <= IDLE;
      prev_state <= IDLE;
      sample_counter <= 0;
      RAM_ptr <= 0;
    end
    else
    begin
      //state <= next_state;
      case(state)
        IDLE:
        begin
          if(send)
            state <= INIT;
        end
        INIT:
        begin
          sample_counter <= 0;
          Rx_buffer_ptr <= 0;
          RAM_ptr <= 0;
          if(send == 0)
            state <= TRANSMIT1;
        end
        TRANSMIT1:
        begin
          prev_state <= state;
          if(data_ready)
            state <= RECEIVE;
          else if(BusyTxD == 0)
          begin
            TxD_data <= input_samples [sample_counter][BITS-1:0];
            state <= TRANSMIT2;
          end
          else
            state <= TRANSMIT1;
        end
        TRANSMIT2:
        begin
          prev_state <= state;
          if(data_ready)
            state <= RECEIVE;
          else if (BusyTxD == 0)
          begin
            TxD_data <= input_samples [sample_counter][2*BITS-1:BITS];
            sample_counter <= sample_counter + 1;
            state <= TRANSMIT1;
          end
          else
            state <= TRANSMIT2;
        end
        RECEIVE:
        begin
          if(Rx_buffer_ptr < BUFFERSIZE)
          begin
            //Rx_buffer_ptr <= Rx_buffer_ptr + 1;
            Rx_buffer[Rx_buffer_ptr] <= RxD_data;
          end
          state <= MOVE;
        end
        MOVE:
        begin
          if(Rx_buffer_ptr[0] == 1'b0 && Rx_buffer_ptr != 0)
          begin
            RAM[RAM_ptr] <= {Rx_buffer[Rx_buffer_ptr], Rx_buffer_ptr[Rx_buffer_ptr - 1]};
            RAM_ptr <= RAM_ptr + 1;
            if(Rx_buffer_ptr > 1)
              Rx_buffer_ptr <= Rx_buffer_ptr - 2;
            else
              Rx_buffer_ptr <= 0;
          end
          else
            Rx_buffer_ptr <= Rx_buffer_ptr + 1;
          if(RAM_ptr == SAMPLES_COUNT - 1)
            state <= IDLE;
          else
            state <= prev_state;
        end
      endcase
    end
  end
  assign TxD_start = ((state == TRANSMIT1 || state == TRANSMIT2) && BusyTxD == 0 && sample_counter < SAMPLES_COUNT) ? 1'b1 : 1'b0;

endmodule
