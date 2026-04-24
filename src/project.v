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

  // Bidirectional pins - all inputs
  assign uio_out = 8'b0;
  assign uio_oe  = 8'b0;  // All bidirectional pins configured as inputs

  // Input mapping
  // ui_in[3:0] = activation input (FP4) OR scale_low[7:0] when loading
  // ui_in[7:4] = weight input (FP4) OR scale_high[7:0] when loading
  wire [3:0] a_in     = ui_in[3:0];  // Activation input (FP4)
  wire [3:0] w_in     = ui_in[7:4];  // Weight input (FP4)
  
  // Double-flop synchronizers for control signals (metastability protection)
  reg [4:0] uio_sync_1, uio_sync_2;
  
  always @(posedge clk) begin
    if (!rst_n) begin
      uio_sync_1 <= 5'b0;
      uio_sync_2 <= 5'b0;
    end else begin
      uio_sync_1 <= uio_in[4:0];
      uio_sync_2 <= uio_sync_1;
    end
  end
  
  // Control signals (synchronized)
  wire       data_valid = uio_sync_2[0]; // Data valid enable - process MAC
  wire       reset_acc  = uio_sync_2[1]; // Reset accumulator to zero
  wire       load_scale_low = uio_sync_2[2]; // Load scale factor low byte
  wire       load_scale_high = uio_sync_2[3]; // Load scale factor high byte
  wire       vector_mode = uio_sync_2[4]; // Enable vector output mode
  wire       h_en_in  = data_valid;  // Horizontal enable controlled by data_valid
  wire       v_en_in  = data_valid;  // Vertical enable controlled by data_valid
  wire       ld_bias  = reset_acc;   // Load bias when reset_acc is asserted
  
  // Scale factor register - simple parallel load
  reg [15:0] scale_factor;
  
  always @(posedge clk) begin
    if (!rst_n) begin
      scale_factor <= 16'h3C00;  // Default: 1.0 in FP16
    end else begin
      if (load_scale_low)
        scale_factor[7:0] <= ui_in[7:0];  // Load low byte
      if (load_scale_high)
        scale_factor[15:8] <= ui_in[7:0]; // Load high byte
    end
  end
  
  // Internal signals
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
      .acc_out  (acc_out)
  );
  
  // Vector unit: FP16 × FP16 → FP4 multiplier
  wire [3:0] vector_out;
  
  FloatP16x4 #(
      .INPUT_WIDTH(16),
      .OUTPUT_WIDTH(4)
  ) u_vector_mul (
      .A   (acc_out),
      .B   (scale_factor),
      .Out (vector_out)
  );
  
  // Output mapping
  // When vector_mode=1: output FP4 scaled result
  // When vector_mode=0: output raw FP16 accumulator (upper 8 bits: sign + exponent + upper mantissa)
  assign uo_out[3:0] = vector_mode ? vector_out : acc_out[11:8];
  assign uo_out[7:4] = vector_mode ? 4'b0 : acc_out[15:12];

  // List all unused inputs to prevent warnings
  wire _unused = &{ena, uio_in[7:5], acc_out[7:0], 1'b0};

endmodule
