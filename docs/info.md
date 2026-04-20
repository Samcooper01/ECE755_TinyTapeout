<!---

This file is used to generate your project datasheet. Please fill in the information below and delete any unused
sections.

You can also include images in this folder and reference them in the markdown. Each image must be less than
512 kb in size, and the combined size of all images must be less than 1 MB.
-->

## How it works

This project implements a single Processing Element (PE) from a GEMM (General Matrix Multiply) systolic array. The PE performs multiply-accumulate (MAC) operations using custom floating-point arithmetic:

- **FP4 Multiplier**: Multiplies 4-bit floating-point activation and weight inputs
- **FP16 Adder**: Accumulates results in 16-bit floating-point format
- **2-Stage Pipeline**: Fully pipelined design for maximum throughput
  - Stage 1: FP4 multiplication
  - Stage 2: FP16 addition/accumulation

The design continuously performs MAC operations: `accumulator += activation × weight`

### Architecture Details

- **Input**: 8 pins total (4 bits activation + 4 bits weight)
- **Output**: 8 pins showing lower byte of 16-bit accumulator
- **Pipeline Latency**: 2 clock cycles from input to accumulator update
- **Control**: Always-enabled (continuous operation)
- **Bias**: Hardwired to zero (pure MAC operation)

## How to test

The design operates as a simple synchronous circuit - no complex protocol needed:

1. **Apply inputs** on `ui_in[7:0]`:
   - `ui_in[3:0]` = Activation value (FP4 format)
   - `ui_in[7:4]` = Weight value (FP4 format)

2. **Wait 2 clock cycles** for pipeline latency

3. **Read accumulator output** on `uo_out[7:0]`:
   - Lower 8 bits of 16-bit FP16 accumulator

4. **Change inputs** every cycle to perform continuous MAC operations

### Example Test Sequence

```
Cycle 0: Set ui_in = 0x11 (a=0x1, w=0x1)
Cycle 2: Read uo_out (accumulator += 1×1)
Cycle 3: Set ui_in = 0x23 (a=0x3, w=0x2)
Cycle 5: Read uo_out (accumulator += 3×2)
...
```

The accumulator continuously adds new multiply results to the previous sum.

## External hardware

No external hardware required. The design can be tested with:
- Logic analyzer or oscilloscope to observe outputs
- Microcontroller or FPGA to generate test patterns
- Simple GPIO bit-banging for manual testing
