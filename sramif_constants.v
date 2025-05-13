// sram interface base address
//`define SRAMIF_BASE_ADDR 32'h50000000
`define SRAMIF_BASE_ADDR 32'h83800000

// data sram interface
`define DATA_SLICE_LHS 31
`define DATA_SLICE_RHS 22

// command sram address base, address range
// 5040_0000 ~ 5040_0fff
`define CMD_BASE_ADDR (`SRAMIF_BASE_ADDR + 32'h400000)
`define CMD_SLICE_LHS 31
`define CMD_SLICE_RHS 12

// npu register address base, address range
// 5040_1000 ~ 5040_107f
`define NPUREG_BASE_ADDR (`SRAMIF_BASE_ADDR + 32'h401000)
`define NPUREG_SLICE_LHS 31
`define NPUREG_SLICE_RHS 7

// lut address base, address range
// 5042_0000 ~ 5043_ffff
`define LUT_BASE_ADDR (`SRAMIF_BASE_ADDR + 32'h420000)
`define LUT_SLICE_LHS 31
`define LUT_SLICE_RHS 17

// shift address base, address range
// 5040_1800 ~ 5040_1fff
`define SHIFT_BASE_ADDR (`SRAMIF_BASE_ADDR + 32'h401800)
`define SHIFT_SLICE_LHS 31
`define SHIFT_SLICE_RHS 11

// npu axi ctrl register address base, address range
// 50401080, range 32 word
`define CTRL_BASE_ADDR (`SRAMIF_BASE_ADDR + 32'h401080)
`define CTRL_SLICE_LHS 31
`define CTRL_SLICE_RHS 7
`define CTRL_FIFO_COUNTER 5'h0
`define CTRL_PRE          5'h1

// sram bank decoder
`define CH_LHS 4
`define CH_RHS 4
`define BANK_AB 20
`define BANK_ADDR_ST 19
`define BANK_ADDR_ED 16
`define INBANK_ADDR_ST 15
`define INBANK_ADDR_ED 5
