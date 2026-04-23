<!---

This file is used to generate your project datasheet. Please fill in the information below and delete any unused
sections.

You can also include images in this folder and reference them in the markdown. Each image must be less than
512 kb in size, and the combined size of all images must be less than 1 MB.
-->

## What is Tiny Tapeout?

Tiny Tapeout is an educational project that makes it easier and cheaper than ever to get your digital and analog designs manufactured on a real chip.

To learn more and get started, visit https://tinytapeout.com.

## GEMM PE with Vector Unit

This design implements a Processing Element (PE) with an integrated vector unit for neural network inference:

### MAC Unit (Multiply-Accumulate)
- **FP4 Multiplier**: Multiplies 4-bit floating-point activation and weight inputs
- **FP16 Adder**: Accumulates results in 16-bit floating-point format
- **2-Stage Pipeline**: Fully pipelined design for maximum throughput
  - Stage 1: FP4 multiplication
  - Stage 2: FP16 addition/accumulation

### Vector Unit (Quantization/Activation)
- **FP16×FP16→FP4 Multiplier**: Scales FP16 accumulator by programmable scale factor
- **Output**: 4-bit FP4 quantized result
- **Use case**: Apply activation functions, quantize for next layer, or normalize outputs

**Operation**: `output = (accumulator × scale_factor) quantized to FP4`

### Architecture Details

- **Input**: 8 dedicated pins (4 bits activation + 4 bits weight, both FP4 format)
- **Output**: Selectable between vector and accumulator modes
  - `uo_out[3:0]`: FP4 scaled output when `vector_mode=1`
  - `uo_out[7:0]`: FP16 accumulator[7:0] when `vector_mode=0`
- **Control**: 5 bidirectional input pins
  - `uio_in[0]`: data_valid - enable MAC operation
  - `uio_in[1]`: reset_acc - initialize accumulator to zero
  - `uio_in[2]`: load_scale_low - load scale[7:0] from ui_in
  - `uio_in[3]`: load_scale_high - load scale[15:8] from ui_in
  - `uio_in[4]`: vector_mode - output FP4 scaled result
- **Pipeline Latency**: 2 clock cycles from data_valid to accumulator update
- **Clock**: Free-running clock required (10-50 MHz recommended)
- **Scale Factor**: 16-bit FP16, default 1.0 (0x3C00)

## How to test

The design uses a **free-running clock** with control signals for proper operation:

### MAC Operation Mode

1. **Connect a continuous clock** to `clk` (recommended: 10-50 MHz)

2. **Initialize the accumulator**:
   - Set `uio_in[1] = 1` (reset_acc) for 1 clock cycle
   - This loads zero into the accumulator
   - Set `uio_in[1] = 0` to return to normal operation

3. **Perform MAC operations**:
   - Set `ui_in[3:0]` = Activation value (FP4)
   - Set `ui_in[7:4]` = Weight value (FP4)
   - Pulse `uio_in[0] = 1` for 1 cycle (data_valid)
   - Wait 2 cycles for pipeline
   - Repeat for multiple MAC operations

4. **Read accumulator** (optional):
   - Keep `uio_in[4] = 0` (vector_mode off)
   - Read `uo_out[7:0]` for accumulator lower 8 bits

### Vector Unit Mode

5. **Load scale factor** (16-bit FP16):
   - Set `ui_in[7:0]` = scale_factor[7:0] (low byte)
   - Pulse `uio_in[2] = 1` for 1 cycle (load_scale_low)
   - Set `ui_in[7:0]` = scale_factor[15:8] (high byte)
   - Pulse `uio_in[3] = 1` for 1 cycle (load_scale_high)
   - Can load both bytes in same cycle if desired
   
6. **Enable vector output**:
   - Set `uio_in[4] = 1` (vector_mode)
   - Read `uo_out[3:0]` for FP4 scaled result
   - Result = (accumulator × scale_factor) quantized to FP4

### Example Test Sequence

```
Cycle 0: uio_in[1] = 1                (reset accumulator to 0)
Cycle 1: uio_in[1] = 0                (release reset)
Cycle 2: ui_in = 0x11, uio_in[0] = 1  (start: a=0x1, w=0x1)
Cycle 3: uio_in[0] = 0                (disable, let pipeline process)
Cycle 4: Read uo_out                  (accumulator = 1×1)
Cycle 5: ui_in = 0x23, uio_in[0] = 1  (start: a=0x3, w=0x2)
Cycle 6: uio_in[0] = 0                (disable)
Cycle 7: Read uo_out                  (accumulator = 1×1 + 3×2)
...
```

**Key Points:**
- Use a **free-running clock** (not manual pulsing) to avoid timing issues
- The `data_valid` signal controls when new data is processed
- Pipeline latency is 2 cycles from data_valid assertion to accumulator update

## External hardware

No external hardware required. The design can be tested with:
- Logic analyzer or oscilloscope to observe outputs
- Microcontroller or FPGA to generate test patterns
- Simple GPIO bit-banging for manual testing
