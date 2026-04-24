#!/bin/bash
#==============================================================================
# TinyTapeout GEMM PE Simulation Script
# Compiles and runs the testbench using Icarus Verilog
#==============================================================================

set -e  # Exit on error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Parse command line arguments
TEST_SELECT=""
SHOW_HELP=0

while [[ $# -gt 0 ]]; do
    case $1 in
        -t|--test)
            TEST_SELECT="$2"
            shift 2
            ;;
        -h|--help)
            SHOW_HELP=1
            shift
            ;;
        *)
            echo -e "${RED}Unknown option: $1${NC}"
            SHOW_HELP=1
            shift
            ;;
    esac
done

# Show help if requested
if [ $SHOW_HELP -eq 1 ]; then
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  -t, --test <tc>   Run specific test case (tc1-tc9)"
    echo "  -h, --help        Show this help message"
    echo ""
    echo "Test Cases:"
    echo "  tc1 - Basic MAC Operation"
    echo "  tc2 - Multiple MAC with Accumulation"
    echo "  tc3 - Scale Factor Loading"
    echo "  tc4 - Vector Mode Output"
    echo "  tc5 - Accumulator Reset"
    echo "  tc6 - Corner Cases"
    echo "  tc7 - Control Signal Synchronization"
    echo "  tc8 - Pipeline Behavior"
    echo "  tc9 - Full System Integration"
    echo ""
    echo "Examples:"
    echo "  $0              # Run all tests"
    echo "  $0 -t tc1       # Run only TC1"
    echo "  $0 --test tc3   # Run only TC3"
    exit 0
fi

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}TinyTapeout GEMM PE Verification${NC}"
echo -e "${BLUE}========================================${NC}"
if [ -n "$TEST_SELECT" ]; then
    echo -e "${BLUE}Running: $TEST_SELECT only${NC}"
else
    echo -e "${BLUE}Running: All tests${NC}"
fi
echo ""

# Check if iverilog is installed
if ! command -v iverilog &> /dev/null; then
    echo -e "${RED}Error: iverilog not found!${NC}"
    echo "Please install Icarus Verilog:"
    echo "  Ubuntu/Debian: sudo apt-get install iverilog"
    echo "  macOS: brew install icarus-verilog"
    exit 1
fi

# Check if vvp is installed
if ! command -v vvp &> /dev/null; then
    echo -e "${RED}Error: vvp not found!${NC}"
    echo "Please install Icarus Verilog (includes vvp)"
    exit 1
fi

# Clean previous build
echo -e "${YELLOW}Cleaning previous build...${NC}"
make -f Makefile_iverilog clean 2>/dev/null || true
echo ""

# Compile
echo -e "${YELLOW}Compiling testbench and RTL...${NC}"
if make -f Makefile_iverilog compile; then
    echo -e "${GREEN}✓ Compilation successful${NC}"
    echo ""
else
    echo -e "${RED}✗ Compilation failed${NC}"
    exit 1
fi

# Run simulation
echo -e "${YELLOW}Running simulation...${NC}"
echo ""
if [ -n "$TEST_SELECT" ]; then
    # Run specific test
    if make -f Makefile_iverilog sim-$TEST_SELECT; then
        echo ""
        echo -e "${GREEN}✓ Simulation complete${NC}"
        echo ""
    else
        echo ""
        echo -e "${RED}✗ Simulation failed${NC}"
        exit 1
    fi
else
    # Run all tests
    if make -f Makefile_iverilog sim; then
        echo ""
        echo -e "${GREEN}✓ Simulation complete${NC}"
        echo ""
    else
        echo ""
        echo -e "${RED}✗ Simulation failed${NC}"
        exit 1
    fi
fi

# Check if waveform was generated
if [ -f "waves/tb_tt_um_example.vcd" ]; then
    echo -e "${GREEN}✓ Waveform generated: waves/tb_tt_um_example.vcd${NC}"
    echo ""
    echo "To view waveforms, run:"
    echo -e "  ${BLUE}make -f Makefile_iverilog wave${NC}"
    echo "  or"
    echo -e "  ${BLUE}gtkwave waves/tb_tt_um_example.vcd${NC}"
else
    echo -e "${YELLOW}⚠ No waveform file generated${NC}"
fi

echo ""
echo -e "${BLUE}========================================${NC}"
echo -e "${GREEN}Verification Complete!${NC}"
echo -e "${BLUE}========================================${NC}"

# Made with Bob
