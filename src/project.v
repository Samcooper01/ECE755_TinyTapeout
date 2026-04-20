/*
 * Copyright (c) 2024 Your Name
 * SPDX-License-Identifier: Apache-2.0
 */

`default_nettype none

module tt_um_example (
    input  wire [7:0] ui_in,    // Dedicated inputs
    output wire [7:0] uo_out,   // Dedicated outputs
    input  wire [7:0] uio_in,   // IOs: Input path
    output wire [7:0] uio_out,  // IOs: Output path
    output wire [7:0] uio_oe,   // IOs: Enable path (active high: 0=input, 1=output)
    input  wire       ena,      // always 1 when the design is powered, so you can ignore it
    input  wire       clk,      // clock
    input  wire       rst_n     // reset_n - low to reset
);

  // Bidirectional pins unused
  assign uio_out = 8'b0;
  assign uio_oe  = 8'b0;

  // Input mapping
  // ui_in[3:0] = activation input (FP4)
  // ui_in[7:4] = weight input (FP4)
  wire [3:0] a_in     = ui_in[3:0];  // Activation input (FP4)
  wire [3:0] w_in     = ui_in[7:4];  // Weight input (FP4)
  
  // Control signals (tied for simple operation)
  wire       h_en_in  = 1'b1;        // Always enabled
  wire       v_en_in  = 1'b1;        // Always enabled
  wire       ld_bias  = 1'b0;        // No bias loading (accumulate only)
  
  // Internal signals
  wire [3:0]  a_out;
  wire [3:0]  w_out;
  wire        h_en_out;
  wire        v_en_out;
  wire [15:0] acc_out;
  
  // Fixed bias value for testing (can be modified)
  wire [15:0] bias = 16'h0000;  // FP16 zero
  
  // Instantiate GEMM PE
  gemm_pe #(
      .ACT_WIDTH(4),
      .WGT_WIDTH(4),
      .ACC_WIDTH(16)
  ) u_gemm_pe (
      .clk      (clk),
      .a_in     (a_in),
      .h_en_in  (h_en_in),
      .w_in     (w_in),
      .v_en_in  (v_en_in),
      .bias     (bias),
      .ld_bias  (ld_bias),
      .a_out    (a_out),
      .h_en_out (h_en_out),
      .w_out    (w_out),
      .v_en_out (v_en_out),
      .acc_out  (acc_out)
  );
  
  // Output mapping - all 8 bits for accumulator
  assign uo_out[7:0] = acc_out[7:0]; // Lower 8 bits of accumulator

  // List all unused inputs to prevent warnings
  wire _unused = &{ena, rst_n, uio_in, acc_out[15:8], w_out, a_out, h_en_out, v_en_out, 1'b0};

endmodule
