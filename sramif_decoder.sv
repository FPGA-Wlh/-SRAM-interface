`include "define.vh"
module sramif_decoder
(// Address inputs
 input  wire          val_write_i,
 input  wire [31:0]   val_wr_addr_i,
 input  wire [15:0]   val_wr_strb_i,
 input  wire [127:0]  val_wr_data_i,

  // Clocks and resets
  input  wire                   clk,
  input  wire                   reset_n,

 input  wire          val_read_i,
 input  wire [31:0]   val_rd_addr_i,
 output logic [127:0]  val_rd_data_o,

  input wire        unpk_valid_i,

    // npu axi register
    input [5:0]                 fifo_count     ,

    // preprocess interface
    output logic         preproc_valid,
    output logic [1:0]   pre_type,
    output logic         bvalid_delay        ,

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
    input        [1:0][15:0][127:0]        bankB_dma_dout      ,

    // npu lut sram
    output logic [15:0]             dma_lut_cs      ,
    output logic [15:0]             dma_lut_we      ,
    output logic [15:0][11:0]       dma_lut_addr    ,
    output logic [15:0][15:0]       dma_lut_din     ,
    output logic [15:0][1:0]        dma_lut_byte_en ,
    input        [15:0][15:0]       dma_lut_dout    ,

    // command sram interface
	output logic                      cmd_cs         ,
    output logic                      cmd_we         ,
    output logic [10 - 1:0]           cmd_addr       ,
    input  logic [32-1:0]             cmd_out        ,
    output logic [32 - 1:0]           cmd            ,

    // npu reg interface
    output logic [31:0]               sys_addr       , // System Interface
    output logic                      sys_wr         , // System Interface
    output logic [15:0]               sys_wr_val     , // System Interface
    output logic                      sys_rd         , // System Interface
    input                             sys_ack        , // System Interface
    input        [15:0]               sys_rd_val     
);

logic [127:0] val_rd_sram;
logic val_rdata_valid; // npu_preproc read data is valid

logic w_cmd_en;    // write command sram enable
logic w_cmd_en_d1;    // write command sram enable
logic r_cmd_en;    // write command sram enable
logic r_cmd_en_d1;    // write command sram enable
logic r_cmd_en_d2;    // write command sram enable

logic w_reg_en;    // write command sram enable
logic r_reg_en;    // write command sram enable
logic r_reg_en_d1;    // write command sram enable
logic r_reg_en_d2;    // write command sram enable

logic r_fiforeg_en;    // read fifo register enable
logic r_fiforeg_en_d1;    // read fifo register enable
logic r_fiforeg_en_d2;    // read fifo register enable

logic w_lut_en;       // write lut sram enable
logic w_lut_en_d1;    // read  lut sram enable delay 1 cycle
logic r_lut_en;       // read  lut sram enable
logic r_lut_en_d1;    // read  lut sram enable delay 1 cycle
logic r_lut_en_d2;    // read  lut sram enable delay 1 cycle
logic [31:0]  val_rd_addr_i_reg;
logic [31:0]  val_rd_addr_i_d2;
logic [31:0]  val_wr_addr_i_reg;
//logic [15:0]   val_wr_strb_d1;
logic [127:0]  val_wr_data_d1;

logic [31:0]  cmd_base_addr;
logic [31:0]  npureg_base_addr;
logic [31:0]  lut_base_addr;
logic [31:0]  ctrl_reg_base_addr;

  // command sram
  assign cmd_base_addr = `CMD_BASE_ADDR;
  assign w_cmd_en  = val_write_i & (val_wr_addr_i[`CMD_SLICE_LHS:`CMD_SLICE_RHS] == cmd_base_addr[`CMD_SLICE_LHS:`CMD_SLICE_RHS]);
  assign r_cmd_en  = val_read_i  & (val_rd_addr_i[`CMD_SLICE_LHS:`CMD_SLICE_RHS] == cmd_base_addr[`CMD_SLICE_LHS:`CMD_SLICE_RHS]);
always_ff @(posedge clk or negedge reset_n) begin
    if(!reset_n)   w_cmd_en_d1  <= 1'b0;
    else           w_cmd_en_d1  <= w_cmd_en;
end
always_ff @(posedge clk or negedge reset_n) begin
    if(!reset_n)   r_cmd_en_d1  <= 1'b0;
    else           r_cmd_en_d1  <= r_cmd_en;
end
always_ff @(posedge clk or negedge reset_n) begin
    if(!reset_n)   r_cmd_en_d2  <= 1'b0;
    else           r_cmd_en_d2  <= r_cmd_en_d1;
end

  // reg
  // 0x5040_1000 ~ 0x5040_107f
  assign npureg_base_addr = `NPUREG_BASE_ADDR;
  assign w_reg_en  = val_write_i & (val_wr_addr_i[`NPUREG_SLICE_LHS:`NPUREG_SLICE_RHS] == npureg_base_addr[`NPUREG_SLICE_LHS:`NPUREG_SLICE_RHS]);
  assign r_reg_en  = val_read_i  & (val_rd_addr_i[`NPUREG_SLICE_LHS:`NPUREG_SLICE_RHS] == npureg_base_addr[`NPUREG_SLICE_LHS:`NPUREG_SLICE_RHS]);

always_ff @(posedge clk or negedge reset_n) begin
    if(!reset_n)   r_reg_en_d1  <= 1'b0;
    else           r_reg_en_d1  <= r_reg_en;
end
always_ff @(posedge clk or negedge reset_n) begin
    if(!reset_n)   r_reg_en_d2  <= 1'b0;
    else           r_reg_en_d2  <= r_reg_en_d1;
end

  // lut
  // 5042_0000 ~ 5043_ffff
  assign lut_base_addr = `LUT_BASE_ADDR;
  assign w_lut_en  = val_write_i & (val_wr_addr_i[`LUT_SLICE_LHS:`LUT_SLICE_RHS] == lut_base_addr[`LUT_SLICE_LHS:`LUT_SLICE_RHS]);
  assign r_lut_en  = val_read_i  & (val_rd_addr_i[`LUT_SLICE_LHS:`LUT_SLICE_RHS] == lut_base_addr[`LUT_SLICE_LHS:`LUT_SLICE_RHS]);

always_ff @(posedge clk or negedge reset_n) begin
    if(!reset_n)   w_lut_en_d1  <= 1'b0;
    else           w_lut_en_d1  <= w_lut_en;
end
always_ff @(posedge clk or negedge reset_n) begin
    if(!reset_n)   r_lut_en_d1  <= 1'b0;
    else           r_lut_en_d1  <= r_lut_en;
end
always_ff @(posedge clk or negedge reset_n) begin
    if(!reset_n)   r_lut_en_d2  <= 1'b0;
    else           r_lut_en_d2  <= r_lut_en_d1;
end
always_ff @(posedge clk or negedge reset_n) begin
    if(!reset_n)   val_wr_addr_i_reg <= 32'h0;
    else           val_wr_addr_i_reg <= val_wr_addr_i;
end
always_ff @(posedge clk or negedge reset_n) begin
    if(!reset_n)   val_rd_addr_i_reg <= 32'h0;
    else           val_rd_addr_i_reg <= val_rd_addr_i;
end
always_ff @(posedge clk or negedge reset_n) begin
    if(!reset_n)   val_rd_addr_i_d2 <= 32'h0;
    else           val_rd_addr_i_d2 <= val_rd_addr_i_reg;
end

//always_ff @(posedge clk or negedge reset_n) begin
//    if(!reset_n)   val_wr_strb_d1  <= 16'b0;
//    else           val_wr_strb_d1  <= val_wr_strb_i;
//end
always_ff @(posedge clk or negedge reset_n) begin
    if(!reset_n)   val_wr_data_d1  <= 128'b0;
    else           val_wr_data_d1  <= val_wr_data_i;
end

  // fifo reg
  // current only [4:0] fifo counter
  // 0x5040_1080
  assign ctrl_reg_base_addr = `CTRL_BASE_ADDR;
  assign r_fiforeg_en  = val_read_i  & (val_rd_addr_i[`CTRL_SLICE_LHS:`CTRL_SLICE_RHS] == ctrl_reg_base_addr[`CTRL_SLICE_LHS:`CTRL_SLICE_RHS]) & (val_rd_addr_i[`CTRL_SLICE_RHS-1:2] == `CTRL_FIFO_COUNTER);

always_ff @(posedge clk or negedge reset_n) begin
    if(!reset_n)   r_fiforeg_en_d1  <= 1'b0;
    else           r_fiforeg_en_d1  <= r_fiforeg_en;
end
always_ff @(posedge clk or negedge reset_n) begin
    if(!reset_n)   r_fiforeg_en_d2  <= 1'b0;
    else           r_fiforeg_en_d2  <= r_fiforeg_en_d1;
end

// SRAM CONTROL SIGNAL
// LUT and read data output
always_ff @(posedge clk or negedge reset_n) begin
    if(!reset_n) begin
        dma_lut_cs <= 16'h0;
        dma_lut_we <= 16'h0;
        for(int unsigned i=0; i< 16; i++) begin
            for(int unsigned j=0; j< 12; j++) 
                dma_lut_addr[i][j]    <= 1'b0;
            for(int unsigned j=0; j< 16; j++) 
                dma_lut_din[i][j]     <= 1'b0;
            for(int unsigned j=0; j< 2; j++) 
                dma_lut_byte_en[i][j] <= 1'b0;
        end
    end
    //********************************
    // read lut sram control logic
    //********************************
    else if(r_lut_en == 1'b1) begin
        if(~val_rd_addr_i[16]) begin
            dma_lut_cs   <= 16'hff;
            dma_lut_we   <= 16'h0;
            for(int unsigned i=0; i< 8; i++) 
                dma_lut_addr[i] <= val_rd_addr_i[15:4];
            for(int unsigned i=8; i< 16; i++) 
                dma_lut_addr[i] <= 12'h0;
        end
        else begin
            dma_lut_cs   <= 16'hff00;
            dma_lut_we   <= 16'h0;
            for(int unsigned i=8; i< 16; i++) 
                dma_lut_addr[i] <= val_rd_addr_i[15:4];
            for(int unsigned i=0; i< 8; i++) 
                dma_lut_addr[i] <= 12'h0;
        end
    end // read lut sram end
    //********************************
    // write lut sram
    //********************************
    else if(w_lut_en == 1'b1) begin
        if(~val_wr_addr_i[16]) begin
            for(int unsigned i=0; i< 8; i++) begin
                dma_lut_cs[i]      <= val_wr_strb_i[2*i+1] & val_wr_strb_i[2*i];
                dma_lut_we[i]      <= val_wr_strb_i[2*i+1] & val_wr_strb_i[2*i];
                dma_lut_addr[i]    <= val_wr_addr_i[15:4];
                for(int unsigned j=0; j< 16; j++)
                    dma_lut_din[i][j] <= val_wr_data_i[16*i+j];
                dma_lut_byte_en[i][0] <= val_wr_strb_i[2*i];
                dma_lut_byte_en[i][1] <= val_wr_strb_i[2*i+1];
            end
            for(int unsigned i=8; i< 16; i++) begin
                dma_lut_cs[i]      <= 1'b0;
                dma_lut_we[i]      <= 1'b0;
                dma_lut_addr[i]    <= 12'h0;
                dma_lut_din[i]     <= 16'h0;
                dma_lut_byte_en[i] <= 2'h0;
            end
        end
        else begin
            for(int unsigned i=0; i< 8; i++) begin
                dma_lut_cs[i+8]      <= val_wr_strb_i[2*i+1] & val_wr_strb_i[2*i];
                dma_lut_we[i+8]      <= val_wr_strb_i[2*i+1] & val_wr_strb_i[2*i];
                dma_lut_addr[i+8]    <= val_wr_addr_i[15:4];
                for(int unsigned j=0; j< 16; j++)
                    dma_lut_din[i+8][j] <= val_wr_data_i[16*i+j];
                dma_lut_byte_en[i+8][0] <= val_wr_strb_i[2*i];
                dma_lut_byte_en[i+8][1] <= val_wr_strb_i[2*i+1];
            end
            for(int unsigned i=0; i< 8; i++) begin
                dma_lut_cs[i]      <= 1'b0;
                dma_lut_we[i]      <= 1'b0;
                dma_lut_addr[i]    <= 12'h0;
                dma_lut_din[i]     <= 16'h0;
                dma_lut_byte_en[i] <= 2'h0;
            end

        end
    end // write lut sram
    else begin
        dma_lut_cs <= 16'h0;
        dma_lut_we <= 16'h0;
        for(int unsigned i=0; i< 16; i++) begin
            for(int unsigned j=0; j< 12; j++) 
                dma_lut_addr[i][j]    <= 1'b0;
            for(int unsigned j=0; j< 16; j++) 
                dma_lut_din[i][j]     <= 1'b0;
            for(int unsigned j=0; j< 2; j++) 
                dma_lut_byte_en[i][j] <= 1'b0;
        end
    end
end

//******************************************
// read return data
//******************************************
always_comb begin
    val_rd_data_o = 128'h0;
    //********************************
    // read fifo reg delay two cycle
    //********************************
    if(r_fiforeg_en_d2 == 1'b1) begin
        val_rd_data_o[4:0] = fifo_count;
    end
    //********************************
    // read data output delay two cycle
    //********************************
    else if(val_rdata_valid) begin
        val_rd_data_o = val_rd_sram;
    end
    else if(r_reg_en_d2) begin
        val_rd_data_o = {16'b0,sys_rd_val,16'b0,sys_rd_val,
            16'b0,sys_rd_val,16'b0,sys_rd_val};
    end
    //********************************
    // read command delay two cycle
    //********************************
    else if(r_cmd_en_d2 == 1'b1) begin
        case(val_rd_addr_i_d2[3:2])
            2'd0: val_rd_data_o = {96'h0, cmd_out};
            2'd1: val_rd_data_o = {64'h0, cmd_out, 32'h0};
            2'd2: val_rd_data_o = {32'h0, cmd_out, 64'h0};
            2'd3: val_rd_data_o = {cmd_out, 96'h0};
            default: val_rd_data_o = 128'h0;
        endcase
    end
    //********************************
    // read lut output delay two cycle
    //********************************
    else if(r_lut_en_d2 == 1'b1) begin
        if(~val_rd_addr_i_d2[16]) begin
            for(int unsigned k=0; k < 16; k++) begin
                val_rd_data_o[0+k]   = dma_lut_dout[0][k];
                val_rd_data_o[16+k]  = dma_lut_dout[1][k];
                val_rd_data_o[32+k]  = dma_lut_dout[2][k];
                val_rd_data_o[48+k]  = dma_lut_dout[3][k];
                val_rd_data_o[64+k]  = dma_lut_dout[4][k];
                val_rd_data_o[80+k]  = dma_lut_dout[5][k];
                val_rd_data_o[96+k]  = dma_lut_dout[6][k];
                val_rd_data_o[112+k] = dma_lut_dout[7][k];
            end
        end
        else begin
            for(int unsigned k=0; k < 16; k++) begin
                val_rd_data_o[0+k]   = dma_lut_dout[8][k];
                val_rd_data_o[16+k]  = dma_lut_dout[9][k];
                val_rd_data_o[32+k]  = dma_lut_dout[10][k];
                val_rd_data_o[48+k]  = dma_lut_dout[11][k];
                val_rd_data_o[64+k]  = dma_lut_dout[12][k];
                val_rd_data_o[80+k]  = dma_lut_dout[13][k];
                val_rd_data_o[96+k]  = dma_lut_dout[14][k];
                val_rd_data_o[112+k] = dma_lut_dout[15][k];
            end
        end
    end // read lut output end
end

//********************************
// COMMAND SRAM SIGNAL
// write command sram, only to write
//********************************
always_ff @(posedge clk or negedge reset_n) begin
    if(!reset_n) begin
        cmd      <= 32'h0;
        cmd_cs   <= 1'b0  ;
        cmd_we   <= 1'b0  ;
        cmd_addr <= 10'h0;
    end else if(w_cmd_en == 1'b1) begin
        if(val_wr_strb_i[3:0] == 4'hf) begin
            cmd      <= val_wr_data_i[31:0];
            cmd_cs   <= 1'b1  ;
            cmd_we   <= 1'b1  ;
            cmd_addr <= val_wr_addr_i[11:2];
        end
        else if(val_wr_strb_i[7:4] == 4'hf) begin
            cmd      <= val_wr_data_i[63:32];
            cmd_cs   <= 1'b1  ;
            cmd_we   <= 1'b1  ;
            cmd_addr <= val_wr_addr_i[11:2];
        end
        else if(val_wr_strb_i[11:8] == 4'hf) begin
            cmd      <= val_wr_data_i[95:64];
            cmd_cs   <= 1'b1  ;
            cmd_we   <= 1'b1  ;
            cmd_addr <= val_wr_addr_i[11:2];
        end
        else if(val_wr_strb_i[15:12] == 4'hf) begin
            cmd      <= val_wr_data_i[127:96];
            cmd_cs   <= 1'b1  ;
            cmd_we   <= 1'b1  ;
            cmd_addr <= val_wr_addr_i[11:2];
        end
        else begin
            cmd      <= 32'h0;
            cmd_cs   <= 1'b0  ;
            cmd_we   <= 1'b0  ;
            cmd_addr <= 10'h0;
        end
    end
    else if(r_cmd_en == 1'b1) begin
        cmd      <= 32'h0;
        cmd_cs   <= 1'b1  ;
        cmd_we   <= 1'b0  ;
        cmd_addr <= val_rd_addr_i[11:2];
    end
    else begin
        cmd      <= 32'h0;
        cmd_cs   <= 1'b0  ;
        cmd_we   <= 1'b0  ;
        cmd_addr <= 10'h0;
    end
end

// NPU REGISTER
//********************************
// read npu register control logic
//********************************
always_ff @(posedge clk or negedge reset_n) begin
    if(!reset_n) begin
        sys_wr     <= 1'b0  ;
        sys_rd     <= 1'b0  ;
        sys_addr   <= 32'h0 ;
        sys_wr_val <= 16'h0 ;
    end else if(w_reg_en == 1'b1) begin
        sys_wr     <= 1'b1  ;
        sys_rd     <= 1'b0  ;
        sys_addr   <= val_wr_addr_i;
        if(val_wr_strb_i[3:0] == 4'hf)
            sys_wr_val <= val_wr_data_i[15:0];
        else if(val_wr_strb_i[7:4] == 4'hf)
            sys_wr_val <= val_wr_data_i[47:32];
        else if(val_wr_strb_i[11:8] == 4'hf)
            sys_wr_val <= val_wr_data_i[79:64];
        else if(val_wr_strb_i[15:12] == 4'hf)
            sys_wr_val <= val_wr_data_i[111:96];
        else
            sys_wr_val <= 16'h0 ;
    end
    else if(r_reg_en == 1'b1) begin
        sys_wr     <= 1'b0  ;
        sys_rd     <= 1'b1  ;
        sys_addr   <= val_rd_addr_i;
        sys_wr_val <= 16'h0 ;
    end
    else begin
        sys_wr     <= 1'b0  ;
        sys_rd     <= 1'b0  ;
        sys_addr   <= 32'h0 ;
        sys_wr_val <= 16'h0 ;
    end
end

  sramif_decoder_preproc
    u_sramif_decoder_preproc
      (
           .clk             (clk),
           .reset_n         (reset_n),

         // Read port
         .val_read_i          (val_read_i),
         .val_rd_addr_i       (val_rd_addr_i),
         .val_rd_data_o       (val_rd_sram),
         .val_rdata_valid     (val_rdata_valid),

         // Write port
         .val_write_i         (val_write_i),
         .val_wr_addr_i       (val_wr_addr_i),
         .val_wr_strb_i       (val_wr_strb_i),
         .val_wr_data_i       (val_wr_data_i),

         // unpack valid
       .unpk_valid_i    (unpk_valid_i),
         
         // preprocess interface
         .preproc_valid       (preproc_valid),
         .pre_type            (pre_type),
         .bvalid_delay        (bvalid_delay),

         // sram interface
        .bankA_dma_cs        ( bankA_dma_cs        ),
        .bankA_dma_we        ( bankA_dma_we        ),
        .bankA_dma_addr      ( bankA_dma_addr      ),
        .bankA_dma_din       ( bankA_dma_din       ),
        .bankA_dma_byte_en   ( bankA_dma_byte_en   ),
        .bankA_dma_dout      ( bankA_dma_dout      ),
        .bankB_dma_cs        ( bankB_dma_cs        ),
        .bankB_dma_we        ( bankB_dma_we        ),
        .bankB_dma_addr      ( bankB_dma_addr      ),
        .bankB_dma_din       ( bankB_dma_din       ),
        .bankB_dma_byte_en   ( bankB_dma_byte_en   ),
        .bankB_dma_dout      ( bankB_dma_dout      )
      );

endmodule      
