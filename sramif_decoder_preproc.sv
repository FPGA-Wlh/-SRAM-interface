`include "define.vh"
module sramif_decoder_preproc
(// Address inputs
 (* mark_debug = "true" *)  input  wire          val_write_i,
 input  wire [31:0]   val_wr_addr_i,
 input  wire [15:0]   val_wr_strb_i,
 input  wire [127:0]  val_wr_data_i,

 input  wire          val_read_i,
 input  wire [31:0]   val_rd_addr_i,
 output logic [127:0]  val_rd_data_o,
 output logic          val_rdata_valid,

  input wire        unpk_valid_i,

  // Clocks and resets
  input  wire                   clk,
  input  wire                   reset_n,

  // pre-process ip valid
  output logic                  preproc_valid,
  output logic   [1:0]                pre_type,
  output logic                        bvalid_delay        ,

 // srambank ctrl and addr
    output logic [1:0][15:0]               bankA_dma_cs        ,
    output logic [1:0][15:0]               bankA_dma_we        ,
    output logic [1:0][15:0][10:0]         bankA_dma_addr      , 
    output logic [1:0][15:0][127:0]        bankA_dma_din       , 
    output logic [1:0][15:0][15:0]         bankA_dma_byte_en   ,
    input        [1:0][15:0][127:0]        bankA_dma_dout      , 
    output logic [1:0][15:0]               bankB_dma_cs        ,
    output logic [1:0][15:0]               bankB_dma_we        ,
    output logic [1:0][15:0][10:0]         bankB_dma_addr      , 
    output logic [1:0][15:0][127:0]        bankB_dma_din       , 
    output logic [1:0][15:0][15:0]         bankB_dma_byte_en   ,
    input        [1:0][15:0][127:0]        bankB_dma_dout
);

localparam WRITETHROUGH = 2'd0;
localparam SHIFT        = 2'd1;
localparam SHIFTADD     = 2'd2;
localparam BANK_NUM     = 3'd2;
localparam RD_IDX_WIDTH = 8'd64;

logic w_data_en;    // write data sram enable
logic r_data_en;    // read  data sram enable
logic r_data_en_d1;
logic r_data_en_d2;
logic [31:0]  val_rd_addr_i_reg;
logic [31:0]  val_rd_addr_i_d2;
logic [31:0]  val_wr_addr_i_reg;

// preprocess register field
(* mark_debug = "true" *) logic [1:0]  preproc_type;
logic [17:0] channelgroup;
logic        chlgrp_clear;
logic [1:0]  ppt_wire;    // axi write register value
logic [17:0] cg_wire;     // axi write register value
logic        cgc_wire;    // axi write register value
(* mark_debug = "true" *) logic        w_reg_en;
logic        r_reg_en;
logic        r_reg_en_d1;
logic        r_reg_en_d2;

// val_write_i delay 1/2/3 cycles for shift_add
logic w_data_en_d1;
logic w_data_en_d2;
logic w_data_en_d3;
logic w_data_en_d4;

logic [31:0]   val_wr_addr_d1;
logic [15:0]   val_wr_strb_d1;
logic [127:0]  val_wr_data_d1;

// shift sram signal
logic cs;
logic we;
logic [15:0] byte_en;
logic [6:0]  addr;
logic [127:0] shift_din;
logic [127:0] shift_dout;
logic [2:0]  bcnt;

logic w_shift_en;
logic w_shift_en_d1;
logic r_shift_en;
logic r_shift_en_d1;
logic r_shift_en_d2;

// channel group count for x*y
logic [17:0] cg_count;
logic [2:0]  ch_count;
logic [2:0]  ch_count_d1;
// shift value register
logic [127:0] shift_reg1;
logic [127:0] shift_reg2;
// shift sram address
logic [6:0]  shift_addr;
// preprocess ip read shift sram
logic        shift_valid1;
logic        shift_valid2;
logic        shift_valid1_d1;
logic        shift_valid2_d1;

logic [127:0] sram_data_b;

// shift value A and B
logic [7:0][15:0] data_a_after_shift;
logic [127:0] data_a_after_shift_w;
logic [7:0][15:0] data_a_after_shift_d1;
logic [7:0][15:0] data_a_after_shift_d2;
logic [7:0][15:0] data_a_after_shift_d3;
logic [7:0][15:0] data_b_after_shift;
// logic [127:0] data_b_after_shift;
logic [7:0][3:0]  shift_val1;
logic [7:0][3:0]  shift_val2;
logic [7:0][15:0] val_w_temp;

// sram read data
logic [7:0][15:0] val_r_temp;

// shift add result
logic [7:0][16:0] shift_add_result_temp;
logic [7:0][15:0] shift_add_result;
logic [127:0]     shift_add_result_w;

// base address
logic [31:0]  pre_ctrl_base_addr;
logic [31:0]  data_base_addr;
logic [31:0]  shift_base_addr;

// register write
// address, strobe, data, unaligned data
// to verify
// register write enable
// address = ?? // smaller or larger
  assign pre_ctrl_base_addr = `CTRL_BASE_ADDR;
  assign w_reg_en  = val_write_i  & (val_wr_addr_i[`CTRL_SLICE_LHS:`CTRL_SLICE_RHS] == pre_ctrl_base_addr[`CTRL_SLICE_LHS:`CTRL_SLICE_RHS]) & (val_wr_addr_i[`CTRL_SLICE_RHS-1:2] == `CTRL_PRE);
  assign r_reg_en  = val_read_i  & (val_rd_addr_i[`CTRL_SLICE_LHS:`CTRL_SLICE_RHS] == pre_ctrl_base_addr[`CTRL_SLICE_LHS:`CTRL_SLICE_RHS]) & (val_rd_addr_i[`CTRL_SLICE_RHS-1:2] == `CTRL_PRE);

always_ff @(posedge clk or negedge reset_n) begin
    if(!reset_n)   r_reg_en_d1  <= 1'b0;
    else           r_reg_en_d1  <= r_reg_en;
end
always_ff @(posedge clk or negedge reset_n) begin
    if(!reset_n)   r_reg_en_d2  <= 1'b0;
    else           r_reg_en_d2  <= r_reg_en_d1;
end

always_ff @(posedge clk or negedge reset_n) begin
    if(!reset_n)   preproc_type <= 2'd0;
    else if(w_reg_en) preproc_type <= ppt_wire;
end
assign pre_type = preproc_type;

always_ff @(posedge clk or negedge reset_n) begin
    if(!reset_n)   channelgroup <= 18'h0;
    else if(cgc_wire)
                   channelgroup <= 18'h0;
    else if(w_reg_en) channelgroup <= cg_wire;
end

// delay one cycle
always_ff @(posedge clk or negedge reset_n) begin
    if(!reset_n)   val_wr_addr_d1  <= 32'b0;
    else           val_wr_addr_d1  <= val_wr_addr_i;
end
always_ff @(posedge clk or negedge reset_n) begin
    if(!reset_n)   val_wr_strb_d1  <= 16'b0;
    else           val_wr_strb_d1  <= val_wr_strb_i;
end
always_ff @(posedge clk or negedge reset_n) begin
    if(!reset_n)   val_wr_data_d1  <= 128'b0;
    else           val_wr_data_d1  <= val_wr_data_i;
end

// register write value
// address = 0x5040_1084 and write valid
assign {cgc_wire, cg_wire, ppt_wire} = w_reg_en ? val_wr_data_i[52:32] : 21'h0;

  // write is priority to read when to the same bank
  assign data_base_addr = `SRAMIF_BASE_ADDR;
  assign w_data_en = val_write_i & (val_wr_addr_i[`DATA_SLICE_LHS:`DATA_SLICE_RHS] == data_base_addr[`DATA_SLICE_LHS:`DATA_SLICE_RHS]);
  assign r_data_en = val_read_i & (val_rd_addr_i[`DATA_SLICE_LHS:`DATA_SLICE_RHS] == data_base_addr[`DATA_SLICE_LHS:`DATA_SLICE_RHS]);

always_ff @(posedge clk or negedge reset_n) begin
    if(!reset_n)   r_data_en_d1  <= 1'b0;
    else           r_data_en_d1  <= r_data_en;
end
always_ff @(posedge clk or negedge reset_n) begin
    if(!reset_n)   r_data_en_d2  <= 1'b0;
    else           r_data_en_d2  <= r_data_en_d1;
end

always_ff @(posedge clk or negedge reset_n) begin
    if(!reset_n)   val_rd_addr_i_reg <= 32'h0;
    else           val_rd_addr_i_reg <= val_rd_addr_i;
end
always_ff @(posedge clk or negedge reset_n) begin
    if(!reset_n)   val_rd_addr_i_d2 <= 32'h0;
    else           val_rd_addr_i_d2 <= val_rd_addr_i_reg;
end

always_ff @(posedge clk or negedge reset_n) begin
    if(!reset_n)   val_wr_addr_i_reg <= 32'h0;
    else           val_wr_addr_i_reg <= val_wr_addr_i;
end

always_ff @(posedge clk or negedge reset_n) begin
    if(!reset_n) begin
        w_data_en_d1  <= 1'b0;
        w_data_en_d2  <= 1'b0;
        w_data_en_d3  <= 1'b0;
        w_data_en_d4  <= 1'b0;
    end
    else begin
        w_data_en_d1  <= w_data_en;
        w_data_en_d2  <= w_data_en_d1;
        w_data_en_d3  <= w_data_en_d2;
        w_data_en_d4  <= w_data_en_d3;
    end
end

//*****************************************
// data sram cs/we/addr/din/strb
//*****************************************
// address control constants
logic [15:0][3:0] bank_addr;
assign bank_addr  = 64'hfedc_ba98_7654_3210;
logic [1:0] bank_index;
assign bank_index = 2'b10;

// data sram cs
genvar ibank;
genvar ics;
generate
for(ibank=0;ibank<BANK_NUM;ibank++) begin : bankA_cs_gen_bank
    for(ics=0;ics<16;ics++) begin : bankA_cs_gen
        always_ff @(posedge clk or negedge reset_n) begin
            if(!reset_n) begin
                bankA_dma_cs[ibank][ics] <= 1'b0;
            end else begin
                bankA_dma_cs[ibank][ics] <= (((bank_index[ibank] == val_rd_addr_i[`CH_LHS:`CH_RHS])
                && val_rd_addr_i[`BANK_AB] == 1'b0 && val_rd_addr_i[`BANK_ADDR_ST:`BANK_ADDR_ED]==bank_addr[ics] && r_data_en)
                || ((bank_index[ibank] == val_wr_addr_i[`CH_LHS:`CH_RHS] && val_wr_addr_i[`BANK_AB] == 1'b0 
                && val_wr_addr_i[`BANK_ADDR_ST:`BANK_ADDR_ED]==bank_addr[ics])
                && (w_data_en || (w_data_en_d3 && preproc_type == SHIFTADD))))  ? 1'b1 : 1'b0;
            end
        end
    end
end
endgenerate

// data sram we
genvar iwe;
generate
for(ibank=0;ibank<BANK_NUM;ibank++) begin : bankA_we_gen_bank
    for(iwe=0;iwe<16;iwe++) begin : bankA_we_gen
        always_ff @(posedge clk or negedge reset_n) begin
            if(!reset_n) begin
                bankA_dma_we[ibank][iwe] <= 1'b0;
            end else begin
                bankA_dma_we[ibank][iwe] <= ((bank_index[ibank] == val_wr_addr_i[`CH_LHS:`CH_RHS] 
                && val_wr_addr_i[`BANK_AB] == 1'b0 && val_wr_addr_i[`BANK_ADDR_ST:`BANK_ADDR_ED]==bank_addr[iwe])
                && ((w_data_en && preproc_type != SHIFTADD) || (w_data_en_d3 && preproc_type == SHIFTADD))) ? 1'b1 : 1'b0;
            end
        end
    end
end
endgenerate

// data sram addr
genvar iaddr;
generate
for(ibank=0;ibank<BANK_NUM;ibank++) begin : bankA_addr_gen_bank
    for(iaddr=0;iaddr<16;iaddr++) begin : bankA_addr_gen
        always_ff @(posedge clk or negedge reset_n) begin
            if(!reset_n) begin
                bankA_dma_addr[ibank][iaddr] <= 11'b0;
            end else begin
                bankA_dma_addr[ibank][iaddr] <= (val_rd_addr_i[`BANK_AB] == 1'b0 
                    && bank_index[ibank] == val_rd_addr_i[`CH_LHS:`CH_RHS]
                    && val_rd_addr_i[`BANK_ADDR_ST:`BANK_ADDR_ED]==bank_addr[iaddr] && r_data_en)
                ? val_rd_addr_i[`INBANK_ADDR_ST:`INBANK_ADDR_ED] :
                    ((val_wr_addr_i[`BANK_AB] == 1'b0 && val_wr_addr_i[`BANK_ADDR_ST:`BANK_ADDR_ED]==bank_addr[iaddr])
                    && bank_index[ibank] == val_wr_addr_i[`CH_LHS:`CH_RHS]
                    && (w_data_en || (w_data_en_d3 && preproc_type == SHIFTADD))) 
                ? val_wr_addr_i[`INBANK_ADDR_ST:`INBANK_ADDR_ED] : 11'h0;
            end
        end
    end
end
endgenerate

// data sram din
genvar idin, ibit;
generate
for(ibank=0;ibank<BANK_NUM;ibank++) begin : bankA_din_gen_bank
    for(idin=0;idin<16;idin++) begin : bankA_din_gen
        for(ibit=0;ibit<128;ibit++) begin : bankA_din_bit_gen
            always_ff @(posedge clk or negedge reset_n) begin
                if(!reset_n) begin
                    bankA_dma_din[ibank][idin][ibit] <= 1'b0;
                end else if (val_wr_addr_i[`BANK_AB] == 1'b0
                    && val_wr_addr_i[`BANK_ADDR_ST:`BANK_ADDR_ED]==bank_addr[idin]) begin
                    bankA_dma_din[ibank][idin][ibit] <= 
                        bank_index[ibank] == val_wr_addr_i[`CH_LHS:`CH_RHS]
                    ?  ((w_data_en && preproc_type == WRITETHROUGH)
                    ? val_wr_data_i[ibit] :
                        (w_data_en && preproc_type == SHIFT)
                    ? data_a_after_shift_w[ibit] :
                        (w_data_en_d3 && preproc_type == SHIFTADD)
                    ? shift_add_result_w[ibit] : 1'b0) : 1'b0;
                end else begin
                    bankA_dma_din[ibank][idin][ibit] <= 1'b0;
                end
            end
        end
    end
end
endgenerate

// data sram strb
genvar istrb, isbit;
generate
for(ibank=0;ibank<BANK_NUM;ibank++) begin : bankA_strb_gen_bank
    for(istrb=0;istrb<16;istrb++) begin : bankA_strb_gen
        for(isbit=0;isbit<16;isbit++) begin : bankA_strb_bit_gen
            always_ff @(posedge clk or negedge reset_n) begin
                if(!reset_n) begin
                    bankA_dma_byte_en[ibank][istrb][isbit] <= 1'b0;
                end else if (val_wr_addr_i[`BANK_AB] == 1'b0
                    && val_wr_addr_i[`BANK_ADDR_ST:`BANK_ADDR_ED]==bank_addr[istrb]) begin
                    bankA_dma_byte_en[ibank][istrb][isbit] <= 
                        bank_index[ibank] == val_wr_addr_i[`CH_LHS:`CH_RHS]
                        ?  (((w_data_en && preproc_type == WRITETHROUGH)
                            || (w_data_en && preproc_type == SHIFT)
                            || (w_data_en_d3 && preproc_type == SHIFTADD))
                        ? val_wr_strb_i[isbit] : 1'b0) : 1'b0;
                end else begin
                    bankA_dma_byte_en[ibank][istrb][isbit] <= 1'b0;
                end
            end
        end
    end
end
endgenerate


//*****************************************
// data sram bankB cs/we/addr/din/strb
//*****************************************
// data sram cs
genvar ibcs;
generate
for(ibank=0;ibank<BANK_NUM;ibank++) begin : bankB_cs_gen_bank
    for(ibcs=0;ibcs<16;ibcs++) begin : bankB_cs_gen
        always_ff @(posedge clk or negedge reset_n) begin
            if(!reset_n) begin
                bankB_dma_cs[ibank][ibcs] <= 1'b0;
            end else begin
                bankB_dma_cs[ibank][ibcs] <= (((bank_index[ibank] == val_rd_addr_i[`CH_LHS:`CH_RHS])
                && val_rd_addr_i[`BANK_AB] == 1'b1 && val_rd_addr_i[`BANK_ADDR_ST:`BANK_ADDR_ED]==bank_addr[ibcs] && r_data_en)
                || ((bank_index[ibank] == val_wr_addr_i[`CH_LHS:`CH_RHS] && val_wr_addr_i[`BANK_AB] == 1'b1
                && val_wr_addr_i[`BANK_ADDR_ST:`BANK_ADDR_ED]==bank_addr[ibcs])
                && (w_data_en || (w_data_en_d3 && preproc_type == SHIFTADD))))  ? 1'b1 : 1'b0;
            end
        end
    end
end
endgenerate

// data sram we
genvar ibwe;
generate
for(ibank=0;ibank<BANK_NUM;ibank++) begin : bankB_we_gen_bank
    for(ibwe=0;ibwe<16;ibwe++) begin : bankB_we_gen
        always_ff @(posedge clk or negedge reset_n) begin
            if(!reset_n) begin
                bankB_dma_we[ibank][ibwe] <= 1'b0;
            end else begin
                bankB_dma_we[ibank][ibwe] <= ((bank_index[ibank] == val_wr_addr_i[`CH_LHS:`CH_RHS] 
                && val_wr_addr_i[`BANK_AB] == 1'b1 && val_wr_addr_i[`BANK_ADDR_ST:`BANK_ADDR_ED]==bank_addr[ibwe])
                && ((w_data_en && preproc_type != SHIFTADD) || (w_data_en_d3 && preproc_type == SHIFTADD))) ? 1'b1 : 1'b0;
            end
        end
    end
end
endgenerate

// data sram addr
genvar ibaddr;
generate
for(ibank=0;ibank<BANK_NUM;ibank++) begin : bankB_addr_gen_bank
    for(ibaddr=0;ibaddr<16;ibaddr++) begin : bankB_addr_gen
        always_ff @(posedge clk or negedge reset_n) begin
            if(!reset_n) begin
                bankB_dma_addr[ibank][ibaddr] <= 11'b0;
            end else begin
                bankB_dma_addr[ibank][ibaddr] <= (val_rd_addr_i[`BANK_AB] == 1'b1 
                    && bank_index[ibank] == val_rd_addr_i[`CH_LHS:`CH_RHS]
                    && val_rd_addr_i[`BANK_ADDR_ST:`BANK_ADDR_ED]==bank_addr[ibaddr] && r_data_en)
                ? val_rd_addr_i[`INBANK_ADDR_ST:`INBANK_ADDR_ED] :
                    ((val_wr_addr_i[`BANK_AB] == 1'b1 && val_wr_addr_i[`BANK_ADDR_ST:`BANK_ADDR_ED]==bank_addr[ibaddr])
                    && bank_index[ibank] == val_wr_addr_i[`CH_LHS:`CH_RHS]
                    && (w_data_en || (w_data_en_d3 && preproc_type == SHIFTADD))) 
                ? val_wr_addr_i[`INBANK_ADDR_ST:`INBANK_ADDR_ED] : 11'h0;
            end
        end
    end
end
endgenerate

// data sram din
genvar ibdin, ibbit;
generate
for(ibank=0;ibank<BANK_NUM;ibank++) begin : bankB_din_gen_bank
    for(ibdin=0;ibdin<16;ibdin++) begin : bankB_din_gen
        for(ibbit=0;ibbit<128;ibbit++) begin : bankB_din_bit_gen
            always_ff @(posedge clk or negedge reset_n) begin
                if(!reset_n) begin
                    bankB_dma_din[ibank][ibdin][ibbit] <= 1'b0;
                end else if (val_wr_addr_i[`BANK_AB] == 1'b1
                    && val_wr_addr_i[`BANK_ADDR_ST:`BANK_ADDR_ED]==bank_addr[ibdin]) begin
                    bankB_dma_din[ibank][ibdin][ibbit] <= 
                        bank_index[ibank] == val_wr_addr_i[`CH_LHS:`CH_RHS]
                    ?  ((w_data_en && preproc_type == WRITETHROUGH)
                    ? val_wr_data_i[ibbit] :
                        (w_data_en && preproc_type == SHIFT)
                    ? data_a_after_shift_w[ibbit] :
                        (w_data_en_d3 && preproc_type == SHIFTADD)
                    ? shift_add_result_w[ibbit] : 1'b0) : 1'b0;
                end else begin
                    bankB_dma_din[ibank][ibdin][ibbit] <= 1'b0;
                end
            end
        end
    end
end
endgenerate

// data sram strb
genvar ibstrb, ibsbit;
generate
for(ibank=0;ibank<BANK_NUM;ibank++) begin : bankB_strb_gen_bank
    for(ibstrb=0;ibstrb<16;ibstrb++) begin : bankB_strb_gen
        for(ibsbit=0;ibsbit<16;ibsbit++) begin : bankB_strb_bit_gen
            always_ff @(posedge clk or negedge reset_n) begin
                if(!reset_n) begin
                    bankB_dma_byte_en[ibank][ibstrb][ibsbit] <= 1'b0;
                end else if (val_wr_addr_i[`BANK_AB] == 1'b1
                    && val_wr_addr_i[`BANK_ADDR_ST:`BANK_ADDR_ED]==bank_addr[ibstrb]) begin
                    bankB_dma_byte_en[ibank][ibstrb][ibsbit] <= 
                        bank_index[ibank] == val_wr_addr_i[`CH_LHS:`CH_RHS]
                        ?  (((w_data_en && preproc_type == WRITETHROUGH)
                            || (w_data_en && preproc_type == SHIFT)
                            || (w_data_en_d3 && preproc_type == SHIFTADD))
                        ? val_wr_strb_i[ibsbit] : 1'b0) : 1'b0;
                end else begin
                    bankB_dma_byte_en[ibank][ibstrb][ibsbit] <= 1'b0;
                end
            end
        end
    end
end
endgenerate

// SRAM CONTROL SIGNAL
logic [RD_IDX_WIDTH:0] rd_idx_d2;
assign rd_idx_d2 = { {RD_IDX_WIDTH{1'b0}}, {1'b1} } << { {val_rd_addr_i_d2[`CH_LHS:`CH_RHS]},
    {val_rd_addr_i_d2[`BANK_AB]}, {val_rd_addr_i_d2[`BANK_ADDR_ST:`BANK_ADDR_ED]} };

always_comb begin
    val_rd_data_o = 128'h0;
    val_rdata_valid = 1'b0;
    //********************************
    // read data output delay one cycle
    //********************************
    if(r_data_en_d2 == 1'b1) begin
        val_rdata_valid = 1'b1;
        for(int unsigned k=0; k < 128; k++) begin
            case(1'b1)
                rd_idx_d2[  0]: val_rd_data_o[k] = bankA_dma_dout[0][0][k];
                rd_idx_d2[  1]: val_rd_data_o[k] = bankA_dma_dout[0][1][k];
                rd_idx_d2[  2]: val_rd_data_o[k] = bankA_dma_dout[0][2][k];
                rd_idx_d2[  3]: val_rd_data_o[k] = bankA_dma_dout[0][3][k];
                rd_idx_d2[  4]: val_rd_data_o[k] = bankA_dma_dout[0][4][k];
                rd_idx_d2[  5]: val_rd_data_o[k] = bankA_dma_dout[0][5][k];
                rd_idx_d2[  6]: val_rd_data_o[k] = bankA_dma_dout[0][6][k];
                rd_idx_d2[  7]: val_rd_data_o[k] = bankA_dma_dout[0][7][k];
                rd_idx_d2[  8]: val_rd_data_o[k] = bankA_dma_dout[0][8][k];
                rd_idx_d2[  9]: val_rd_data_o[k] = bankA_dma_dout[0][9][k];
                rd_idx_d2[ 10]: val_rd_data_o[k] = bankA_dma_dout[0][10][k];
                rd_idx_d2[ 11]: val_rd_data_o[k] = bankA_dma_dout[0][11][k];
                rd_idx_d2[ 12]: val_rd_data_o[k] = bankA_dma_dout[0][12][k];
                rd_idx_d2[ 13]: val_rd_data_o[k] = bankA_dma_dout[0][13][k];
                rd_idx_d2[ 14]: val_rd_data_o[k] = bankA_dma_dout[0][14][k];
                rd_idx_d2[ 15]: val_rd_data_o[k] = bankA_dma_dout[0][15][k];
                rd_idx_d2[ 16]: val_rd_data_o[k] = bankB_dma_dout[0][0][k];
                rd_idx_d2[ 17]: val_rd_data_o[k] = bankB_dma_dout[0][1][k];
                rd_idx_d2[ 18]: val_rd_data_o[k] = bankB_dma_dout[0][2][k];
                rd_idx_d2[ 19]: val_rd_data_o[k] = bankB_dma_dout[0][3][k];
                rd_idx_d2[ 20]: val_rd_data_o[k] = bankB_dma_dout[0][4][k];
                rd_idx_d2[ 21]: val_rd_data_o[k] = bankB_dma_dout[0][5][k];
                rd_idx_d2[ 22]: val_rd_data_o[k] = bankB_dma_dout[0][6][k];
                rd_idx_d2[ 23]: val_rd_data_o[k] = bankB_dma_dout[0][7][k];
                rd_idx_d2[ 24]: val_rd_data_o[k] = bankB_dma_dout[0][8][k];
                rd_idx_d2[ 25]: val_rd_data_o[k] = bankB_dma_dout[0][9][k];
                rd_idx_d2[ 26]: val_rd_data_o[k] = bankB_dma_dout[0][10][k];
                rd_idx_d2[ 27]: val_rd_data_o[k] = bankB_dma_dout[0][11][k];
                rd_idx_d2[ 28]: val_rd_data_o[k] = bankB_dma_dout[0][12][k];
                rd_idx_d2[ 29]: val_rd_data_o[k] = bankB_dma_dout[0][13][k];
                rd_idx_d2[ 30]: val_rd_data_o[k] = bankB_dma_dout[0][14][k];
                rd_idx_d2[ 31]: val_rd_data_o[k] = bankB_dma_dout[0][15][k];
                rd_idx_d2[ 32]: val_rd_data_o[k] = bankA_dma_dout[1][0][k];
                rd_idx_d2[ 33]: val_rd_data_o[k] = bankA_dma_dout[1][1][k];
                rd_idx_d2[ 34]: val_rd_data_o[k] = bankA_dma_dout[1][2][k];
                rd_idx_d2[ 35]: val_rd_data_o[k] = bankA_dma_dout[1][3][k];
                rd_idx_d2[ 36]: val_rd_data_o[k] = bankA_dma_dout[1][4][k];
                rd_idx_d2[ 37]: val_rd_data_o[k] = bankA_dma_dout[1][5][k];
                rd_idx_d2[ 38]: val_rd_data_o[k] = bankA_dma_dout[1][6][k];
                rd_idx_d2[ 39]: val_rd_data_o[k] = bankA_dma_dout[1][7][k];
                rd_idx_d2[ 40]: val_rd_data_o[k] = bankA_dma_dout[1][8][k];
                rd_idx_d2[ 41]: val_rd_data_o[k] = bankA_dma_dout[1][9][k];
                rd_idx_d2[ 42]: val_rd_data_o[k] = bankA_dma_dout[1][10][k];
                rd_idx_d2[ 43]: val_rd_data_o[k] = bankA_dma_dout[1][11][k];
                rd_idx_d2[ 44]: val_rd_data_o[k] = bankA_dma_dout[1][12][k];
                rd_idx_d2[ 45]: val_rd_data_o[k] = bankA_dma_dout[1][13][k];
                rd_idx_d2[ 46]: val_rd_data_o[k] = bankA_dma_dout[1][14][k];
                rd_idx_d2[ 47]: val_rd_data_o[k] = bankA_dma_dout[1][15][k];
                rd_idx_d2[ 48]: val_rd_data_o[k] = bankB_dma_dout[1][0][k];
                rd_idx_d2[ 49]: val_rd_data_o[k] = bankB_dma_dout[1][1][k];
                rd_idx_d2[ 50]: val_rd_data_o[k] = bankB_dma_dout[1][2][k];
                rd_idx_d2[ 51]: val_rd_data_o[k] = bankB_dma_dout[1][3][k];
                rd_idx_d2[ 52]: val_rd_data_o[k] = bankB_dma_dout[1][4][k];
                rd_idx_d2[ 53]: val_rd_data_o[k] = bankB_dma_dout[1][5][k];
                rd_idx_d2[ 54]: val_rd_data_o[k] = bankB_dma_dout[1][6][k];
                rd_idx_d2[ 55]: val_rd_data_o[k] = bankB_dma_dout[1][7][k];
                rd_idx_d2[ 56]: val_rd_data_o[k] = bankB_dma_dout[1][8][k];
                rd_idx_d2[ 57]: val_rd_data_o[k] = bankB_dma_dout[1][9][k];
                rd_idx_d2[ 58]: val_rd_data_o[k] = bankB_dma_dout[1][10][k];
                rd_idx_d2[ 59]: val_rd_data_o[k] = bankB_dma_dout[1][11][k];
                rd_idx_d2[ 60]: val_rd_data_o[k] = bankB_dma_dout[1][12][k];
                rd_idx_d2[ 61]: val_rd_data_o[k] = bankB_dma_dout[1][13][k];
                rd_idx_d2[ 62]: val_rd_data_o[k] = bankB_dma_dout[1][14][k];
                rd_idx_d2[ 63]: val_rd_data_o[k] = bankB_dma_dout[1][15][k];
                default:        val_rd_data_o[k] = 1'b0;
            endcase
        end
    end // read data output end
    //********************************
    // read shift data
    //********************************
    else if(r_shift_en_d2 == 1'b1) begin
        val_rd_data_o = shift_dout;
        val_rdata_valid = 1'b1;
    end
    //********************************
    // read shift register
    //********************************
    else if(r_reg_en_d2 == 1'b1) begin
        val_rd_data_o = {76'h0, channelgroup, preproc_type, 32'h0};
        val_rdata_valid = 1'b1;
    end
end

// logic [127:0] sram_data_b;

//********************************************
// sram_data_b is shift add operation
// second input data, valid after write enable
// 2 cycles
//********************************************
logic [RD_IDX_WIDTH:0] rd_idx_reg;
assign rd_idx_reg = { {RD_IDX_WIDTH{1'b0}}, {1'b1}} << { {val_wr_addr_i_reg[`CH_LHS:`CH_RHS]},
    {val_wr_addr_i_reg[`BANK_AB]}, {val_wr_addr_i_reg[`BANK_ADDR_ST:`BANK_ADDR_ED]} };

always_ff @(posedge clk or negedge reset_n) begin
    if(!reset_n) begin
        sram_data_b <= 128'h0;
    end
    else if(w_data_en_d2) begin
        for(int unsigned k=0; k < 128; k++) begin
            case(1'b1)
                rd_idx_reg[  0]: sram_data_b[k] = bankA_dma_dout[0][0][k];
                rd_idx_reg[  1]: sram_data_b[k] = bankA_dma_dout[0][1][k];
                rd_idx_reg[  2]: sram_data_b[k] = bankA_dma_dout[0][2][k];
                rd_idx_reg[  3]: sram_data_b[k] = bankA_dma_dout[0][3][k];
                rd_idx_reg[  4]: sram_data_b[k] = bankA_dma_dout[0][4][k];
                rd_idx_reg[  5]: sram_data_b[k] = bankA_dma_dout[0][5][k];
                rd_idx_reg[  6]: sram_data_b[k] = bankA_dma_dout[0][6][k];
                rd_idx_reg[  7]: sram_data_b[k] = bankA_dma_dout[0][7][k];
                rd_idx_reg[  8]: sram_data_b[k] = bankA_dma_dout[0][8][k];
                rd_idx_reg[  9]: sram_data_b[k] = bankA_dma_dout[0][9][k];
                rd_idx_reg[ 10]: sram_data_b[k] = bankA_dma_dout[0][10][k];
                rd_idx_reg[ 11]: sram_data_b[k] = bankA_dma_dout[0][11][k];
                rd_idx_reg[ 12]: sram_data_b[k] = bankA_dma_dout[0][12][k];
                rd_idx_reg[ 13]: sram_data_b[k] = bankA_dma_dout[0][13][k];
                rd_idx_reg[ 14]: sram_data_b[k] = bankA_dma_dout[0][14][k];
                rd_idx_reg[ 15]: sram_data_b[k] = bankA_dma_dout[0][15][k];
                rd_idx_reg[ 16]: sram_data_b[k] = bankB_dma_dout[0][0][k];
                rd_idx_reg[ 17]: sram_data_b[k] = bankB_dma_dout[0][1][k];
                rd_idx_reg[ 18]: sram_data_b[k] = bankB_dma_dout[0][2][k];
                rd_idx_reg[ 19]: sram_data_b[k] = bankB_dma_dout[0][3][k];
                rd_idx_reg[ 20]: sram_data_b[k] = bankB_dma_dout[0][4][k];
                rd_idx_reg[ 21]: sram_data_b[k] = bankB_dma_dout[0][5][k];
                rd_idx_reg[ 22]: sram_data_b[k] = bankB_dma_dout[0][6][k];
                rd_idx_reg[ 23]: sram_data_b[k] = bankB_dma_dout[0][7][k];
                rd_idx_reg[ 24]: sram_data_b[k] = bankB_dma_dout[0][8][k];
                rd_idx_reg[ 25]: sram_data_b[k] = bankB_dma_dout[0][9][k];
                rd_idx_reg[ 26]: sram_data_b[k] = bankB_dma_dout[0][10][k];
                rd_idx_reg[ 27]: sram_data_b[k] = bankB_dma_dout[0][11][k];
                rd_idx_reg[ 28]: sram_data_b[k] = bankB_dma_dout[0][12][k];
                rd_idx_reg[ 29]: sram_data_b[k] = bankB_dma_dout[0][13][k];
                rd_idx_reg[ 30]: sram_data_b[k] = bankB_dma_dout[0][14][k];
                rd_idx_reg[ 31]: sram_data_b[k] = bankB_dma_dout[0][15][k];
                rd_idx_reg[ 32]: sram_data_b[k] = bankA_dma_dout[1][0][k];
                rd_idx_reg[ 33]: sram_data_b[k] = bankA_dma_dout[1][1][k];
                rd_idx_reg[ 34]: sram_data_b[k] = bankA_dma_dout[1][2][k];
                rd_idx_reg[ 35]: sram_data_b[k] = bankA_dma_dout[1][3][k];
                rd_idx_reg[ 36]: sram_data_b[k] = bankA_dma_dout[1][4][k];
                rd_idx_reg[ 37]: sram_data_b[k] = bankA_dma_dout[1][5][k];
                rd_idx_reg[ 38]: sram_data_b[k] = bankA_dma_dout[1][6][k];
                rd_idx_reg[ 39]: sram_data_b[k] = bankA_dma_dout[1][7][k];
                rd_idx_reg[ 40]: sram_data_b[k] = bankA_dma_dout[1][8][k];
                rd_idx_reg[ 41]: sram_data_b[k] = bankA_dma_dout[1][9][k];
                rd_idx_reg[ 42]: sram_data_b[k] = bankA_dma_dout[1][10][k];
                rd_idx_reg[ 43]: sram_data_b[k] = bankA_dma_dout[1][11][k];
                rd_idx_reg[ 44]: sram_data_b[k] = bankA_dma_dout[1][12][k];
                rd_idx_reg[ 45]: sram_data_b[k] = bankA_dma_dout[1][13][k];
                rd_idx_reg[ 46]: sram_data_b[k] = bankA_dma_dout[1][14][k];
                rd_idx_reg[ 47]: sram_data_b[k] = bankA_dma_dout[1][15][k];
                rd_idx_reg[ 48]: sram_data_b[k] = bankB_dma_dout[1][0][k];
                rd_idx_reg[ 49]: sram_data_b[k] = bankB_dma_dout[1][1][k];
                rd_idx_reg[ 50]: sram_data_b[k] = bankB_dma_dout[1][2][k];
                rd_idx_reg[ 51]: sram_data_b[k] = bankB_dma_dout[1][3][k];
                rd_idx_reg[ 52]: sram_data_b[k] = bankB_dma_dout[1][4][k];
                rd_idx_reg[ 53]: sram_data_b[k] = bankB_dma_dout[1][5][k];
                rd_idx_reg[ 54]: sram_data_b[k] = bankB_dma_dout[1][6][k];
                rd_idx_reg[ 55]: sram_data_b[k] = bankB_dma_dout[1][7][k];
                rd_idx_reg[ 56]: sram_data_b[k] = bankB_dma_dout[1][8][k];
                rd_idx_reg[ 57]: sram_data_b[k] = bankB_dma_dout[1][9][k];
                rd_idx_reg[ 58]: sram_data_b[k] = bankB_dma_dout[1][10][k];
                rd_idx_reg[ 59]: sram_data_b[k] = bankB_dma_dout[1][11][k];
                rd_idx_reg[ 60]: sram_data_b[k] = bankB_dma_dout[1][12][k];
                rd_idx_reg[ 61]: sram_data_b[k] = bankB_dma_dout[1][13][k];
                rd_idx_reg[ 62]: sram_data_b[k] = bankB_dma_dout[1][14][k];
                rd_idx_reg[ 63]: sram_data_b[k] = bankB_dma_dout[1][15][k];
                default:         sram_data_b[k] = 1'b0;
            endcase
        end
    end else begin
        sram_data_b <= 128'h0;
    end
end

// logic [127:0] data_a_after_shift;
// logic [127:0] data_a_after_shift_d1;
// logic [127:0] data_a_after_shift_d2;
// logic [127:0] data_a_after_shift_d3;
// logic [127:0] data_b_after_shift;
// logic [31:0]  shift_val1;
// logic [31:0]  shift_val2;
// logic [7:0][15:0] val_w_temp;

// shift value mux logic
always_comb begin
    if(preproc_type == SHIFT) begin
        case({val_wr_addr_i[`CH_LHS:`CH_RHS], val_wr_addr_i[4]})
            2'd0: 
                for(int unsigned j=0; j<8; j++)
                    for(int unsigned k=0; k<4; k++)
                        shift_val1[j][k] = shift_reg1[j*8+k];
            2'd1: 
                for(int unsigned j=0; j<8; j++)
                    for(int unsigned k=0; k<4; k++)
                        shift_val1[j][k] = shift_reg1[j*8+k+64];
            2'd2: 
                for(int unsigned j=0; j<8; j++)
                    for(int unsigned k=0; k<4; k++)
                        shift_val1[j][k] = shift_reg1[j*8+k+4];
            2'd3: 
                for(int unsigned j=0; j<8; j++)
                    for(int unsigned k=0; k<4; k++)
                        shift_val1[j][k] = shift_reg1[j*8+k+68];
            default: shift_val1 = 32'h0;
        endcase
    end
    else if(preproc_type == SHIFTADD) begin
        case({val_wr_addr_i[`CH_LHS:`CH_RHS], val_wr_addr_i[4]})
            2'd0: 
                for(int unsigned j=0; j<8; j++)
                    for(int unsigned k=0; k<4; k++)
                        shift_val1[j][k] = shift_reg1[j*8+k];
            2'd1: 
                for(int unsigned j=0; j<8; j++)
                    for(int unsigned k=0; k<4; k++)
                        shift_val1[j][k] = shift_reg1[j*8+k+64];
            2'd2: 
                for(int unsigned j=0; j<8; j++)
                    for(int unsigned k=0; k<4; k++)
                        shift_val1[j][k] = shift_reg2[j*8+k];
            2'd3: 
                for(int unsigned j=0; j<8; j++)
                    for(int unsigned k=0; k<4; k++)
                        shift_val1[j][k] = shift_reg2[j*8+k+64];
            default: shift_val1 = 32'h0;
        endcase
    end
    else begin
        shift_val1 = 32'h0;
    end
end

// shift value mux logic
always_comb begin
    if(preproc_type == SHIFTADD) begin
        case(val_wr_addr_i[`CH_LHS:`CH_RHS])
            2'd0: 
                for(int unsigned j=0; j<8; j++)
                    for(int unsigned k=0; k<4; k++)
                        shift_val2[j][k] = shift_reg1[j*8+k+4];
            2'd1: 
                for(int unsigned j=0; j<8; j++)
                    for(int unsigned k=0; k<4; k++)
                        shift_val2[j][k] = shift_reg1[j*8+k+68];
            2'd2: 
                for(int unsigned j=0; j<8; j++)
                    for(int unsigned k=0; k<4; k++)
                        shift_val2[j][k] = shift_reg2[j*8+k+4];
            2'd3: 
                for(int unsigned j=0; j<8; j++)
                    for(int unsigned k=0; k<4; k++)
                        shift_val2[j][k] = shift_reg2[j*8+k+68];
            default: shift_val2 = 32'h0;
        endcase
    end
    else begin
        shift_val2 = 32'h0;
    end
end

always_comb begin
    for(int unsigned j=0; j<8; j++)
        for(int unsigned i=0; i<16; i++)
            val_w_temp[j][i] = val_wr_data_i[j*16+i];
end

// shift value generate
always_comb begin
    data_a_after_shift  = 128'h0;
    if(preproc_type == SHIFT || preproc_type == SHIFTADD) begin
        for(int unsigned i=0; i<8; i++) begin
            case(shift_val1[i])
                4'h0: data_a_after_shift[i] = val_w_temp[i];
                4'h1: data_a_after_shift[i] = {{2{val_w_temp[i][15]}},val_w_temp[i][14:1]};    // >>
                4'h2: data_a_after_shift[i] = {{3{val_w_temp[i][15]}},val_w_temp[i][14:2]};
                4'h3: data_a_after_shift[i] = {{4{val_w_temp[i][15]}},val_w_temp[i][14:3]};
                4'h4: data_a_after_shift[i] = {{5{val_w_temp[i][15]}},val_w_temp[i][14:4]};
                4'hf: data_a_after_shift[i] = (val_w_temp[i][15] == val_w_temp[i][14]) ? {val_w_temp[i][15], val_w_temp[i][13:0], 1'b0} : {val_w_temp[i][15],{15{~val_w_temp[i][15]}}};  // <<
                4'he: data_a_after_shift[i] = (|val_w_temp[i][15:13] == &val_w_temp[i][15:13]) ? {val_w_temp[i][15], val_w_temp[i][12:0], 2'b0} : {val_w_temp[i][15],{15{~val_w_temp[i][15]}}};  // <<
                4'hd: data_a_after_shift[i] = (|val_w_temp[i][15:12] == &val_w_temp[i][15:12]) ? {val_w_temp[i][15], val_w_temp[i][11:0], 3'b0} : {val_w_temp[i][15],{15{~val_w_temp[i][15]}}};  // <<
                4'hc: data_a_after_shift[i] = (|val_w_temp[i][15:11] == &val_w_temp[i][15:11]) ? {val_w_temp[i][15], val_w_temp[i][10:0], 4'b0} : {val_w_temp[i][15],{15{~val_w_temp[i][15]}}};  // <<
                default: data_a_after_shift[i] = val_w_temp[i];
            endcase
        end
    end
end

genvar i1, j1;
for(i1=0;i1<8;i1++) begin
    for(j1=0;j1<16;j1++) begin
        always_comb begin
            data_a_after_shift_w[i1*16+j1] = data_a_after_shift[i1][j1];
        end
    end
end

always_ff @(posedge clk or negedge reset_n) begin
    if(!reset_n) begin
        data_a_after_shift_d1 <= 128'h0;
        data_a_after_shift_d2 <= 128'h0;
        data_a_after_shift_d3 <= 128'h0;
    end
    else begin
        data_a_after_shift_d1 <= data_a_after_shift;
        data_a_after_shift_d2 <= data_a_after_shift_d1;
        data_a_after_shift_d3 <= data_a_after_shift_d2;
    end
end

// shift add read sram data
// logic [7:0][15:0] val_r_temp;

genvar i3,j3;
for(i3=0; i3<8; i3++) begin
    for(j3=0; j3<16; j3++) begin
        always_comb begin
            val_r_temp[i3][j3] = sram_data_b[i3*16+j3];
        end
    end
end

// logic [7:0][15:0] data_b_8;
// always_comb begin
//     for(int unsigned j=0; j<8; j++)
//         for(int unsigned i=0; i<16; i++)
//             sram_data_b[i+j*16] = data_b_8[j][i];
// end

// data B shift
always_comb begin
    data_b_after_shift  = 128'h0;
    if(preproc_type == SHIFTADD) begin
        for(int unsigned i=0; i<8; i++) begin
            case(shift_val2[i])
                4'h0: data_b_after_shift[i] = val_r_temp[i];
                4'h1: data_b_after_shift[i] = {{2{val_r_temp[i][15]}},val_r_temp[i][14:1]};    // >>
                4'h2: data_b_after_shift[i] = {{3{val_r_temp[i][15]}},val_r_temp[i][14:2]};
                4'h3: data_b_after_shift[i] = {{4{val_r_temp[i][15]}},val_r_temp[i][14:3]};
                4'h4: data_b_after_shift[i] = {{5{val_r_temp[i][15]}},val_r_temp[i][14:4]};
                4'hf: data_b_after_shift[i] = (val_r_temp[i][15] == val_r_temp[i][14]) ? {val_r_temp[i][15], val_r_temp[i][13:0], 1'b0} : {val_r_temp[i][15],{15{~val_r_temp[i][15]}}};  // <<
                4'he: data_b_after_shift[i] = (|val_r_temp[i][15:13] == &val_r_temp[i][15:13]) ? {val_r_temp[i][15], val_r_temp[i][12:0], 2'b0} : {val_r_temp[i][15],{15{~val_r_temp[i][15]}}};  // <<
                4'hd: data_b_after_shift[i] = (|val_r_temp[i][15:12] == &val_r_temp[i][15:12]) ? {val_r_temp[i][15], val_r_temp[i][11:0], 3'b0} : {val_r_temp[i][15],{15{~val_r_temp[i][15]}}};  // <<
                4'hc: data_b_after_shift[i] = (|val_r_temp[i][15:11] == &val_r_temp[i][15:11]) ? {val_r_temp[i][15], val_r_temp[i][10:0], 4'b0} : {val_r_temp[i][15],{15{~val_r_temp[i][15]}}};  // <<
                default: data_b_after_shift[i] = val_r_temp[i];
            endcase
        end
    end
end

// logic [7:0][16:0] shift_add_result_temp;
// logic [7:0][15:0] shift_add_result;
// logic [127:0]     shift_add_result_w;

always_comb begin
    for(int unsigned i=0;i<8;i++)
        shift_add_result_temp[i] = data_a_after_shift_d3[i] + data_b_after_shift[i];
end

always_comb begin
    for(int unsigned i=0;i<8;i++)
        if((shift_add_result_temp[i][15] != data_b_after_shift[i][15]) && 
            (data_a_after_shift[i][15] == data_b_after_shift[i][15]))
            shift_add_result[i] = {data_b_after_shift[i][15],{15{~data_b_after_shift[i][15]}}};
        else
            shift_add_result[i] = {shift_add_result_temp[i][15],shift_add_result_temp[i][14:0]};
end

genvar i2, j2;
for(i2=0;i2<8;i2++) begin
    for(j2=0;j2<16;j2++) begin
	always_comb begin
            shift_add_result_w[i2*16+j2] = shift_add_result[i2][j2];
        end
    end
end

// logic cs;
// logic we;
// logic [15:0] byte_en;
// logic [6:0]  addr;
// logic [127:0] shift_din;
// logic [127:0] shift_dout;
// 
// logic w_shift_en;
// logic r_shift_en;
// logic r_shift_en_d1;
// 
// // channel group count for x*y
// logic [17:0] cg_count;
// logic [2:0]  ch_count;
// // shift value register
// logic [127:0] shift_reg1;
// logic [127:0] shift_reg2;
// // shift sram address
// logic [6:0]  shift_addr;
// // preprocess ip read shift sram
// logic        shift_valid1;
// logic        shift_valid2;
// logic        shift_valid1_d1;
// logic        shift_valid2_d1;

logic [15:0] val_wr_strb_wire;
logic [15:0] val_wr_strb_reg;

// write shift sram first time and default address=0
always_ff @(posedge clk or negedge reset_n) begin
    if(~reset_n)   shift_reg1  <= 128'h0;
    else if(shift_valid1_d1) begin
        shift_reg1 <= shift_dout;
    end
    else if(w_shift_en && val_wr_addr_i[10:4]==7'h0) begin
        for(int unsigned i=0; i<16; i++) begin
            if(val_wr_strb_i[i]) begin
                for(int unsigned j=0; j<8; j++) begin
                    shift_reg1[i*8+j] <= val_wr_data_i[i*8+j];
                end
            end
        end
    end
    else if(cgc_wire) begin
        shift_reg1 <= 128'h0;
    end
end

always_ff @(posedge clk or negedge reset_n) begin
    if(!reset_n) begin
        shift_reg2  <= 128'h0;
    end
    // write shift sram first time and default address= 1
    else if(shift_valid2_d1) begin
        shift_reg2 <= shift_dout;
    end
    else if(w_shift_en && val_wr_addr_i[10:4]==7'h1) begin
        for(int unsigned i=0; i<16; i++) begin
            if(val_wr_strb_i[i]) begin
                for(int unsigned j=0; j<8; j++) begin
                    shift_reg2[i*8+j] <= val_wr_data_i[i*8+j];
                end
            end
        end
    end else if(cgc_wire) begin
        shift_reg2 <= 128'h0;
    end
end

//*********************************************
// when write 32channel, 512bit, cg_count add 1
//*********************************************
always_ff @(posedge clk or negedge reset_n) begin
    if(!reset_n)   cg_count  <= 18'h0;
    else if(cgc_wire)
        cg_count  <= 18'h0;
    else if(cg_count == channelgroup &&
        (preproc_type == 2'd2 || preproc_type == 2'd1) && (ch_count == 3'h3 && val_wr_strb_wire == 16'hffff))
        cg_count  <= 18'h0;
    else if((preproc_type == 2'd2 || preproc_type == 2'd1) && (ch_count == 3'h3 && val_wr_strb_wire == 16'hffff))
        cg_count  <= cg_count + 18'h1;
end

logic [17:0] cg_count_d1;
always_ff @(posedge clk or negedge reset_n) begin
    if(!reset_n)   cg_count_d1  <= 18'h0;
    else           cg_count_d1  <= cg_count;
end

// each time 8 channel, 4 times
always_ff @(posedge clk or negedge reset_n) begin
    if(!reset_n)   ch_count  <= 3'h0;
    else if(ch_count == 3'h3 && val_wr_strb_wire == 16'hffff)
        ch_count  <= 3'h0;
//    else if(w_data_en && (preproc_type == 2'd2 || preproc_type == 2'd1) 
//        && ch_count == 3'h4 && (val_wr_strb_wire == 16'hffff))
//        ch_count  <= 3'h1;
    else if(w_data_en_d1 && (preproc_type == 2'd2 || preproc_type == 2'd1)
        && (val_wr_strb_wire == 16'hffff))
        ch_count  <= ch_count + 3'h1;
    else if(cgc_wire)
        ch_count  <= 3'h0;
end
always_ff @(posedge clk or negedge reset_n) begin
    if(!reset_n)   ch_count_d1  <= 3'h0;
    else           ch_count_d1  <= ch_count;
end

always_comb begin
    if(val_wr_strb_reg == 16'hffff)
        val_wr_strb_wire = (w_data_en_d1 && (preproc_type == 2'd2 || preproc_type == 2'd1)) ? val_wr_strb_d1 : 16'h0;
    else if(w_data_en_d1 && (preproc_type == 2'd2 || preproc_type == 2'd1))
        val_wr_strb_wire = val_wr_strb_reg | val_wr_strb_d1;
    else
        val_wr_strb_wire = val_wr_strb_reg;
end

always_ff @(posedge clk or negedge reset_n) begin
    if(!reset_n)   
        val_wr_strb_reg <= 16'h0;
    else if(preproc_type == 2'd2 || preproc_type == 2'd1)
        val_wr_strb_reg <= val_wr_strb_wire;
end

  // shift sram axi read and write
  assign shift_base_addr = `SHIFT_BASE_ADDR;
  assign w_shift_en = val_write_i & (val_wr_addr_i[`SHIFT_SLICE_LHS:`SHIFT_SLICE_RHS] == shift_base_addr[`SHIFT_SLICE_LHS:`SHIFT_SLICE_RHS]);
  assign r_shift_en = val_read_i  & (val_rd_addr_i[`SHIFT_SLICE_LHS:`SHIFT_SLICE_RHS] == shift_base_addr[`SHIFT_SLICE_LHS:`SHIFT_SLICE_RHS]);

always_ff @(posedge clk or negedge reset_n) begin
    if(!reset_n)   w_shift_en_d1  <= 1'b0;
    else           w_shift_en_d1  <= w_shift_en;
end
always_ff @(posedge clk or negedge reset_n) begin
    if(!reset_n)   r_shift_en_d1  <= 1'b0;
    else           r_shift_en_d1  <= r_shift_en;
end
always_ff @(posedge clk or negedge reset_n) begin
    if(!reset_n)   r_shift_en_d2  <= 1'b0;
    else           r_shift_en_d2  <= r_shift_en_d1;
end

// shift sram control signal generate
// and read internal read sram valid
// for shift_reg1/2
always_ff @(posedge clk or negedge reset_n) begin
    if(!reset_n) begin
        cs           <= 1'b0;
        we           <= 1'b0;
        addr         <= 7'h0;
        byte_en      <= 16'h0;
        shift_din    <= 128'h0;
        shift_valid1 <= 1'b0;
        shift_valid2 <= 1'b0;
    end
    // write/read shift sram control signal
    else if(w_shift_en == 1'b1) begin
        cs           <= 1'b1;
        we           <= 1'b1;
        addr         <= val_wr_addr_i[10:4];
        byte_en      <= val_wr_strb_i;
        shift_din    <= val_wr_data_i;
        shift_valid1 <= 1'b0;
        shift_valid2 <= 1'b0;
    end
    else if(r_shift_en == 1'b1) begin
        cs           <= 1'b1;
        we           <= 1'b0;
        addr         <= val_rd_addr_i[10:4];
        byte_en      <= 16'h0;
        shift_din    <= 128'h0;
        shift_valid1 <= 1'b0;
        shift_valid2 <= 1'b0;
    end
    // 25-32 channel is writing and read new shift value
    else if(preproc_type == 2'd1 && cg_count == channelgroup && (ch_count == 3'h3 && val_wr_strb_wire == 16'hffff)) begin
        cs           <= 1'b1;
        we           <= 1'b0;
        addr         <= shift_addr;
        shift_valid1 <= 1'b1;
        byte_en      <= 16'h0;
        shift_din    <= 128'h0;
        shift_valid2 <= 1'b0;
    end
    // 9-16 channel is writing and shift_value1 read new value
    else if(preproc_type == 2'd2 && cg_count == channelgroup && (ch_count == 3'h3 && val_wr_strb_wire == 16'hffff)) begin
        cs           <= 1'b1;
        we           <= 1'b0;
        addr         <= shift_addr;
        shift_valid1 <= 1'b1;
        byte_en      <= 16'h0;
        shift_din    <= 128'h0;
        shift_valid2 <= 1'b0;
    end
    // 25-32 channel is writing and shift_value2 read new value
    else if(preproc_type == 2'd2 && shift_valid1_d1) begin
        cs           <= 1'b1;
        we           <= 1'b0;
        addr         <= shift_addr + 7'h1;
        shift_valid2 <= 1'b1;
        byte_en      <= 16'h0;
        shift_din    <= 128'h0;
        shift_valid1 <= 1'b0;
    end else begin
        cs           <= 1'b0;
        we           <= 1'b0;
        addr         <= 7'h0;
        byte_en      <= 16'h0;
        shift_din    <= 128'h0;
        shift_valid1 <= 1'b0;
        shift_valid2 <= 1'b0;
    end
end
// change shift value
always_ff @(posedge clk or negedge reset_n) begin
    if(!reset_n) begin
        bvalid_delay <= 1'b0;
        bcnt         <= 3'd0;
    end
    // write through not delay ace_bvalid
    else if(preproc_type == 2'd0) begin
        bvalid_delay <= 1'b0;
        bcnt         <= 3'd0;
    end
    else if(bcnt >= 3'd3) begin
        bvalid_delay <= 1'b0;
        bcnt         <= 3'd0;
    end
    else if(bvalid_delay) begin
        bcnt         <= bcnt + 3'd1;
    end
    // shift/shift add type, the last value
    // need to change shift reg
    else if((preproc_type == 2'd1 || preproc_type == 2'd2) 
        && cg_count == channelgroup && (ch_count == 3'h3 && val_wr_strb_wire == 16'hffff)) begin
        bvalid_delay <= 1'b1;
    end
end

// shift read value delay one cycle
always_ff @(posedge clk or negedge reset_n) begin
    if(!reset_n)   shift_valid1_d1 <= 1'b0;
    else           shift_valid1_d1 <= shift_valid1;
end
always_ff @(posedge clk or negedge reset_n) begin
    if(!reset_n)   shift_valid2_d1 <= 1'b0;
    else           shift_valid2_d1 <= shift_valid2;
end

//********************************************
// shift read address register
// 1.shift
// address -> shift_reg1
// only use shift value 1
// each time add 1
//
// 2.shift add
// even address -> shift_reg1
// odd  address -> shift_reg2
// each time add 2
//********************************************
always_ff @(posedge clk or negedge reset_n) begin
    if(!reset_n) shift_addr <= 7'h0;
    else if(preproc_type == 2'd1 && cg_count == channelgroup 
        && ch_count == 3'd1 && ch_count_d1 == 3'd0)
        shift_addr <= shift_addr + 7'h1;
    else if(preproc_type == 2'd2 && cg_count == channelgroup
        && ch_count == 3'd1 && ch_count_d1 == 3'd0)
        shift_addr <= shift_addr + 7'h2;
    else if(cgc_wire)
        shift_addr <= 7'h0;
end

// shift sram
sram #(.DEPTH(256), .DATA_W(128)) u_shift_ram (
    .clk(clk), .cs(cs), .byte_en(byte_en), .we(we), .addr({1'b0,addr}), .din(shift_din), .dout(shift_dout));

// sram_256x128 u_shift_ram (
//   .clka(clk),    // input wire clka
//   .ena(cs),      // input wire ena
//   .wea(byte_en),      // input wire [15 : 0] wea
//   .addra({1'b0,addr}),  // input wire [7 : 0] addra
//   .dina(shift_din),    // input wire [127 : 0] dina
//   .douta(shift_dout)  // output wire [127 : 0] douta
// );
//sram_256x128 #(.DEPTH(8'd128), .DATA_W(8'd128)) u_shift_sram (.clk(clk), .cs(cs), .byte_en(byte_en), .we(we), .addr(addr), .din(shift_din), .dout(shift_dout));

logic preproc_valid_reg;

// preprocess valid
// type = 0, valid always is 1
// type = 1, valid always is 1
// type = 2, write_data enable is 0,
// after 3 cycles, valid is 1
always_ff @(posedge clk or negedge reset_n) begin
    if(!reset_n) 
        preproc_valid_reg <= 1'b1;
    else
        preproc_valid_reg <= preproc_valid;
end

always_comb begin
    if(preproc_type == 2'd2 && w_data_en)
        preproc_valid = 1'b0;
    // preprocess valid to nxt_wready, shift add 
    // need 4 cycles write(include val_write cycle)
    // so w_data_en, d1, d2, d3(write shift add value)
    else if(preproc_type == 2'd2 && w_data_en_d2)
        preproc_valid = 1'b1;
    else if(unpk_valid_i && (val_wr_addr_i[`DATA_SLICE_LHS:`DATA_SLICE_RHS] == data_base_addr[`DATA_SLICE_LHS:`DATA_SLICE_RHS]) && preproc_type == 2'd2)
        preproc_valid = 1'b0;
    else
        preproc_valid = preproc_valid_reg;
end

endmodule
