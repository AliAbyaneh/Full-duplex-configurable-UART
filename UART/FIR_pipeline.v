// Authors : Ali Abyaneh, Mahyar Emami
// Fall 2017, Computer Architecture

`timescale 1 ps / 1 ps
`include "macros.v"
module multiplier(a, b, p);
  parameter WIDTH = 16;
  input signed [WIDTH - 1:0] a, b;
  output signed [2 * WIDTH - 1:0] p;
  assign p = a * b;
endmodule
/*module ROM(clk, address, q);
  parameter WIDTH = 16;
  parameter LENGTH = 64;
  localparam ADDRSPACE = `LOG2_CEIL(LENGTH);
  input [ADDRSPACE-1:0] address;
  output reg [WIDTH-1:0] q;
  input clk;
  reg signed [WIDTH-1:0] COEFF [0:LENGTH-1];
  initial begin
    $readmemh("coeff.hex", COEFF);
  end
  always @(posedge clk)
    q <= COEFF[address];
endmodule*/
module FIR_sync(
            clk,
            rst,
            FIR_input,
            input_valid,
            FIR_output,
            output_valid
          );
  parameter LENGTH = 64;
  parameter WIDTH = 16;
  parameter OUT_WIDTH = 2 * WIDTH + `LOG2_CEIL(LENGTH) - 1;

  input clk, rst, input_valid;
  input signed [WIDTH-1:0] FIR_input;
  output reg output_valid;
  output reg signed [OUT_WIDTH - 1:0] FIR_output;

  wire [WIDTH-1:0] coeff;

  //reg signed [WIDTH-1:0] coeff [0:LENGTH-1];
  reg signed [WIDTH-1:0] shiftreg[0:LENGTH-1];

  localparam WAIT = 0, START = 1, LOAD_COEFF = 2, CALC_MUL = 3, CALC_SUM = 4, SAVE = 5, DONE = 6;
  reg [2:0] ps, ns;
  reg signed [OUT_WIDTH - 1:0] ACC;
  reg signed [2*WIDTH - 1:0] PREG;
  localparam  ADDRESS_RANGE = `LOG2_CEIL(LENGTH);
  reg [ADDRESS_RANGE - 1:0] address;
  reg ldACC, addrCount, addrRst, ACCRst, shen, ldPREG, ldOut;
  wire mul_finished;
  wire signed [OUT_WIDTH - 1:0] sum;
  wire signed [2*WIDTH - 1:0] product;

  //assign FIR_output = ACC;

  /*ROM #(.WIDTH(WIDTH), .LENGTH(LENGTH))
                                      coeffROM(
                                                .clk(clk),
                                                .address(address),
                                                .q(coeff)
                                              );*/
  ROM coROM (.clock(clk), .address(address), .q(coeff));

  multiplier #(WIDTH) MULT(
                  .a(shiftreg[address]),
                  .b(coeff),
                  .p(product)
                  );

  assign sum = ACC + PREG;
  assign mul_finished = (address == LENGTH - 1) ? 1'b1:1'b0;
  //State registers, address counter, and ACC register
  integer i;
  always @(posedge clk) begin
    if(rst)begin
      ps <= 0;
      for(i = 0; i < LENGTH; i = i + 1)
        shiftreg[i] <= 0;
    end
    else
      ps <= ns;
    if(shen)begin
      for(i = 0; i < LENGTH - 1; i = i + 1)
        shiftreg[i + 1] <= shiftreg[i];
      shiftreg[0] <= FIR_input;
    end
    if(addrRst)
      address <= 0;
    else if(addrCount)
      address <= address + 1;
    if(ACCRst)begin
      ACC <= 0;
      PREG <= 0;
    end
    else if(ldACC)
      ACC <= sum;
    if (ldPREG)
      PREG <= product;
    if(ldOut)
      FIR_output <= ACC;
  end
  //Next state evaluation logic
  always @(ps, input_valid, mul_finished) begin
    ns = WAIT;
    case(ps)
      WAIT: if(input_valid) ns = START; else ns = WAIT;
      START: if(input_valid) ns = START; else ns = LOAD_COEFF;
      LOAD_COEFF: ns = CALC_MUL;
      CALC_MUL: ns = CALC_SUM;
      CALC_SUM: if(mul_finished) ns = SAVE; else ns = LOAD_COEFF;
      SAVE: ns = DONE;
      DONE: if(input_valid) ns = START; else ns = WAIT;
      default: ns = WAIT;
    endcase
  end
  //Signal evaluation
  always@(ps)begin
    addrCount = 0;
    ldACC = 0;
    addrRst = 0;
    ACCRst = 0;
    output_valid = 0;
    shen = 0;
    ldPREG = 0;
    ldOut = 0;
    case(ps)
      START: begin addrRst = 1'b1; ACCRst = 1'b1; shen = 1'b1; end
      CALC_MUL: ldPREG = 1'b1;
      CALC_SUM: begin addrCount = 1'b1; ldACC = 1'b1; end
      SAVE: ldOut = 1'b1;
      DONE: output_valid = 1'b1;
      default: output_valid = 1'b0;
    endcase
  end

endmodule
