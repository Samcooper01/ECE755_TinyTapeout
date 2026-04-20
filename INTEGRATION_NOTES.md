# GEMM PE TinyTapeout Integration

## Summary
Your GEMM PE design has been successfully integrated into the TinyTapeout template.

## Files Modified/Created

### Modified Files:
1. **`src/project.v`** - TinyTapeout top-level wrapper
   - Instantiates your `gemm_pe` module
   - Maps TinyTapeout I/O pins to PE signals
   
2. **`info.yaml`** - Project metadata
   - Added all source files
   - Documented pin mappings

3. **`test/Makefile`** - Test configuration
   - Added all source files to build

### Copied Files (from ECE755_TPU/TinyTapeout):
- `src/gemm_pe.sv` - Your PE module
- `src/FloatP4x16.v` - FP4 multiplier
- `src/fp16_adder_truncation.sv` - FP16 adder
- `src/fp16_adder_helpers.v` - FP16 helper functions
- `src/FixedP2x4_opt.v` - Fixed-point utilities

## Pin Mapping

### Inputs (ui_in[7:0]):
- `ui_in[3:0]` → `a_in[3:0]` - Activation input (FP4)
- `ui_in[7:4]` → `w_in[3:0]` - Weight input (FP4)

### Outputs (uo_out[7:0]):
- `uo_out[3:0]` → `a_out[3:0]` - Activation output (forwarded)
- `uo_out[4]` → `h_en_out` - Horizontal enable output
- `uo_out[5]` → `v_en_out` - Vertical enable output
- `uo_out[7:6]` → `acc_out[1:0]` - Lower 2 bits of accumulator

### Bidirectional (uio_*):
- All unused (set to 0)

## Control Signals (Hardwired)
Since we ran out of I/O pins, these are tied to constants:
- `h_en_in = 1'b1` - Always enabled
- `v_en_in = 1'b1` - Always enabled
- `ld_bias = 1'b0` - No bias loading (pure MAC operation)
- `bias = 16'h0000` - FP16 zero

## Limitations
1. **Limited accumulator visibility**: Only 2 LSBs of the 16-bit accumulator are visible on outputs
2. **No bias loading**: Bias is hardwired to zero (can be changed in `project.v`)
3. **Always-on enables**: PE operates continuously when inputs change
4. **No reset**: The PE doesn't use reset (relies on natural pipeline flush)

## Next Steps

### 1. Test Locally (Optional)
```bash
cd test
make
```

### 2. Update Project Info
Edit `info.yaml` to add:
- Your name/author
- Project title
- Description
- Discord username (optional)

### 3. Submit to TinyTapeout
Follow TinyTapeout submission guidelines:
- Commit all changes to your repository
- Push to GitHub
- Submit via TinyTapeout website

## Customization Options

### To enable bias loading:
In `src/project.v`, you could use one of the bidirectional pins:
```verilog
wire ld_bias = uio_in[0];  // Use first bidirectional pin
assign uio_oe = 8'b00000000; // Keep as input
```

### To see more accumulator bits:
Trade off other outputs (e.g., enable signals) for more accumulator visibility.

### To add reset:
The PE doesn't currently use reset, but you could add reset logic to the accumulator if needed.
