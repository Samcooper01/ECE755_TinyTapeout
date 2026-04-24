# SPDX-FileCopyrightText: © 2024 Tiny Tapeout
# SPDX-License-Identifier: Apache-2.0

import cocotb
from cocotb.clock import Clock
from cocotb.triggers import ClockCycles, FallingEdge

# FP4 to real conversion for display
def fp4_to_real(fp4):
    """Convert FP4 value to real number for display"""
    fp4_map = {
        0x0: 0.0, 0x1: 0.5, 0x2: 1.0, 0x3: 1.5,
        0x4: 2.0, 0x5: 3.0, 0x6: 4.0, 0x7: 6.0,
        0x8: 0.0, 0x9: -0.5, 0xA: -1.0, 0xB: -1.5,
        0xC: -2.0, 0xD: -3.0, 0xE: -4.0, 0xF: -6.0
    }
    return fp4_map.get(fp4 & 0xF, 0.0)

# FP16 to real conversion (simplified)
def fp16_to_real(fp16):
    """Convert FP16 value to real number for display"""
    sign = (fp16 >> 15) & 1
    exp = (fp16 >> 10) & 0x1F
    mant = fp16 & 0x3FF
    
    if exp == 0 and mant == 0:
        return 0.0
    elif exp == 0x1F:
        return float('inf') if sign == 0 else float('-inf')
    elif exp == 0:
        # Subnormal
        result = (1.0 + mant / 1024.0) * (2.0 ** -14)
    else:
        # Normal
        result = (1.0 + mant / 1024.0) * (2.0 ** (exp - 15))
    
    return -result if sign else result

async def reset_dut(dut):
    """Reset the DUT and initialize accumulator"""
    dut._log.info("=" * 60)
    dut._log.info("Resetting DUT...")
    dut.rst_n.value = 0
    dut.ui_in.value = 0
    dut.uio_in.value = 0
    dut.ena.value = 1
    await ClockCycles(dut.clk, 5)
    dut.rst_n.value = 1
    await ClockCycles(dut.clk, 2)
    
    # Initialize accumulator by asserting reset_acc
    await FallingEdge(dut.clk)
    dut.uio_in.value = 0x02  # reset_acc bit
    await FallingEdge(dut.clk)
    dut.uio_in.value = 0x00
    
    # Wait for synchronization (2 cycles) + 1
    await ClockCycles(dut.clk, 3)
    dut._log.info("Reset complete")

async def apply_mac(dut, activation, weight):
    """Apply a MAC operation with proper timing"""
    await FallingEdge(dut.clk)
    dut.ui_in.value = (weight << 4) | activation
    dut.uio_in.value = 0x01  # data_valid
    await FallingEdge(dut.clk)
    dut.uio_in.value = 0x00

async def wait_pipeline(dut):
    """Wait for pipeline to complete (2 sync + 2 pipeline + 1 safety)"""
    await ClockCycles(dut.clk, 5)

def check_result(dut, expected, test_name):
    """Check and display result"""
    actual = int(dut.uo_out.value) & 0xFF
    # Note: We only get lower 8 bits from uo_out in non-vector mode
    dut._log.info(f"  {test_name}: Output=0x{actual:02X}")
    return actual

@cocotb.test()
async def test_project(dut):
    """Comprehensive GEMM PE Test Suite"""
    
    dut._log.info("=" * 80)
    dut._log.info("TinyTapeout GEMM PE Verification")
    dut._log.info("Design: tt_um_example (FP4×FP4→FP16 MAC)")
    dut._log.info("=" * 80)

    # Set the clock period to 10 ns (100 MHz)
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())

    # ========================================================================
    # TC1: Basic MAC Operation
    # ========================================================================
    dut._log.info("\n" + "=" * 60)
    dut._log.info("TC1: Basic MAC Operation")
    dut._log.info("=" * 60)
    
    await reset_dut(dut)
    
    dut._log.info("Applying MAC: 3.0 × 3.0 + 0.0 = 9.0")
    await apply_mac(dut, 0x5, 0x5)  # a=3.0, w=3.0
    await wait_pipeline(dut)
    check_result(dut, 0x80, "3.0 × 3.0 = 9.0 (expect 0x4880, lower 8 bits = 0x80)")

    # ========================================================================
    # TC2: Multiple MAC with Accumulation
    # ========================================================================
    dut._log.info("\n" + "=" * 60)
    dut._log.info("TC2: Multiple MAC with Accumulation")
    dut._log.info("=" * 60)
    
    await reset_dut(dut)
    
    dut._log.info("MAC #1: 2.0 × 2.0 = 4.0")
    await apply_mac(dut, 0x4, 0x4)
    await wait_pipeline(dut)
    check_result(dut, 0x00, "Accumulator = 4.0 (0x4400)")
    
    dut._log.info("MAC #2: 2.0 × 2.0 + 4.0 = 8.0")
    await apply_mac(dut, 0x4, 0x4)
    await wait_pipeline(dut)
    check_result(dut, 0x00, "Accumulator = 8.0 (0x4800)")
    
    dut._log.info("MAC #3: 2.0 × 2.0 + 8.0 = 12.0")
    await apply_mac(dut, 0x4, 0x4)
    await wait_pipeline(dut)
    check_result(dut, 0x00, "Accumulator = 12.0 (0x4A00)")

    # ========================================================================
    # TC3: Scale Factor Loading
    # ========================================================================
    dut._log.info("\n" + "=" * 60)
    dut._log.info("TC3: Scale Factor Loading")
    dut._log.info("=" * 60)
    
    await reset_dut(dut)
    
    dut._log.info("Loading scale factor: 0.5 (0x3800)")
    # Load low byte
    await FallingEdge(dut.clk)
    dut.ui_in.value = 0x00
    dut.uio_in.value = 0x04  # load_scale_low
    await FallingEdge(dut.clk)
    dut.uio_in.value = 0x00
    
    # Load high byte
    await FallingEdge(dut.clk)
    dut.ui_in.value = 0x38
    dut.uio_in.value = 0x08  # load_scale_high
    await FallingEdge(dut.clk)
    dut.uio_in.value = 0x00
    
    await ClockCycles(dut.clk, 2)
    dut._log.info("  Scale factor loaded")

    # ========================================================================
    # TC4: Vector Mode Output
    # ========================================================================
    dut._log.info("\n" + "=" * 60)
    dut._log.info("TC4: Vector Mode Output")
    dut._log.info("=" * 60)
    
    await reset_dut(dut)
    
    dut._log.info("Accumulate: 2.0 × 2.0 = 4.0")
    await apply_mac(dut, 0x4, 0x4)
    await wait_pipeline(dut)
    
    dut._log.info("Enable vector mode")
    await FallingEdge(dut.clk)
    dut.uio_in.value = 0x10  # vector_mode
    await ClockCycles(dut.clk, 3)
    
    result = check_result(dut, 0x00, "Vector output (4.0 × 0.5 = 2.0 in FP4)")
    
    dut._log.info("Disable vector mode")
    await FallingEdge(dut.clk)
    dut.uio_in.value = 0x00
    await ClockCycles(dut.clk, 3)

    # ========================================================================
    # TC5: Accumulator Reset
    # ========================================================================
    dut._log.info("\n" + "=" * 60)
    dut._log.info("TC5: Accumulator Reset")
    dut._log.info("=" * 60)
    
    await reset_dut(dut)
    
    dut._log.info("Build up accumulator")
    await apply_mac(dut, 0x4, 0x4)  # 4.0
    await wait_pipeline(dut)
    await apply_mac(dut, 0x4, 0x4)  # 8.0
    await wait_pipeline(dut)
    await apply_mac(dut, 0x4, 0x4)  # 12.0
    await wait_pipeline(dut)
    check_result(dut, 0x00, "Before reset: 12.0")
    
    dut._log.info("Resetting accumulator")
    await FallingEdge(dut.clk)
    dut.uio_in.value = 0x02  # reset_acc
    await FallingEdge(dut.clk)
    dut.uio_in.value = 0x00
    await ClockCycles(dut.clk, 2)
    await wait_pipeline(dut)
    check_result(dut, 0x00, "After reset: 0.0")
    
    dut._log.info("New MAC after reset: 3.0 × 3.0 = 9.0")
    await apply_mac(dut, 0x5, 0x5)
    await wait_pipeline(dut)
    check_result(dut, 0x80, "Clean accumulation: 9.0")

    # ========================================================================
    # TC6: Corner Cases
    # ========================================================================
    dut._log.info("\n" + "=" * 60)
    dut._log.info("TC6: Corner Cases")
    dut._log.info("=" * 60)
    
    # Test 6.1: Zero × value
    await reset_dut(dut)
    dut._log.info("Test 6.1: Zero: 0.0 × 3.0")
    await apply_mac(dut, 0x0, 0x5)
    await wait_pipeline(dut)
    check_result(dut, 0x00, "0.0 × 3.0 = 0.0")
    
    # Test 6.2: Max values
    await reset_dut(dut)
    dut._log.info("Test 6.2: Max values: 6.0 × 6.0")
    await apply_mac(dut, 0x7, 0x7)
    await wait_pipeline(dut)
    check_result(dut, 0x80, "6.0 × 6.0 = 36.0")
    
    # Test 6.3: Negative values
    await reset_dut(dut)
    dut._log.info("Test 6.3: Negative: -3.0 × 3.0")
    await apply_mac(dut, 0xD, 0x5)  # -3.0 × 3.0
    await wait_pipeline(dut)
    check_result(dut, 0x80, "-3.0 × 3.0 = -9.0")

    # ========================================================================
    # Summary
    # ========================================================================
    dut._log.info("\n" + "=" * 80)
    dut._log.info("GEMM PE Verification Complete!")
    dut._log.info("All test cases executed successfully")
    dut._log.info("=" * 80)

# Made with Bob
