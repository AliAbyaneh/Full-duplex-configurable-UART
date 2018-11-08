// Authors : Ali Abyaneh, Mahyar Emami
// Fall 2017, Computer Architecture

`include "macros.v"
module system(clk, rst, TxD, RxD);
  input clk, rst, RxD;
  output TxD;
  parameter   FILTER_LENGTH = 64,
              INPUT_WIDTH = 16,
              UART_BITS = 8;
  localparam  RESULT_WIDTH = 2 * INPUT_WIDTH + `LOG2_CEIL(FILTER_LENGTH) - 1;
  parameter FCLK = 100000000,
            BAUD_RATE = 115200;
  parameter TX_BUFFER_SIZE = INPUT_WIDTH * 8;
  localparam LOG2_TX_BUFFER_SIZE = `LOG2_CEIL(TX_BUFFER_SIZE);
  wire [UART_BITS-1:0] TxD_data;
  wire TxD_start;
  wire BusyTxD;
  wire TxD, BaudTick;
  Tx #(.BITS(UART_BITS)) TXUnit (.clk(clk),
                            .rst(rst),
                            .TxD_data(TxD_data),
                            .TxD_start(TxD_start),
                            .BaudTick(BaudTick),
                            .Busy(BusyTxD),
                            .TxD(TxD)
                            );
  Baud_Rate_Generator #(.baud_rate(BAUD_RATE), .clk_rate(FCLK))
                      BaudGen (.clk(clk), .baud(BaudTick));
  wire data_ready;
  wire [UART_BITS-1:0] RxD_data;
  Rx #(.BITS(UART_BITS), .RATE_MULTIPLIER(4), .BAUD_RATE(BAUD_RATE), .CLOCK_RATE(FCLK))
                    RXUnit(
                            .clk(clk),
                            .BaudTick(BaudTick),
                            .RxD(RxD),
                            .RxD_data(RxD_data),
                            .data_ready(data_ready),
                            .rst(rst)
                          );
  wire [INPUT_WIDTH-1:0] FIR_input;
  wire [RESULT_WIDTH-1:0] FIR_output;
  wire FIR_input_valid;
  wire FIR_output_valid;
  FIR_sync #(.LENGTH(FILTER_LENGTH), .WIDTH(INPUT_WIDTH))
            FILTER(
                    .clk(clk),
                    .rst(rst),
                    .FIR_input(FIR_input),
                    .FIR_output(FIR_output),
                    .input_valid(FIR_input_valid),
                    .output_valid(FIR_output_valid)
                  );
  localparam RX_BUFFER_SIZE = INPUT_WIDTH / UART_BITS;
  localparam TX_BUFFER_STEP = INPUT_WIDTH / UART_BITS;
  localparam LOG2_RX_BUFFER_SIZE = `LOG2_CEIL(RX_BUFFER_SIZE);
  //localparam LOG2_TX_BUFFER_SIZE = `LOG2_CEIL(TX_BUFFER_SIZE);
  reg [UART_BITS-1:0] Rx_buffer [0:RX_BUFFER_SIZE - 1];
  reg [UART_BITS-1:0] Tx_buffer [0:TX_BUFFER_SIZE - 1];
  wire [UART_BITS-1:0] Tx_buffer_input [0:TX_BUFFER_STEP - 1];
  reg [LOG2_RX_BUFFER_SIZE - 1:0] Rx_buffer_ptr;
  reg [LOG2_TX_BUFFER_SIZE - 1:0] Tx_buffer_ptr;
  //reg [LOG2_RX_BUFFER_SIZE - 2:0] next_word_ptr;
  reg [1:0] state_r, state_t;
  reg save_pending;
  integer i;
  //STATES
  /*localparam  RESET = 0,
              MAIN = 1,
              CALC = 2,
              RECEIVE = 3,
              TRANSMIT = 4,
              SAVE = 5;*/
  localparam  MAIN = 0,
              RECEIVE = 1,
              CALC = 2;
  localparam  TRANSMIT = 0,
              SAVE = 1;

  always @(posedge clk)
  begin
    if(rst)
    begin
      state_r <= MAIN;
      state_t <= TRANSMIT;
      for(i = 0; i < RX_BUFFER_SIZE; i = i + 1)
			   Rx_buffer[i] <= 0;
			Rx_buffer_ptr <= 0;
			Tx_buffer_ptr <= 0;
			//next_word_ptr <= 0;
			save_pending <= 0;
    end
    else
    begin
      case(state_r)
        MAIN:
        begin
          //Interrupt handling vectors
          //0.RECEIVE 1.TRANSMIT
          if(data_ready)
          begin
            state_r <= RECEIVE;
          end
          else
            state_r <= MAIN;
        end
        RECEIVE:
        begin
          Rx_buffer_ptr <= Rx_buffer_ptr + 1;
          Rx_buffer[Rx_buffer_ptr] <= RxD_data;
          //if enough data was received then initiate the filter
          if(Rx_buffer_ptr == RX_BUFFER_SIZE - 1)
            state_r <= CALC;
          else
            state_r <= MAIN;
        end
        CALC:
        begin
          //checking for incoming data:
          if(data_ready)
            state_r <= RECEIVE;
          else
            state_r <= MAIN;
          /*However the if condition would
            never hold true since we just came
            out of RECEIVE state
          */
        end
      endcase
      case(state_t)
        SAVE:
        begin
          for(i = 0; i < TX_BUFFER_SIZE - TX_BUFFER_STEP; i = i + 1)
          begin
            if(i < TX_BUFFER_STEP)
              Tx_buffer[i] <= Tx_buffer_input[i];
            Tx_buffer[i + TX_BUFFER_STEP] <= Tx_buffer[i];
          end
          Tx_buffer_ptr <= Tx_buffer_ptr + TX_BUFFER_STEP;
          if(FIR_output_valid)
            state_t <= SAVE;
          else
            state_t <= TRANSMIT;
        end
        TRANSMIT:
        begin
          if(FIR_output_valid)
            state_t <= SAVE;
          else
            state_t <= TRANSMIT;
          if(BusyTxD == 0 && Tx_buffer_ptr != 0)
            Tx_buffer_ptr <= Tx_buffer_ptr - 1;
        end
      endcase
    end
  end
  assign TxD_start = (state_t == TRANSMIT && BusyTxD == 0 && Tx_buffer_ptr != 0) ? 1 : 0;
  assign TxD_data = Tx_buffer[Tx_buffer_ptr];
  assign FIR_input_valid = (state_r == CALC);
  wire [INPUT_WIDTH - 1:0] FIR_output_slice;
  assign FIR_output_slice = FIR_output[34:19];
  generate
  genvar j;
  for(j = 0; j < RX_BUFFER_SIZE; j = j + 1)
  begin: BufferLoop
    assign Tx_buffer_input [TX_BUFFER_STEP - 1 - j] = FIR_output_slice[(j + 1)* UART_BITS - 1: j * UART_BITS];
    assign FIR_input [(j + 1) * UART_BITS - 1: j* UART_BITS] = Rx_buffer[j];
  end
  endgenerate
endmodule
