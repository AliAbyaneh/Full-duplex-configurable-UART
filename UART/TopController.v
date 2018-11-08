// Authors : Ali Abyaneh, Mahyar Emami
// Fall 2017, Computer Architecture

`include "macros.v"

module TopController (CLOCK_50, SW, UART_TXD, UART_RXD);
  input CLOCK_50;
  input SW;
  output UART_TXD;
  input UART_RXD;
  wire rst, BaudTick, Busy, TxD, data_ready;
  wire signed [15:0] splited_FIR_out;
  parameter FilterLENGTH = 64;
  parameter FilterWIDTH = 16;
  parameter BITS = 8;
  parameter OUT_WIDTH = 2 * FilterWIDTH + `LOG2_CEIL(FilterLENGTH) - 1;

  localparam FilterUARTWidthRatio = FilterWIDTH/BITS;
  localparam FilterUARTOUTWidthRatio = OUT_WIDTH/BITS;
  localparam NumOfInMesPart = `D8_CEIL(FilterWIDTH) - 1;
  localparam NumOfOutMesPart = 2;
  localparam  inPartsCntBits = `LOG2_CEIL(FilterUARTWidthRatio);
  localparam  outPartsCntBits = 3;
  // FIR filter wire decleration

  reg FIR_in_valid;
  reg signed [FilterWIDTH-1:0] FIR_input;
  wire FIR_O_valid;
  wire signed [OUT_WIDTH - 1:0] FIR_output;
  reg signed [15:0] Filter_Res;
  wire signed [15:0] Filter_Res1;
  reg TxD_start;
  reg [inPartsCntBits - 1 : 0] inputPartsCounter = 0;
  reg [outPartsCntBits - 1 : 0] outputPartsCounter = 0;
  assign rst = SW;
  reg [BITS-1:0] TxD_data;
  wire [BITS-1:0] RXD_data;

  reg sync_reg_1,sync_reg_2,RXD;

  always @(posedge CLOCK_50)  // assign synchronization registers
  begin
  sync_reg_1 <= UART_RXD;
  sync_reg_2 <= sync_reg_1;
  RXD <= sync_reg_2;
  end
  // Sate Machine states
  localparam WaitOnInput = 0, nthPartReady = 1, StartFilterInput = 2, WaitOnFilter = 3,TXIsBusy = 4,SendMessage = 5, Done = 6, WaitOnDataReady = 7;
  reg [3:0] state;

  always @ (posedge CLOCK_50) begin
    if(rst) begin
      TxD_data <= 0;
      state <= WaitOnInput;
      inputPartsCounter <= 0;
      FIR_in_valid <= 0;
      FIR_input <= 0;
      outputPartsCounter <= 0;
      TxD_start <= 1'b0;
    end
    else begin
      FIR_in_valid <= 0;
      case (state)
        WaitOnInput:
          begin
            TxD_start <= 1'b0;
            if(data_ready)
              state <= nthPartReady;
            else
              state <= WaitOnInput;
          end
        nthPartReady:
          begin
            FIR_input <= {RXD_data, FIR_input[FilterWIDTH - 1 : BITS]};
            if (inputPartsCounter == NumOfInMesPart) begin
                state <= StartFilterInput;
            end
            else if(!data_ready)
              state <= WaitOnInput;
            else
              state <= WaitOnDataReady;
            inputPartsCounter <= inputPartsCounter + 1;
          end
        StartFilterInput:
          begin
            FIR_in_valid <= 1'b1;
            state <=  WaitOnFilter;
          end
        WaitOnFilter:
          begin
            if(FIR_O_valid && ~Busy) begin
              state <= SendMessage;
              Filter_Res <= splited_FIR_out;
            end
            else if(Busy) begin
              state <= TXIsBusy;
              Filter_Res <= splited_FIR_out;
            end
            else
                state <= WaitOnFilter;
          end
        TXIsBusy:
          begin
            if(Busy)
              state <= TXIsBusy;
            else
              state <= SendMessage;
          end
        SendMessage:
          begin
            TxD_data <= Filter_Res1[15 : 8];
            if(~Busy && BaudTick) begin
              outputPartsCounter <= outputPartsCounter + 1;
              if (outputPartsCounter == NumOfOutMesPart) begin
                state <= Done;
              end
              else begin
                state <= SendMessage;
                TxD_start <= 1'b1;
                end
            end
            else
              TxD_start <= 1'b0;
            end
        Done:
          begin
            FIR_in_valid <= 0;
            state <= WaitOnInput;
          end
        WaitOnDataReady:
          begin
            if(!data_ready)
              state <= WaitOnInput;
            else
              state <= WaitOnDataReady;
          end
        default:
          begin
            state <= WaitOnInput;
            FIR_in_valid <= 0;
            FIR_input <= 0;
            inputPartsCounter <= 0;
            outputPartsCounter <= 0;
          end
      endcase
    end
  end
  assign Filter_Res1 = (outputPartsCounter == 0) ? Filter_Res : Filter_Res << ((outputPartsCounter - 1) * BITS);
  Tx #(BITS) TxUnit  (
                .clk(CLOCK_50),
                .rst(rst),
                .BaudTick(BaudTick),
                .TxD_data(TxD_data),
                .TxD(TxD),
                .Busy(Busy),
                .TxD_start(TxD_start)
                );
  assign UART_TXD = TxD;
  Baud_Rate_Generator BRGUnit (
                      .clk(CLOCK_50),
                      .baud(BaudTick)
                      );
	wire rdreq,q;
	Fifo myfifo(
				.clock(CLOCK_50),
				.data(UART_RXD),
				.rdreq(rdreq),
				.wrreq(BaudTick),
				.q(q));
	assign rdreq = (BaudTick && (state == WaitOnInput)) ? 1 : 0;
  Rx RXUnit(
         .BaudTick(BaudTick),
         .RxD(q),
         .data_ready(data_ready),
         .RxD_data(RXD_data),
         .clk(CLOCK_50),
         .rst(rst)
         );
   assign splited_FIR_out = FIR_output[34:19];
   FIR_sync#(.LENGTH(FilterLENGTH),  .WIDTH(FilterWIDTH)) FIRUnit(
               .clk(CLOCK_50),
               .rst(rst),
               .FIR_input(FIR_input),
               .input_valid(FIR_in_valid),
               .FIR_output(FIR_output),
               .output_valid(FIR_O_valid)
             );
endmodule // TopControlle(CLOCK_50, SW, UART_TXD, UART_RXD)
