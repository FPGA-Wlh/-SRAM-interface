module npu_axi_top#(
        // ---- Parameter ---- //
    parameter CMD_LEN        = 'd32 , 
    parameter CMD_DEPTH      = 'd10 ,
    parameter INT_NUM        = 'd8  , 
    parameter REG_IDX        = 'd32 ,   // One-hot index
    parameter REG_VAL        = 'd16 ,
    parameter WWIDTH		 = 'd1920,
    parameter WINWIDTH		 = 'd128,
    parameter AFIFO_DEPTH    = 5'd16,
    parameter AFIFO_AWIDTH   = 3'd4,
    parameter SFIFO_WIDTH    = 9'd160,
	parameter SFIFO_ADDRW    = 3'd5,
    parameter SFIFO_DEPTH    = 6'd32,
    parameter REG_IDX_BITS   = 3'd5,

    // AXI
    parameter integer AXI_SRAM_ID = 14,
    parameter STRB_WIDTH = (WINWIDTH/8),
    parameter LEN_WIDTH = 32,
    parameter ADDR_WIDTH = 32,



    parameter W_psum = 32,
    parameter W_data = 16,
    parameter W_wt = 10,
    parameter W_mul = W_data + W_wt,

    parameter W_coarse_shift = 5,
    parameter W_fine_shift = 4,
    parameter W_bias = 16,
    parameter W_bn_beta = 8,
    parameter W_bn_gamma = 16,
    parameter W_bn_shift = 4,
    parameter W_prelu_alpha = 16,
    parameter W_relu6_th = 16

)(
     // Clock and reset  
    input                                                       clk                     ,
    input                                                       rst_n                   ,                              
    // System Interface
    input                                                       en                      ,
    input                                                       go                      ,
    output logic [INT_NUM-1:0]                                  interrupt               ,
    
    input  logic [128-1:0]           wt 	  ,
    output logic                wt_ready 	  ,
    input                       wt_valid ,

    input  wire                                                 axi_clk                 ,

    // ACE slave interface
    input  wire [AXI_SRAM_ID-1:0]                               s_axi_data_awid            , 
    input  wire [ADDR_WIDTH-1:0]                                s_axi_data_awaddr          , 
    input  wire [7:0]                                           s_axi_data_awlen           , 
    input  wire [2:0]                                           s_axi_data_awsize          , 
    input  wire [1:0]                                           s_axi_data_awburst         , 
    input  wire                                                 s_axi_data_awlock          , 
    input  wire [3:0]                                           s_axi_data_awcache         , 
    input  wire [2:0]                                           s_axi_data_awprot          , 
    input  wire                                                 s_axi_data_awvalid         , 
    output wire                                                 s_axi_data_awready         , 
    input  wire [WINWIDTH-1:0]                                  s_axi_data_wdata           , 
    input  wire [STRB_WIDTH-1:0]                                s_axi_data_wstrb           , 
    input  wire                                                 s_axi_data_wlast           , 
    input  wire                                                 s_axi_data_wvalid          , 
    output wire                                                 s_axi_data_wready          , 
    input  wire                                                 s_axi_data_bready          , 
    output wire [AXI_SRAM_ID-1:0]                               s_axi_data_bid             , 
    output wire [1:0]                                           s_axi_data_bresp           , 
    output wire                                                 s_axi_data_bvalid          ,
    input  wire [AXI_SRAM_ID-1:0]                               s_axi_data_arid            , 
    input  wire [ADDR_WIDTH-1:0]                                s_axi_data_araddr          , 
    input  wire [7:0]                                           s_axi_data_arlen           , 
    input  wire [2:0]                                           s_axi_data_arsize          , 
    input  wire [1:0]                                           s_axi_data_arburst         , 
    input  wire                                                 s_axi_data_arlock          , 
    input  wire [3:0]                                           s_axi_data_arcache         , 
    input  wire [2:0]                                           s_axi_data_arprot          , 
    input  wire                                                 s_axi_data_arvalid         , 
    output wire                                                 s_axi_data_arready         , 
    output wire [AXI_SRAM_ID-1:0]                               s_axi_data_rid             , 
    output wire [WINWIDTH-1:0]                                  s_axi_data_rdata           , 
    output wire [1:0]                                           s_axi_data_rresp           , 
    output wire                                                 s_axi_data_rlast           ,
    output wire                                                 s_axi_data_rvalid          , 
    input  wire                                                 s_axi_data_rready          

//    // npu weight interface         
//    input  wire [AXI_SRAM_ID-1:0]                               s_axi_wt_awid            , 
//    input  wire [ADDR_WIDTH-1:0]                                s_axi_wt_awaddr          , 
//    input  wire [7:0]                                           s_axi_wt_awlen           , 
//    input  wire [2:0]                                           s_axi_wt_awsize          , 
//    input  wire [1:0]                                           s_axi_wt_awburst         , 
//    input  wire                                                 s_axi_wt_awlock          , 
//    input  wire [3:0]                                           s_axi_wt_awcache         , 
//    input  wire [2:0]                                           s_axi_wt_awprot          , 
//    input  wire                                                 s_axi_wt_awvalid         , 
//    output wire                                                 s_axi_wt_awready         , 
//    input  wire [WINWIDTH-1:0]                                  s_axi_wt_wdata           , 
//    input  wire [STRB_WIDTH-1:0]                                s_axi_wt_wstrb           , 
//    input  wire                                                 s_axi_wt_wlast           , 
//    input  wire                                                 s_axi_wt_wvalid          , 
//    output wire                                                 s_axi_wt_wready          , 
//    output wire [AXI_SRAM_ID-1:0]                               s_axi_wt_bid             , 
//    output wire [1:0]                                           s_axi_wt_bresp           , 
//    output wire                                                 s_axi_wt_bvalid          , 
//    input  wire                                                 s_axi_wt_bready          , 
//    input  wire [AXI_SRAM_ID-1:0]                               s_axi_wt_arid            , 
//    input  wire [ADDR_WIDTH-1:0]                                s_axi_wt_araddr          , 
//    input  wire [7:0]                                           s_axi_wt_arlen           , 
//    input  wire [2:0]                                           s_axi_wt_arsize          , 
//    input  wire [1:0]                                           s_axi_wt_arburst         , 
//    input  wire                                                 s_axi_wt_arlock          , 
//    input  wire [3:0]                                           s_axi_wt_arcache         , 
//    input  wire [2:0]                                           s_axi_wt_arprot          , 
//    input  wire                                                 s_axi_wt_arvalid         , 
//    output wire                                                 s_axi_wt_arready         , 
//    output wire [AXI_SRAM_ID-1:0]                               s_axi_wt_rid             , 
//    output wire [WINWIDTH-1:0]                                  s_axi_wt_rdata           , 
//    output wire [1:0]                                           s_axi_wt_rresp           , 
//    output wire                                                 s_axi_wt_rlast           , 
//    output wire                                                 s_axi_wt_rvalid          , 
//    input  wire                                                 s_axi_wt_rready          

);

// npu signal
logic [31:0]              sys_addr           ; 
logic                     sys_wr             ; 
logic [15:0]              sys_wr_val         ; 
logic                     sys_rd             ; 
logic                     sys_ack            ; 
logic [15:0]              sys_rd_val         ; 
logic                     cmd_cs             ; 
logic [31:0]              cmd                ; 
logic [31:0]              cmd_out            ; 
logic [9:0]               cmd_addr           ; 
logic                     cmd_we             ; 
logic [1:0][15:0]                                   bankA_dma_cs            ;
logic [1:0][15:0][15:0]                             bankA_dma_byte_en       ;
logic [1:0][15:0][10:0]                             bankA_dma_addr          ;
logic [1:0][15:0]                                   bankA_dma_en_we         ;
logic [1:0][15:0][127:0]                            bankA_dma_data_write    ;
logic [1:0][15:0][127:0]                            bankA_dma_data_read     ;
logic [1:0][15:0]                                   bankB_dma_cs            ;
logic [1:0][15:0][15:0]                             bankB_dma_byte_en       ;
logic [1:0][15:0][10:0]                             bankB_dma_addr          ;
logic [1:0][15:0]                                   bankB_dma_en_we         ;
logic [1:0][15:0][127:0]                            bankB_dma_data_write    ;
logic [1:0][15:0][127:0]                            bankB_dma_data_read     ;
logic [127:0]             wt_in              ;
logic                     wt_w 	             ;
logic                     wt_full            ;
logic                     wt_afull           ;
logic [SFIFO_ADDRW:0]	              fifo_count         ;
// lut signal
logic [15:0]              dma_lut_cs         ;
logic [15:0]              dma_lut_we         ;
logic [15:0][11:0]        dma_lut_addr       ;
logic [15:0][15:0]        dma_lut_din        ;
logic [15:0][1:0]         dma_lut_byte_en    ;
logic [15:0][15:0]        dma_lut_dout       ;

logic   [960-1:0]                           fifo_wt_in              ;
logic                                       fifo_req                ;


logic [REG_IDX-1:0]                         npu_wr_idx              ;
logic [REG_VAL-1:0]                         npu_wr_val              ;
logic                                       reg_inc                 ;
logic                                       conv_start              ;
logic                                       conv_busy               ;
logic                                       sel_cpu_npu             ;

logic                                       reg_CTRL1_en            ;
logic                                       reg_CTRL2_go            ;
logic                                       reg_CONV_MODE_upsample  ;
logic                                       reg_CONV_MODE_ch_st     ;
logic                                       reg_CONV_MODE_full_ch   ;
logic                                       reg_CONV_MODE_AB_order  ;
logic   [1:0]                               reg_CONV_MODE_trim      ;
logic   [7:0]                               reg_CONV_MODE_mode      ;
logic   [10:0]                              reg_FM_ROW_row          ; 
logic   [10:0]                              reg_FM_COL_col          ; 
logic   [11:0]                              reg_FM_ICH_ich          ; 
logic   [11:0]                              reg_FM_OCH_ST_och_st    ; 
logic   [11:0]                              reg_FM_OCH_ED_och_ed    ; 
logic   [1:0]                               reg_NL_MODE_LUT_en      ; 
logic   [2:0]                               reg_NL_MODE_nl_order    ;
logic                                       reg_NL_MODE_nl_en       ;
logic                                       reg_NL_MODE_bn_en       ;
logic                                       reg_NL_MODE_relu_en     ;
logic                                       reg_NL_MODE_pool_en     ;
logic   [1:0]                               reg_NL_MODE_relu_mode   ;
logic   [1:0]                               reg_NL_MODE_pool_stride ;
logic                                       reg_NL_MODE_pool_kernel ;
logic   [1:0]                               reg_NL_MODE_pool_mode   ;
logic   [1:0]                               reg_POOL_PAD_t          ;
logic   [1:0]                               reg_POOL_PAD_b          ;
logic   [1:0]                               reg_POOL_PAD_l          ;
logic   [1:0]                               reg_POOL_PAD_r          ;
logic   [10:0]                              reg_MEM_IN1_offset_x    ;
logic   [3:0]                               reg_MEM_IN1_offset_y    ;
logic   [10:0]                              reg_MEM_IN2_offset_x    ;
logic   [3:0]                               reg_MEM_IN2_offset_y    ;
logic   [10:0]                              reg_MEM_OUT_offset_x    ;
logic   [3:0]                               reg_MEM_OUT_offset_y    ;
logic   [7:0]                               reg_CROP_row_st         ;
logic   [7:0]                               reg_CROP_col_st         ;
logic   [10:0]                              reg_CROP_ROW_row_out    ;    
logic   [10:0]                              reg_CROP_COL_col_out    ;    
logic   [7:0]                               reg_PAD1_t              ;
logic   [7:0]                               reg_PAD1_b              ;
logic   [7:0]                               reg_PAD2_l              ;
logic   [7:0]                               reg_PAD2_r              ; 
logic   [10:0]                              reg_MEM_PSM_offset_x    ;
logic   [3:0]                               reg_MEM_PSM_offset_y    ;

//row_col_num_manager            
logic   [10:0]                              rbm_col_num_pe          ;
logic   [10:0]                              psum_row_num            ;
logic   [10:0]                              psum_col_num            ;
logic   [10:0]                              nl_row_num              ;
logic   [10:0]                              nl_col_num              ;

//bm
logic   [1:0]                               conv_finish_bm_o        ;       

logic [1:0][7:0][9:0][W_data-1:0]           fm_out_bm_o             ;
logic [1:0]                                 fm_out_irdy_bm_o        ;
logic [1:0]                                 fm_out_last_bm_o        ;
logic [1:0][9:0]                            fm_out_row_valid_bm_o   ;
logic [1:0][7:0]                            fm_out_ch_valid_bm_o    ;
logic   [1:0][3:0][7:0][15:0]               fm_out_nl_o             ;
logic   [1:0][7:0]                          fm_out_row_valid_nl_o   ;
logic   [1:0]                               fm_out_irdy_nl_o        ;
logic   [1:0]                               fm_in_trdy_bm_o         ;
logic   [1:0]                               fm_out_last_nl_o        ;
logic   [1:0][3:0]                          fm_out_ch_valid_nl_o    ;
logic   [1:0]                               datapath_finish_spad_o  ;
logic   [1:0]                               row_frame_p_nl_o        ;

logic   [1:0] [15:0]                        cs_spad_o                 ;
logic   [1:0] [15:0][15:0]                  byte_en_spad_o            ;
logic   [1:0] [15:0][10:0]                  addr_spad_o               ;
logic   [1:0] [15:0]                        we_spad_o              ;
logic   [1:0] [15:0][4*W_psum-1:0]          data_w_spad_o         ;
logic   [1:0] [15:0][4*W_psum-1:0]          data_r_arb_o          ;
logic   [1:0]                               data_trdy_arb_o                      ;

logic   [1:0][15:0]                         bankA_cs_bm_o           ;
logic   [1:0][15:0]                         bankA_we_bm_o           ;
logic   [1:0][15:0][10:0]                   bankA_addr_bm_o         ;
logic   [1:0][15:0][127:0]                  bankA_data_write_bm_o      ;
logic   [1:0][15:0][15:0]                   bankA_byte_enable_bm_o  ;
logic   [1:0][15:0][127:0]                  bankA_data_read_arb_o     ;
logic   [1:0][15:0]                         bankB_cs_bm_o           ;
logic   [1:0][15:0]                         bankB_we_bm_o           ;
logic   [1:0][15:0][10:0]                   bankB_addr_bm_o         ;
logic   [1:0][15:0][127:0]                  bankB_data_write_bm_o      ;
logic   [1:0][15:0][15:0]                   bankB_byte_enable_bm_o  ;
logic   [1:0][15:0][127:0]                  bankB_data_read_arb_o     ;

logic   [1:0][15:0]                         bankA_cs_arb_o          ;
logic   [1:0][15:0][15:0]                   bankA_byte_enable_arb_o     ;
logic   [1:0][15:0]                         bankA_we_arb_o       ; 
logic   [1:0][15:0][10:0]                   bankA_addr_arb_o        ; 
logic   [1:0][15:0][127:0]                  bankA_data_write_arb_o  ;
logic   [1:0][15:0][127:0]                  bankA_data_read_sram_o   ; 
logic   [1:0][15:0]                         bankB_cs_arb_o          ;
logic   [1:0][15:0][15:0]                   bankB_byte_enable_arb_o     ;
logic   [1:0][15:0]                         bankB_we_arb_o       ;
logic   [1:0][15:0][10:0]                   bankB_addr_arb_o        ; 
logic   [1:0][15:0][127:0]                  bankB_data_write_arb_o  ;
logic   [1:0][15:0][127:0]                  bankB_data_read_sram_o   ; 
logic [3:0][3:0][8:0][W_wt-1:0]              wt_i                   ;
logic [3:0]                                  pre_load_weight_rdy  ;
logic [3:0]                                  weight_load_req_o      ;
logic [3:0][2:0]                             count_conv_o           ;

logic [10:0]                            fm_row_num         ;
logic [3:0][7:0]                             row_frame_num_cu_o        ;
logic   fm_in_trdy_cu_o_0;
logic   [7:0][9:0][W_data-1:0]      fm_out_cu_o_0;
logic   fm_out_irdy_cu_o_0;
logic   fm_out_last_cu_o_0;
logic  [9:0]    fm_out_row_valid_cu_o_0;
logic   [7:0]   fm_out_ch_valid_cu_o_0;
logic           psum_in_trdy_cu_o_0;
logic [3:0][7:0][W_psum+2:0]            psum_out_cu_o_0                 ;
logic                                   psum_out_irdy_cu_o_0        ;
logic                                   psum_in_trdy_cu_o_2        ;
logic                                   psum_out_last_cu_o_0        ;
logic [7:0]                             psum_out_row_valid_cu_o_0       ;
logic [3:0]                             psum_out_ch_valid_cu_o_0       ;

logic [3:0][7:0][W_psum+2:0]            b_fm_out_cu_o_2              ;               
logic                                   b_fm_out_irdy_cu_o_2      ;          
logic                                   b_fm_out_last_cu_o_2      ;       
logic [7:0]                             b_fm_out_row_valid_cu_o_2    ;     
logic [3:0]                             b_fm_out_ch_valid_cu_o_2    ;     
logic [3:0][7:0][W_psum+2:0]            b_fm_out_cu_o_0              ;
logic                                   b_fm_out_irdy_cu_o_0     ;
logic                                   b_fm_in_trdy_cu_o_0      ;
logic                                   b_fm_out_last_cu_o_0     ;      
logic [7:0]                             b_fm_out_row_valid_cu_o_0    ;     
logic [3:0]                             b_fm_out_ch_valid_cu_o_0    ; 
logic   fm_in_trdy_cu_o_1;
logic   [7:0][9:0][W_data-1:0]      fm_out_cu_o_1;
logic   fm_out_irdy_cu_o_1;
logic   fm_out_last_cu_o_1;
logic  [9:0]    fm_out_row_valid_cu_o_1;
logic   [7:0]   fm_out_ch_valid_cu_o_1;
logic           psum_in_trdy_cu_o_1;
logic [3:0][7:0][W_psum+2:0]            psum_out_cu_o_1                 ;
logic                                   psum_out_irdy_cu_o_1        ;
logic                                   psum_in_trdy_cu_o_3        ;
logic                                   psum_out_last_cu_o_1        ;
logic [7:0]                             psum_out_row_valid_cu_o_1       ;
logic [3:0]                             psum_out_ch_valid_cu_o_1       ;
logic                                   fm_in_trdy_cu_o_3           ;
logic   [7:0][9:0][W_data-1:0]          fm_out_cu_o_3               ;
logic                                   fm_out_irdy_cu_o_3          ;
logic                                   fm_out_last_cu_o_3          ;
logic   [9:0]                           fm_out_row_valid_cu_o_3     ;
logic   [7:0]                           fm_out_ch_valid_cu_o_3      ;

logic [3:0][7:0][W_psum+2:0]            psum_out_cu_o_3             ;
logic                                   psum_out_irdy_cu_o_3        ;

logic                                   psum_out_last_cu_o_3        ;
logic [7:0]                             psum_out_row_valid_cu_o_3   ;
logic [3:0]                             psum_out_ch_valid_cu_o_3   ;  
logic                                   b_fm_in_trdy_cu_o_2         ; 
logic [3:0][7:0][W_psum+2:0]            b_fm_out_cu_o_3              ;
logic                                   b_fm_out_irdy_cu_o_3     ;
logic                                   b_fm_in_trdy_cu_o_3 ;
logic                                   b_fm_out_last_cu_o_3     ;      
logic [7:0]                             b_fm_out_row_valid_cu_o_3    ;     
logic [3:0]                             b_fm_out_ch_valid_cu_o_3    ;   

logic                                   fm_in_trdy_cu_o_2           ;
logic   [7:0][9:0][W_data-1:0]          fm_out_cu_o_2               ;
logic                                   fm_out_irdy_cu_o_2          ;
logic                                   fm_out_last_cu_o_2          ;
logic   [9:0]                           fm_out_row_valid_cu_o_2     ;
logic   [7:0]                           fm_out_ch_valid_cu_o_2      ;

logic [3:0][7:0][W_psum+2:0]            psum_out_cu_o_2             ;
logic                                   psum_out_irdy_cu_o_2        ;
logic                                   psum_out_last_cu_o_2        ;
logic [7:0]                             psum_out_row_valid_cu_o_2   ;
logic [3:0]                             psum_out_ch_valid_cu_o_2   ;  
          
logic [3:0][7:0][W_psum+2:0]            r_fm_out_cu_o_2              ;
logic                                   r_fm_out_irdy_cu_o_2     ;
logic                                   r_fm_in_trdy_cu_o_2     ;
logic                                   r_fm_out_last_cu_o_2 ;       
logic [7:0]                             r_fm_out_row_valid_cu_o_2    ;     
logic [3:0]                             r_fm_out_ch_valid_cu_o_2    ;    

logic [1:0]                             fm_in_trdy_spad_o;

logic [1:0][3:0][W_bn_beta-1:0]             bn_beta             ;
logic [1:0][3:0][W_bn_gamma-1:0]            bn_gama             ;
logic [1:0][3:0][W_bn_shift-1:0]            bn_shift            ;
logic [1:0][3:0][W_relu6_th-1:0]            relu6_threshold     ;
logic [1:0][3:0][W_prelu_alpha-1:0]         relu_prelu_a        ;

logic [1:0]                                 bn_load_req         ;
logic [1:0]                                 relu_load_req       ;

logic   [1:0][3:0]                         fm_out_ch_valid_lut_o  ;
logic   [1:0]   fm_out_last_spad_o;
logic   [1:0]   fm_out_irdy_spad_o;
logic   [1:0]   fm_in_trdy_lut_o;
logic   [1:0][7:0]  fm_out_row_valid_spad_o;
logic [1:0][3:0][15:0] psum_bias;
logic [1:0][3:0][3:0] psum_fine_shift;
logic [1:0][3:0][7:0][15:0] fm_out_spad_o;
logic [1:0][3:0]                              fm_out_ch_valid_spad_o;    

logic [1:0]                                 psum_load_req;
logic [1:0]                                 pre_load_param_rdy;
logic [1:0][3:0][2:0]                       psum_coarse_shift   ;

logic [1:0]                                 fm_in_trdy_nl_o          ;
logic [1:0]                                 fm_out_irdy_lut_o        ;
logic [1:0]                                 fm_out_last_lut_o        ;
logic [1:0][7:0]                            fm_out_row_valid_lut_o   ;
logic [1:0][3:0][7:0][15:0]                 fm_out_lut_o             ;

sramif u_sramif
(
    .ace_awready_o (s_axi_data_awready ),
    .ace_awvalid_i (s_axi_data_awvalid ),
    .ace_awid_i    (s_axi_data_awid    ), 
    .ace_awaddr_i  (s_axi_data_awaddr  ), 
    .ace_awlen_i   (s_axi_data_awlen   ),
    .ace_awsize_i  (s_axi_data_awsize  ),
    .ace_awburst_i (s_axi_data_awburst ),
    .ace_awlock_i  (s_axi_data_awlock  ),
    .ace_awcache_i (s_axi_data_awcache ),
    .ace_awprot_i  (s_axi_data_awprot  ),
    .ace_wready_o  (s_axi_data_wready  ),
    .ace_wvalid_i  (s_axi_data_wvalid  ),
    .ace_wdata_i   (s_axi_data_wdata   ),
    .ace_wstrb_i   (s_axi_data_wstrb   ),
    .ace_wlast_i   (s_axi_data_wlast   ),
    .ace_bready_i  (s_axi_data_bready  ),
    .ace_bvalid_o  (s_axi_data_bvalid  ),
    .ace_bid_o     (s_axi_data_bid     ),
    .ace_bresp_o   (s_axi_data_bresp   ),
    .ace_arready_o (s_axi_data_arready ),
    .ace_arvalid_i (s_axi_data_arvalid ),
    .ace_arid_i    (s_axi_data_arid    ),
    .ace_araddr_i  (s_axi_data_araddr  ),
    .ace_arlen_i   (s_axi_data_arlen   ),
    .ace_arsize_i  (s_axi_data_arsize  ),
    .ace_arburst_i (s_axi_data_arburst ),
    .ace_arlock_i  (s_axi_data_arlock  ),
    .ace_arcache_i (s_axi_data_arcache ),
    .ace_arprot_i  (s_axi_data_arprot  ),
    .ace_rready_i  (s_axi_data_rready  ),
    .ace_rvalid_o  (s_axi_data_rvalid  ),
    .ace_rid_o     (s_axi_data_rid     ),
    .ace_rdata_o   (s_axi_data_rdata   ),
    .ace_rresp_o   (s_axi_data_rresp   ),
    .ace_rlast_o   (s_axi_data_rlast   ),
    .clk           (axi_clk             ),//700MHz
    .reset_n       (rst_n           ),

    // npu axi register
    .fifo_count          ( fifo_count          ),
    
    // npu data sram interface
    .bankA_dma_cs        ( bankA_dma_cs         ),
    .bankA_dma_byte_en   ( bankA_dma_byte_en    ),
    .bankA_dma_addr      ( bankA_dma_addr       ),
    .bankA_dma_we        ( bankA_dma_en_we      ),
    .bankA_dma_din       ( bankA_dma_data_write ),
    .bankA_dma_dout      ( bankA_dma_data_read  ),
    .bankB_dma_cs        ( bankB_dma_cs         ),
    .bankB_dma_byte_en   ( bankB_dma_byte_en    ),
    .bankB_dma_addr      ( bankB_dma_addr       ),
    .bankB_dma_we        ( bankB_dma_en_we      ),
    .bankB_dma_din       ( bankB_dma_data_write ),
    .bankB_dma_dout      ( bankB_dma_data_read  ),

    // lut sram interface
    .dma_lut_cs          ( dma_lut_cs          ),
    .dma_lut_we          ( dma_lut_we          ),
    .dma_lut_addr        ( dma_lut_addr        ),
    .dma_lut_din         ( dma_lut_din         ),
    .dma_lut_byte_en     ( dma_lut_byte_en     ),
    .dma_lut_dout        ( dma_lut_dout        ),
    
    // npu reg interface
    .sys_addr            ( sys_addr            ),
    .sys_wr              ( sys_wr              ),
    .sys_wr_val          ( sys_wr_val          ),
    .sys_rd              ( sys_rd              ),
    .sys_ack             ( sys_ack             ),
    .sys_rd_val          ( sys_rd_val          ),

    // npu command sram interface
    .cmd_cs              ( cmd_cs              ),
    .cmd_we              ( cmd_we              ),
    .cmd_addr            ( cmd_addr            ),
    .cmd_out             ( cmd_out             ),
    .cmd                 ( cmd                 )
);


weightif u_weightif
(
    .clk        (clk                ),          
    .rst_n      (rst_n              ),
    .wt(wt),
    .wt_ready(wt_ready),
    .wt_valid(wt_valid),
     // weight fifo interface
    .wt_w       ( wt_w              ),
    .wt_full    ( wt_full           ),
    .wt_afull   ( wt_afull          ),
    .wt_in      ( wt_in             )
);



npu_buffer_manager u_bm0(
    .clk_i                      (clk                                ),          
    .rst_n                      (rst_n                              ),
    .conv_start_i               (conv_start                       ),
    .conv_finish_o              (conv_finish_bm_o[0]                   ),
    .bankA_cs_o                 (bankA_cs_bm_o[0]                      ),            
    .bankA_we_o                 (bankA_we_bm_o[0]                      ),
    .bankA_addr_o               (bankA_addr_bm_o[0]                    ),
    .bankA_data_in_o            (bankA_data_write_bm_o[0]                 ),
    .bankA_byte_enable_o        (bankA_byte_enable_bm_o[0]             ),
    .bankA_data_out_i           (bankA_data_read_arb_o[0]                ),
    .bankB_cs_o                 (bankB_cs_bm_o[0]                      ),
    .bankB_we_o                 (bankB_we_bm_o[0]                      ),
    .bankB_addr_o               (bankB_addr_bm_o[0]                    ),
    .bankB_data_in_o            (bankB_data_write_bm_o[0]                 ),
    .bankB_byte_enable_o        (bankB_byte_enable_bm_o[0]             ),
    .bankB_data_out_i           (bankB_data_read_arb_o[0]                ),
    .reg_CONV_MODE_mode         (reg_CONV_MODE_mode                 ),
    .reg_CONV_MODE_upsample     (reg_CONV_MODE_upsample             ),
    .reg_FM_ROW_row             (reg_FM_ROW_row                     ),
    .reg_FM_COL_col             (reg_FM_COL_col                     ),
    .reg_FM_ICH_ich             (reg_FM_ICH_ich                     ),
    .reg_FM_OCH_ST_och_st       (reg_FM_OCH_ST_och_st               ),
    .reg_FM_OCH_ED_och_ed       (reg_FM_OCH_ED_och_ed               ),
    .reg_CONV_MODE_AB_order     (reg_CONV_MODE_AB_order             ),
    .reg_MEM_IN1_offset_x       (reg_MEM_IN1_offset_x               ),
    .reg_MEM_IN1_offset_y       (reg_MEM_IN1_offset_y               ),
    .reg_MEM_IN2_offset_x       (reg_MEM_IN2_offset_x               ),
    .reg_MEM_IN2_offset_y       (reg_MEM_IN2_offset_y               ),
    .reg_MEM_OUT_offset_x       (reg_MEM_OUT_offset_x               ),
    .reg_MEM_OUT_offset_y       (reg_MEM_OUT_offset_y               ),
    .reg_CROP_row_st            (reg_CROP_row_st                    ),
    .reg_CROP_col_st            (reg_CROP_col_st                    ),
    .reg_CROP_ROW_row_out       (reg_CROP_ROW_row_out               ),
    .reg_CROP_COL_col_out       (reg_CROP_COL_col_out               ),
    .reg_PAD1_t                 (reg_PAD1_t                         ),
    .reg_PAD1_b                 (reg_PAD1_b                         ),
    .reg_PAD2_l                 (reg_PAD2_l                         ),
    .reg_PAD2_r                 (reg_PAD2_r                         ),
    .reg_CONV_MODE_ch_st            (reg_CONV_MODE_ch_st            ),
    .reg_CONV_MODE_full_ch      (reg_CONV_MODE_full_ch              ),
    .en_i                       (en || reg_CTRL1_en                               ),
    .nl_col_num_i               (nl_col_num                       ),
    .nl_row_num_i               (nl_row_num                       ), 
    .rbm_col_num_pe_i           (rbm_col_num_pe                   ), 
    .fm_out_o                   (fm_out_bm_o[0]                        ), 
    .fm_out_irdy_o              (fm_out_irdy_bm_o[0]                   ), 
    .fm_out_trdy_i              (fm_in_trdy_cu_o_0                   ), 
    .fm_out_last_o              (fm_out_last_bm_o[0]                   ), 
    .fm_out_row_valid_o         (fm_out_row_valid_bm_o[0]              ), 
    .fm_out_ch_valid_o          (fm_out_ch_valid_bm_o[0]               ), 
    .fm_in_i                    (fm_out_nl_o[0]                         ), 
    .fm_in_row_valid_i          (fm_out_row_valid_nl_o[0]               ), 
    .fm_in_irdy_i               (fm_out_irdy_nl_o[0]                    ), 
    .fm_in_trdy_o               (fm_in_trdy_bm_o[0]                    ), 
    .fm_in_last_i               (fm_out_last_nl_o[0]                    ), 
    .fm_in_ch_valid_i           (fm_out_ch_valid_nl_o[0]                ), 
    .datapath_finish_i          (datapath_finish_spad_o[0]               ), 
    .row_frame_p                (row_frame_p_nl_o[0]                     )   
);

npu_buffer_manager u_bm1(
    .clk_i                      (clk                                ),          
    .rst_n                      (rst_n                              ),
    .conv_start_i               (conv_start                       ),
    .conv_finish_o              (conv_finish_bm_o[1]                   ),
    .bankA_cs_o                 (bankA_cs_bm_o[1]                      ),            
    .bankA_we_o                 (bankA_we_bm_o[1]                      ),
    .bankA_addr_o               (bankA_addr_bm_o[1]                    ),
    .bankA_data_in_o            (bankA_data_write_bm_o[1]                 ),
    .bankA_byte_enable_o        (bankA_byte_enable_bm_o[1]             ),
    .bankA_data_out_i           (bankA_data_read_arb_o[1]                ),
    .bankB_cs_o                 (bankB_cs_bm_o[1]                      ),
    .bankB_we_o                 (bankB_we_bm_o[1]                      ),
    .bankB_addr_o               (bankB_addr_bm_o[1]                    ),
    .bankB_data_in_o            (bankB_data_write_bm_o[1]                 ),
    .bankB_byte_enable_o        (bankB_byte_enable_bm_o[1]             ),
    .bankB_data_out_i           (bankB_data_read_arb_o[1]                ),
    .reg_CONV_MODE_mode         (reg_CONV_MODE_mode                 ),
    .reg_CONV_MODE_upsample     (reg_CONV_MODE_upsample             ),
    .reg_FM_ROW_row             (reg_FM_ROW_row                     ),
    .reg_FM_COL_col             (reg_FM_COL_col                     ),
    .reg_FM_ICH_ich             (reg_FM_ICH_ich                     ),
    .reg_FM_OCH_ST_och_st       (reg_FM_OCH_ST_och_st               ),
    .reg_FM_OCH_ED_och_ed       (reg_FM_OCH_ED_och_ed               ),
    .reg_CONV_MODE_AB_order     (reg_CONV_MODE_AB_order             ),
    .reg_MEM_IN1_offset_x       (reg_MEM_IN1_offset_x               ),
    .reg_MEM_IN1_offset_y       (reg_MEM_IN1_offset_y               ),
    .reg_MEM_IN2_offset_x       (reg_MEM_IN2_offset_x               ),
    .reg_MEM_IN2_offset_y       (reg_MEM_IN2_offset_y               ),
    .reg_MEM_OUT_offset_x       (reg_MEM_OUT_offset_x               ),
    .reg_MEM_OUT_offset_y       (reg_MEM_OUT_offset_y               ),
    .reg_CROP_row_st            (reg_CROP_row_st                    ),
    .reg_CROP_col_st            (reg_CROP_col_st                    ),
    .reg_CROP_ROW_row_out       (reg_CROP_ROW_row_out               ),
    .reg_CROP_COL_col_out       (reg_CROP_COL_col_out               ),
    .reg_PAD1_t                 (reg_PAD1_t                         ),
    .reg_PAD1_b                 (reg_PAD1_b                         ),
    .reg_PAD2_l                 (reg_PAD2_l                         ),
    .reg_PAD2_r                 (reg_PAD2_r                         ),
    .reg_CONV_MODE_ch_st            (reg_CONV_MODE_ch_st            ),
    .reg_CONV_MODE_full_ch      (reg_CONV_MODE_full_ch              ),
    .en_i                       (en || reg_CTRL1_en                               ),
    .nl_col_num_i               (nl_col_num                       ),
    .nl_row_num_i               (nl_row_num                       ), 
    .rbm_col_num_pe_i           (rbm_col_num_pe                   ), 
    .fm_out_o                   (fm_out_bm_o[1]                        ), 
    .fm_out_irdy_o              (fm_out_irdy_bm_o[1]                   ), 
    .fm_out_trdy_i              (fm_in_trdy_cu_o_2                   ), 
    .fm_out_last_o              (fm_out_last_bm_o[1]                   ), 
    .fm_out_row_valid_o         (fm_out_row_valid_bm_o[1]              ), 
    .fm_out_ch_valid_o          (fm_out_ch_valid_bm_o[1]               ), 
    .fm_in_i                    (fm_out_nl_o[1]                         ), 
    .fm_in_row_valid_i          (fm_out_row_valid_nl_o[1]               ), 
    .fm_in_irdy_i               (fm_out_irdy_nl_o[1]                    ), 
    .fm_in_trdy_o               (fm_in_trdy_bm_o[1]                    ), 
    .fm_in_last_i               (fm_out_last_nl_o[1]                    ), 
    .fm_in_ch_valid_i           (fm_out_ch_valid_nl_o[1]                ), 
    .datapath_finish_i          (datapath_finish_spad_o[1]               ), 
    .row_frame_p                (row_frame_p_nl_o[1]                     )    
);

npu_ram_arbiter u_arb0(
    .clk                        (clk                            ),
    .rst_n                      (rst_n                          ),
    .cs_psum                    (cs_spad_o[0]                     ),
    .byte_en_psum               (byte_en_spad_o[0]                ),
    .addr_psum_wr               (addr_spad_o[0]                ),
    .we_en_psum                 (we_spad_o[0]                  ),
    .data_psum_w                (data_w_spad_o[0]                 ),
    .data_psum_r                (data_r_arb_o[0]                 ),
    .data_psum_trdy_o           (data_trdy_arb_o[0]            ),
    .bm_bankA_cs_i              (bankA_cs_bm_o[0]               ),
    .bm_bankA_we_i              (bankA_we_bm_o[0]               ),
    .bm_bankA_addr_i            (bankA_addr_bm_o[0]             ),
    .bm_bankA_data_in_i         (bankA_data_write_bm_o[0]          ),
    .bm_bankA_byte_enable_i     (bankA_byte_enable_bm_o[0]      ),
    .bm_bankA_data_out_o        (bankA_data_read_arb_o[0]         ),
    .bm_bankB_cs_i              (bankB_cs_bm_o[0]               ),
    .bm_bankB_we_i              (bankB_we_bm_o[0]               ),
    .bm_bankB_addr_i            (bankB_addr_bm_o[0]             ),
    .bm_bankB_data_in_i         (bankB_data_write_bm_o[0]          ),
    .bm_bankB_byte_enable_i     (bankB_byte_enable_bm_o[0]      ),
    .bm_bankB_data_out_o        (bankB_data_read_arb_o[0]         ),
    .sram_bankA_cs_o            (bankA_cs_arb_o[0]             ),
    .sram_bankA_byte_enable_o   (bankA_byte_enable_arb_o[0]    ),
    .sram_bankA_we_o            (bankA_we_arb_o[0]             ),
    .sram_bankA_addr_o          (bankA_addr_arb_o[0]           ),
    .sram_bankA_data_in_o       (bankA_data_write_arb_o[0]        ),
    .sram_bankA_data_out_i      (bankA_data_read_sram_o[0]       ),
    .sram_bankB_cs_o            (bankB_cs_arb_o[0]             ),
    .sram_bankB_byte_enable_o   (bankB_byte_enable_arb_o[0]    ),
    .sram_bankB_we_o            (bankB_we_arb_o[0]             ),
    .sram_bankB_addr_o          (bankB_addr_arb_o[0]           ),
    .sram_bankB_data_in_o       (bankB_data_write_arb_o[0]        ),
    .sram_bankB_data_out_i      (bankB_data_read_sram_o[0]       ),
    .reg_CONV_MODE_AB_order     (reg_CONV_MODE_AB_order         )
);

npu_ram_arbiter u_arb1(
    .clk                        (clk                            ),
    .rst_n                      (rst_n                          ),
    .cs_psum                    (cs_spad_o[1]                     ),
    .byte_en_psum               (byte_en_spad_o[1]                ),
    .addr_psum_wr               (addr_spad_o[1]                ),
    .we_en_psum                 (we_spad_o[1]                  ),
    .data_psum_w                (data_w_spad_o[1]                 ),
    .data_psum_r                (data_r_arb_o[1]                 ),
    .data_psum_trdy_o           (data_trdy_arb_o[1]            ),
    .bm_bankA_cs_i              (bankA_cs_bm_o[1]               ),
    .bm_bankA_we_i              (bankA_we_bm_o[1]               ),
    .bm_bankA_addr_i            (bankA_addr_bm_o[1]             ),
    .bm_bankA_data_in_i         (bankA_data_write_bm_o[1]          ),
    .bm_bankA_byte_enable_i     (bankA_byte_enable_bm_o[1]      ),
    .bm_bankA_data_out_o        (bankA_data_read_arb_o[1]         ),
    .bm_bankB_cs_i              (bankB_cs_bm_o[1]               ),
    .bm_bankB_we_i              (bankB_we_bm_o[1]               ),
    .bm_bankB_addr_i            (bankB_addr_bm_o[1]             ),
    .bm_bankB_data_in_i         (bankB_data_write_bm_o[1]          ),
    .bm_bankB_byte_enable_i     (bankB_byte_enable_bm_o[1]      ),
    .bm_bankB_data_out_o        (bankB_data_read_arb_o[1]         ),
    .sram_bankA_cs_o            (bankA_cs_arb_o[1]             ),
    .sram_bankA_byte_enable_o   (bankA_byte_enable_arb_o[1]    ),
    .sram_bankA_we_o            (bankA_we_arb_o[1]             ),
    .sram_bankA_addr_o          (bankA_addr_arb_o[1]           ),
    .sram_bankA_data_in_o       (bankA_data_write_arb_o[1]        ),
    .sram_bankA_data_out_i      (bankA_data_read_sram_o[1]       ),
    .sram_bankB_cs_o            (bankB_cs_arb_o[1]             ),
    .sram_bankB_byte_enable_o   (bankB_byte_enable_arb_o[1]    ),
    .sram_bankB_we_o            (bankB_we_arb_o[1]             ),
    .sram_bankB_addr_o          (bankB_addr_arb_o[1]           ),
    .sram_bankB_data_in_o       (bankB_data_write_arb_o[1]        ),
    .sram_bankB_data_out_i      (bankB_data_read_sram_o[1]       ),
    .reg_CONV_MODE_AB_order     (reg_CONV_MODE_AB_order         )
);



npu_buffer u_bf0(
    .clk             (clk                       ),
    .rstn            (rst_n                      ),
    .en              (en || reg_CTRL1_en                        ),
    .sel_cpu_npu     (sel_cpu_npu               ),
    .A_bm_cs         (bankA_cs_arb_o[0]           ),
    .A_bm_we         (bankA_we_arb_o[0]        ),
    .A_bm_addr       (bankA_addr_arb_o[0]         ),  
    .A_bm_din        (bankA_data_write_arb_o[0]   ),
    .A_bm_byte_en    (bankA_byte_enable_arb_o[0]      ),
    .A_bm_dout       (bankA_data_read_sram_o[0]    ),
    .B_bm_cs         (bankB_cs_arb_o[0]           ),
    .B_bm_we         (bankB_we_arb_o[0]        ),
    .B_bm_addr       (bankB_addr_arb_o[0]         ),
    .B_bm_din        (bankB_data_write_arb_o[0]   ),
    .B_bm_byte_en    (bankB_byte_enable_arb_o[0]      ),
    .B_bm_dout       (bankB_data_read_sram_o[0]    ),
    .A_dma_cs        (bankA_dma_cs[0]           ),
    .A_dma_we        (bankA_dma_en_we[0]        ),
    .A_dma_addr      (bankA_dma_addr[0]         ),
    .A_dma_din       (bankA_dma_data_write[0]   ),
    .A_dma_byte_en   (bankA_dma_byte_en[0]      ),
    .A_dma_dout      (bankA_dma_data_read[0]    ),
    .B_dma_cs        (bankB_dma_cs[0]           ),
    .B_dma_we        (bankB_dma_en_we[0]        ),
    .B_dma_addr      (bankB_dma_addr[0]         ),
    .B_dma_din       (bankB_dma_data_write[0]   ),
    .B_dma_byte_en   (bankB_dma_byte_en[0]      ),
    .B_dma_dout      (bankB_dma_data_read[0]    )
);

npu_buffer u_bf1(
    .clk             (clk                       ),
    .rstn            (rst_n                      ),
    .en              (en || reg_CTRL1_en                        ),
    .sel_cpu_npu     (sel_cpu_npu               ),
    .A_bm_cs         (bankA_cs_arb_o[1]           ),
    .A_bm_we         (bankA_we_arb_o[1]        ),
    .A_bm_addr       (bankA_addr_arb_o[1]         ),  
    .A_bm_din        (bankA_data_write_arb_o[1]   ),
    .A_bm_byte_en    (bankA_byte_enable_arb_o[1]      ),
    .A_bm_dout       (bankA_data_read_sram_o[1]    ),
    .B_bm_cs         (bankB_cs_arb_o[1]           ),
    .B_bm_we         (bankB_we_arb_o[1]        ),
    .B_bm_addr       (bankB_addr_arb_o[1]         ),
    .B_bm_din        (bankB_data_write_arb_o[1]   ),
    .B_bm_byte_en    (bankB_byte_enable_arb_o[1]),
    .B_bm_dout       (bankB_data_read_sram_o[1] ),
    .A_dma_cs        (bankA_dma_cs[1]           ),
    .A_dma_we        (bankA_dma_en_we[1]        ),
    .A_dma_addr      (bankA_dma_addr[1]         ),
    .A_dma_din       (bankA_dma_data_write[1]   ),
    .A_dma_byte_en   (bankA_dma_byte_en[1]      ),
    .A_dma_dout      (bankA_dma_data_read[1]    ),
    .B_dma_cs        (bankB_dma_cs[1]           ),
    .B_dma_we        (bankB_dma_en_we[1]        ),
    .B_dma_addr      (bankB_dma_addr[1]         ),
    .B_dma_din       (bankB_dma_data_write[1]   ),
    .B_dma_byte_en   (bankB_dma_byte_en[1]      ),
    .B_dma_dout      (bankB_dma_data_read[1]    )
);

npu_cu_top_old u_cu0 (
    .clk                    (clk                        ),
    .rst_n                  (rst_n                      ),
    .npu_en                 (en || reg_CTRL1_en                ),
    .mode                   (reg_CONV_MODE_mode             ),                  
    .trim                   (reg_CONV_MODE_trim             ),                  
    .fm_row_num_i           (fm_row_num            ), 
    .conv_finish_i          (conv_finish_bm_o[0]            ),           
    .row_frame_num_o        (row_frame_num_cu_o[0]      ),         
    .conv_dw_en_i           (1'b1                       ), 
    .conv_up_en_i           (1'b1                       ), 
    .fm_i                   (fm_out_bm_o[0]                ),                  
    .fm_in_irdy_i           (fm_out_irdy_bm_o[0]           ),          
    .fm_in_trdy_o           (fm_in_trdy_cu_o_0            ),          
    .fm_in_last_i           (fm_out_last_bm_o[0]            ),          
    .fm_row_valid_i         (fm_out_row_valid_bm_o[0]          ),        
    .fm_ich_valid_i         (fm_out_ch_valid_bm_o[0]          ),        
    .fm_o                   (fm_out_cu_o_0                    ),
    .fm_out_irdy_o          (fm_out_irdy_cu_o_0           ),
    .fm_out_last_o          (fm_out_last_cu_o_0           ),         
    .fm_row_valid_o         (fm_out_row_valid_cu_o_0          ),        
    .fm_ich_valid_o         (fm_out_ch_valid_cu_o_0          ),        
    .psum_i                 (1120'b0                  ),                
    .psum_in_irdy_i         (1'b1          ),        
    .psum_in_trdy_o         (psum_in_trdy_cu_o_0          ), 
    .psum_in_last_i         (1'b0         ),         
    .psum_o                 (psum_out_cu_o_0                  ),                
    .psum_out_irdy_o        (psum_out_irdy_cu_o_0         ),       
    .psum_out_trdy_i        (psum_in_trdy_cu_o_2         ),       
    .psum_out_last_o        (psum_out_last_cu_o_0         ),    
    .psum_row_valid_o       (psum_out_row_valid_cu_o_0        ),   
    .psum_och_valid_o       (psum_out_ch_valid_cu_o_0        ),   
    .wt_i                   (wt_i[0]                    ),                                   
    .pre_load_weight_rdy_i  (pre_load_weight_rdy[0]   ), 
    .weight_load_req_o      (weight_load_req_o[0]       ),       
    .count_conv_o           (count_conv_o[0]            ),
    .b_fm_i                 (b_fm_out_cu_o_2               ),
    .b_fm_in_irdy_i         (b_fm_out_irdy_cu_o_2       ),
    .b_fm_out_trdy_i        (fm_in_trdy_spad_o[0]      ),
    .b_fm_in_last_i         (b_fm_out_last_cu_o_2       ),
    .b_fm_row_valid_i       (b_fm_out_row_valid_cu_o_2     ),
    .b_fm_ich_valid_i       (b_fm_out_ch_valid_cu_o_2     ),
    .b_fm_o                 (b_fm_out_cu_o_0               ),
    .b_fm_out_irdy_o        (b_fm_out_irdy_cu_o_0      ),
    .b_fm_in_trdy_o         (b_fm_in_trdy_cu_o_0       ),
    .b_fm_out_last_o        (b_fm_out_last_cu_o_0      ),
    .b_fm_row_valid_o       (b_fm_out_row_valid_cu_o_0     ),
    .b_fm_ich_valid_o       (b_fm_out_ch_valid_cu_o_0     ),
    .r_fm_i                 (1120'b0    ),
    .r_fm_in_irdy_i         (1'b0    ),
    .r_fm_out_trdy_i        (1'b1    ),
    .r_fm_in_last_i         (1'b0    ),
    .r_fm_row_valid_i       (8'b0    ),
    .r_fm_ich_valid_i       (4'b0    ),
    .r_fm_o                 (    ),
    .r_fm_out_irdy_o        ( ),
    .r_fm_in_trdy_o         ( ),
    .r_fm_out_last_o        ( ),
    .r_fm_row_valid_o       ( ),
    .r_fm_ich_valid_o       ( )
);

npu_cu_top_old u_cu1 (
    .clk                    (clk                        ),                                                                                                                                                       
    .rst_n                  (rst_n                      ),
    .npu_en                 (en || reg_CTRL1_en                ),
    .conv_finish_i          (conv_finish_bm_o[1]           ),
    .mode                   (reg_CONV_MODE_mode             ),                  
    .trim                   (reg_CONV_MODE_trim             ),                  
    .fm_row_num_i           (fm_row_num            ),            
    .row_frame_num_o        (row_frame_num_cu_o[1]      ),         
    .conv_dw_en_i           (1'b0                       ), 
    .conv_up_en_i           (1'b1                       ), 
    .fm_i                   (fm_out_cu_o_0                    ),                  
    .fm_in_irdy_i           (fm_out_irdy_cu_o_0            ),          
    .fm_in_trdy_o           (fm_in_trdy_cu_o_1            ),           
    .fm_in_last_i           (fm_out_last_cu_o_0            ),          
    .fm_row_valid_i         (fm_out_row_valid_cu_o_0          ),        
    .fm_ich_valid_i         (fm_out_ch_valid_cu_o_0          ),        
    .fm_o                   (fm_out_cu_o_1                    ),
    .fm_out_irdy_o          (fm_out_irdy_cu_o_1           ),
    .fm_out_last_o          (fm_out_last_cu_o_1           ),         
    .fm_row_valid_o         (fm_out_row_valid_cu_o_1          ),        
    .fm_ich_valid_o         (fm_out_ch_valid_cu_o_1          ),        
    .psum_i                 (1120'b0                 ),                
    .psum_in_irdy_i         (1'b1         ),        
    .psum_in_trdy_o         (psum_in_trdy_cu_o_1          ),  
    .psum_in_last_i         (1'b0          ),        
    .psum_o                 (psum_out_cu_o_1                  ),                
    .psum_out_irdy_o        (psum_out_irdy_cu_o_1         ),       
    .psum_out_trdy_i        (psum_in_trdy_cu_o_3         ),       
    .psum_out_last_o        (psum_out_last_cu_o_1         ),
    .psum_row_valid_o       (psum_out_row_valid_cu_o_1        ),      
    .psum_och_valid_o       (psum_out_ch_valid_cu_o_1        ),      
    .wt_i                   (wt_i[1]                    ),                                
    .pre_load_weight_rdy_i  (pre_load_weight_rdy[1]   ), 
    .weight_load_req_o      (weight_load_req_o[1]       ),       
    .count_conv_o           (count_conv_o[1]            ),
    .b_fm_i                 (1120'b0    ),
    .b_fm_in_irdy_i         (1'b0    ),
    .b_fm_out_trdy_i        (1'b1    ),
    .b_fm_in_last_i         (1'b0    ),
    .b_fm_row_valid_i       (8'b0    ),
    .b_fm_ich_valid_i       (4'b0    ),
    .b_fm_o                 (        ),
    .b_fm_out_irdy_o        (     ),
    .b_fm_in_trdy_o         (     ),
    .b_fm_out_last_o        (     ),
    .b_fm_row_valid_o       (     ),
    .b_fm_ich_valid_o       (     ),
    .r_fm_i                 (1120'b0    ),
    .r_fm_in_irdy_i         (1'b0    ),
    .r_fm_out_trdy_i        (1'b1    ),
    .r_fm_in_last_i         (1'b0    ),
    .r_fm_row_valid_i       (8'b0    ),
    .r_fm_ich_valid_i       (4'b0    ),
    .r_fm_o                 (       ),
    .r_fm_out_irdy_o        (    ),
    .r_fm_in_trdy_o         (    ),
    .r_fm_out_last_o        (    ),
    .r_fm_row_valid_o       (    ),
    .r_fm_ich_valid_o       (    )
);

npu_cu_top_old3 u_cu2 (
    .clk                    (clk                        ),
    .rst_n                  (rst_n                      ),
    .npu_en                 (en || reg_CTRL1_en                ),
    .conv_finish_i          (conv_finish_bm_o[0]           ),
    .mode                   (reg_CONV_MODE_mode             ),                  
    .trim                   (reg_CONV_MODE_trim             ),                  
    .fm_row_num_i           (fm_row_num            ),                         
    .row_frame_num_o        (row_frame_num_cu_o[2]      ),         
    .conv_dw_en_i           (1'b0                       ), 
    .conv_up_en_i           (1'b0                       ), 
    .fm_i                   (fm_out_bm_o[1]                    ),                  
    .fm_in_irdy_i           (fm_out_irdy_bm_o[1]            ),          
    .fm_in_trdy_o           (fm_in_trdy_cu_o_2            ),           
    .fm_in_last_i           (fm_out_last_bm_o[1]           ),          
    .fm_row_valid_i         (fm_out_row_valid_bm_o[1]         ),        
    .fm_ich_valid_i         (fm_out_ch_valid_bm_o[1]          ),        
    .fm_o                   (fm_out_cu_o_2                   ),
    .fm_out_irdy_o          (fm_out_irdy_cu_o_2           ),
    .fm_out_last_o          (fm_out_last_cu_o_2           ),         
    .fm_row_valid_o         (fm_out_row_valid_cu_o_2          ),        
    .fm_ich_valid_o         (fm_out_ch_valid_cu_o_2          ),        
    .psum_i                 (psum_out_cu_o_0                 ),                
    .psum_in_irdy_i         (psum_out_irdy_cu_o_0          ),        
    .psum_in_trdy_o         (psum_in_trdy_cu_o_2         ),   
    .psum_in_last_i         (psum_out_last_cu_o_0          ),       
    .psum_o                 (psum_out_cu_o_2                  ),                
    .psum_out_irdy_o        (psum_out_irdy_cu_o_2         ),       
    .psum_out_trdy_i        (b_fm_in_trdy_cu_o_2        ),       
    .psum_out_last_o        (psum_out_last_cu_o_2         ),
    .psum_row_valid_o       (psum_out_row_valid_cu_o_2        ),      
    .psum_och_valid_o       (psum_out_ch_valid_cu_o_2        ),      
    .wt_i                   (wt_i[2]                    ),                                      
    .pre_load_weight_rdy_i  (pre_load_weight_rdy[2]   ), 
    .weight_load_req_o      (weight_load_req_o[2]       ),       
    .count_conv_o           (count_conv_o[2]            ),
    .b_fm_i                 (psum_out_cu_o_2               ),
    .b_fm_in_irdy_i         (psum_out_irdy_cu_o_2      ),
    .b_fm_out_trdy_i        (b_fm_in_trdy_cu_o_0     ),
    .b_fm_in_last_i         (psum_out_last_cu_o_2       ),
    .b_fm_row_valid_i       (psum_out_row_valid_cu_o_2     ),
    .b_fm_ich_valid_i       (psum_out_ch_valid_cu_o_2     ),
    .b_fm_o                 (b_fm_out_cu_o_2               ),
    .b_fm_out_irdy_o        (b_fm_out_irdy_cu_o_2      ),
    .b_fm_in_trdy_o         (b_fm_in_trdy_cu_o_2       ),
    .b_fm_out_last_o        (b_fm_out_last_cu_o_2      ),
    .b_fm_row_valid_o       (b_fm_out_row_valid_cu_o_2     ),
    .b_fm_ich_valid_o       (b_fm_out_ch_valid_cu_o_2     ),
    .r_fm_i                 (b_fm_out_cu_o_3               ),
    .r_fm_in_irdy_i         (b_fm_out_irdy_cu_o_3       ),
    .r_fm_out_trdy_i        (fm_in_trdy_spad_o[1]      ),
    .r_fm_in_last_i         (b_fm_out_last_cu_o_3       ),
    .r_fm_row_valid_i       (b_fm_out_row_valid_cu_o_3     ),
    .r_fm_ich_valid_i       (b_fm_out_ch_valid_cu_o_3     ),
    .r_fm_o                 (r_fm_out_cu_o_2               ),
    .r_fm_out_irdy_o        (r_fm_out_irdy_cu_o_2      ),
    .r_fm_in_trdy_o         (r_fm_in_trdy_cu_o_2       ),
    .r_fm_out_last_o        (r_fm_out_last_cu_o_2      ),
    .r_fm_row_valid_o       (r_fm_out_row_valid_cu_o_2     ),
    .r_fm_ich_valid_o       (r_fm_out_ch_valid_cu_o_2     )
); 

npu_cu_top_old3 u_cu3 (
    .clk                    (clk                        ),
    .rst_n                  (rst_n                      ),
    .npu_en                 (en || reg_CTRL1_en                ),
    .conv_finish_i          (conv_finish_bm_o[1]           ),
    .mode                   (reg_CONV_MODE_mode             ),                  
    .trim                   (reg_CONV_MODE_trim             ),                  
    .fm_row_num_i           (fm_row_num            ),            
    .row_frame_num_o        (row_frame_num_cu_o[3]      ),         
    .conv_dw_en_i           (1'b1                       ), 
    .conv_up_en_i           (1'b0                       ), 
    .fm_i                   (fm_out_cu_o_2                    ),                  
    .fm_in_irdy_i           (fm_out_irdy_cu_o_2            ),          
    .fm_in_trdy_o           (fm_in_trdy_cu_o_3            ),           
    .fm_in_last_i           (fm_out_last_cu_o_2            ),          
    .fm_row_valid_i         (fm_out_row_valid_cu_o_2          ),        
    .fm_ich_valid_i         (fm_out_ch_valid_cu_o_2         ),        
    .fm_o                   (fm_out_cu_o_3                   ),
    .fm_out_irdy_o          (fm_out_irdy_cu_o_3          ),
    .fm_out_last_o          (fm_out_last_cu_o_3           ),         
    .fm_row_valid_o         (fm_out_row_valid_cu_o_3          ),        
    .fm_ich_valid_o         (fm_out_ch_valid_cu_o_3         ),        
    .psum_i                 (psum_out_cu_o_1                  ),                
    .psum_in_irdy_i         (psum_out_irdy_cu_o_1         ),        
    .psum_in_trdy_o         (psum_in_trdy_cu_o_3         ),
    .psum_in_last_i         (psum_out_last_cu_o_1          ),         
    .psum_o                 (psum_out_cu_o_3                  ),                
    .psum_out_irdy_o        (psum_out_irdy_cu_o_3         ),       
    .psum_out_trdy_i        (b_fm_in_trdy_cu_o_3         ),       
    .psum_out_last_o        (psum_out_last_cu_o_3         ),
    .psum_row_valid_o       (psum_out_row_valid_cu_o_3        ),      
    .psum_och_valid_o       (psum_out_ch_valid_cu_o_3        ),      
    .wt_i                   (wt_i[3]                    ),                                    
    .pre_load_weight_rdy_i  (pre_load_weight_rdy[3]   ), 
    .weight_load_req_o      (weight_load_req_o[3]       ),       
    .count_conv_o           (count_conv_o[3]            ),
    .b_fm_i                 (psum_out_cu_o_3            ),
    .b_fm_in_irdy_i         (psum_out_irdy_cu_o_3            ),
    .b_fm_out_trdy_i        (r_fm_in_trdy_cu_o_2         ),
    .b_fm_in_last_i         (psum_out_last_cu_o_3          ),
    .b_fm_row_valid_i       (psum_out_row_valid_cu_o_3        ),
    .b_fm_ich_valid_i       (psum_out_ch_valid_cu_o_3        ),
    .b_fm_o                 (b_fm_out_cu_o_3                  ),
    .b_fm_out_irdy_o        (b_fm_out_irdy_cu_o_3         ),
    .b_fm_in_trdy_o         (b_fm_in_trdy_cu_o_3          ),
    .b_fm_out_last_o        (b_fm_out_last_cu_o_3         ),
    .b_fm_row_valid_o       (b_fm_out_row_valid_cu_o_3        ),
    .b_fm_ich_valid_o       (b_fm_out_ch_valid_cu_o_3        ),
    .r_fm_i                 (1120'b0    ),
    .r_fm_in_irdy_i         (1'b0    ),
    .r_fm_out_trdy_i        (1'b1    ),
    .r_fm_in_last_i         (1'b0    ),
    .r_fm_row_valid_i       (8'b0    ),
    .r_fm_ich_valid_i       (4'b0    ),
    .r_fm_o                 (    ),
    .r_fm_out_irdy_o        ( ),
    .r_fm_in_trdy_o         ( ),
    .r_fm_out_last_o        ( ),
    .r_fm_row_valid_o       ( ),
    .r_fm_ich_valid_o       ( )
);

npu_scratchpad u_spad0(
    .clk                    (clk),
    .rst_n                  (rst_n),
    .mode                   (reg_CONV_MODE_mode),
    .trim                   (reg_CONV_MODE_trim),                 
    .fm_i                   (b_fm_out_cu_o_0),                 
    .fm_in_last_i           (b_fm_out_last_cu_o_0),         
    .fm_out_last_o_nl       (fm_out_last_spad_o[0]),
    .row_frame_num          (row_frame_num_cu_o[2]),
    .row_col_num            (psum_col_num),         
    .fm_ich_num             (reg_FM_ICH_ich),
    .fm_in_irdy_i           (b_fm_out_irdy_cu_o_0),         
    .fm_in_trdy_o_cu        (fm_in_trdy_spad_o[0]),         
    .fm_out_irdy_o_nl       (fm_out_irdy_spad_o[0]),     
    .fm_out_trdy_i_nl       (fm_in_trdy_lut_o[0]),  
    .fm_out_trdy_i_arb      (data_trdy_arb_o[0]),       
    .fm_row_valid_i         (b_fm_out_row_valid_cu_o_0),      // 
    .fm_row_valid_o         (fm_out_row_valid_spad_o[0]),       
    .bias                   (psum_bias[0]),
    .fine_shift             (psum_fine_shift[0]),
    .fm_o                   (fm_out_spad_o[0]),                 
    .fm_och_valid_o         (fm_out_ch_valid_spad_o[0]),       
    .fm_ich_valid_i         (b_fm_out_ch_valid_cu_o_0),
    .ch_st                  (reg_CONV_MODE_ch_st),                
    .full_ch                (reg_CONV_MODE_full_ch),              
    .datapath_finish_o      (datapath_finish_spad_o[0]),
    .psum_load_req_o        (psum_load_req[0]),
    .param_rdy              (pre_load_param_rdy[0]),
    .npu_en                 (en || reg_CTRL1_en),
    .conv_finish            (conv_finish_bm_o[0]),
    .conv_start             (conv_start),
    .cs_o                   (cs_spad_o[0]          ),
    .byte_en_o              (byte_en_spad_o[0]     ),
    .en_we_o                (we_spad_o[0]       ),
    .addr_o                 (addr_spad_o[0]),
    .data_write_o           (data_w_spad_o[0]),
    .data_read_i            (data_r_arb_o[0]),
    .coarse_shift_value     (psum_coarse_shift[0]),
    .offset_x               (reg_MEM_PSM_offset_x        ),
    .offset_y               (reg_MEM_PSM_offset_y        ) 
);

npu_scratchpad u_spad1(
    .clk                    (clk),
    .rst_n                  (rst_n),
    .mode                   (reg_CONV_MODE_mode),
    .trim                   (reg_CONV_MODE_trim),                 
    .fm_i                   (r_fm_out_cu_o_2),                 
    .fm_in_last_i           (r_fm_out_last_cu_o_2),         
    .fm_out_last_o_nl       (fm_out_last_spad_o[1]),
    .row_frame_num          (row_frame_num_cu_o[3]),
    .row_col_num            (psum_col_num),         
    .fm_ich_num             (reg_FM_ICH_ich),
    .fm_in_irdy_i           (r_fm_out_irdy_cu_o_2),         
    .fm_in_trdy_o_cu        (fm_in_trdy_spad_o[1]),         
    .fm_out_irdy_o_nl       (fm_out_irdy_spad_o[1]),     
    .fm_out_trdy_i_nl       (fm_in_trdy_lut_o[1]),  
    .fm_out_trdy_i_arb      (data_trdy_arb_o[1]),       
    .fm_row_valid_i         (r_fm_out_row_valid_cu_o_2),      // 
    .fm_row_valid_o         (fm_out_row_valid_spad_o[1]),      
    .bias                   (psum_bias[1]),
    .fine_shift             (psum_fine_shift[1]),
    .fm_o                   (fm_out_spad_o[1]),                 
    .fm_och_valid_o         (fm_out_ch_valid_spad_o[1]),       
    .fm_ich_valid_i         (r_fm_out_ch_valid_cu_o_2),
    .ch_st                  (reg_CONV_MODE_ch_st),                
    .full_ch                (reg_CONV_MODE_full_ch),              
    .datapath_finish_o      (datapath_finish_spad_o[1]),
    .psum_load_req_o        (psum_load_req[1]),
    .param_rdy              (pre_load_param_rdy[1]),
    .npu_en                 (en || reg_CTRL1_en),
    .conv_finish            (conv_finish_bm_o[1]),
    .conv_start             (conv_start),
    .cs_o                   (cs_spad_o[1]          ),
    .byte_en_o              (byte_en_spad_o[1]     ),
    .en_we_o                (we_spad_o[1]       ),
    .addr_o                 (addr_spad_o[1]),
    .data_write_o           (data_w_spad_o[1]),
    .data_read_i            (data_r_arb_o[1]),
    .coarse_shift_value     (psum_coarse_shift[1]),
    .offset_x               (reg_MEM_PSM_offset_x        ),
    .offset_y               (reg_MEM_PSM_offset_y        ) 
);

npu_lut u_lut
(
    .clk                  ( clk                         ),
    .rst_n                ( rst_n                       ),
    .sel_cpu_npu          ( sel_cpu_npu                 ),
    .dma_lut_cs           ( dma_lut_cs                 ),
    .dma_lut_we           ( dma_lut_we                 ),
    .dma_lut_addr         ( dma_lut_addr               ),
    .dma_lut_din          ( dma_lut_din                ),
    .dma_lut_byte_en      ( dma_lut_byte_en            ),
    .dma_lut_dout         ( dma_lut_dout               ),
    .fm_in_irdy_i         ( fm_out_irdy_spad_o          ), //fm_out_irdy_o_nl
    .fm_in_last_i         ( fm_out_last_spad_o          ), //fm_out_last_o_nl
    .fm_out_trdy_i        ( fm_in_trdy_nl_o            ),
    .fm_out_irdy_o        ( fm_out_irdy_lut_o            ),
    .fm_out_last_o        ( fm_out_last_lut_o            ),
    .fm_in_trdy_o         ( fm_in_trdy_lut_o          ),//fm_out_trdy_i_nl
    .fm_row_valid_i       ( fm_out_row_valid_spad_o     ),//fm_row_valid_o_nl
    .fm_ich_valid_i       ( fm_out_ch_valid_spad_o      ),//fm_och_valid_o_nl
    .fm_row_valid_o       ( fm_out_row_valid_lut_o      ),
    .fm_och_valid_o       ( fm_out_ch_valid_lut_o        ),
    .lut_en               ( reg_NL_MODE_LUT_en          ), 
    .fm_i                 ( fm_out_spad_o               ),//fm_o_nl
    .fm_o                 ( fm_out_lut_o                 ),
    .npu_en               ( en || reg_CTRL1_en                      ),
    .conv_finish          ( conv_finish_bm_o[1]              )
);

npu_nl u_nl0(
    .clk                   ( clk                            ),                   
    .rst_n                 ( rst_n                          ),
    .nl_en_i               ( reg_NL_MODE_nl_en              ),               
    .reg_order_i           ( reg_NL_MODE_nl_order           ),          
    .bn_en_i               ( reg_NL_MODE_bn_en              ),               
    .pool_en_i             ( reg_NL_MODE_pool_en            ),             
    .pool_stride_i         ( reg_NL_MODE_pool_stride        ),
    .pool_kernel_i         ( reg_NL_MODE_pool_kernel        ),
    .pool_mode_i           ( reg_NL_MODE_pool_mode          ),
    .pool_pad_t_i          ( reg_POOL_PAD_t                 ),          
    .pool_pad_b_i          ( reg_POOL_PAD_b                 ),
    .pool_pad_l_i          ( reg_POOL_PAD_l                 ),
    .relu_en_i             ( reg_NL_MODE_relu_en            ),             
    .relu_mode_i           ( reg_NL_MODE_relu_mode          ),
    .bn_beta_i             ( bn_beta[0]                     ),
    .bn_gama_i             ( bn_gama[0]                     ),
    .bn_shift_i            ( bn_shift[0]                    ),
    .relu6_threshold_i     ( relu6_threshold[0]             ),
    .relu_prelu_a_i        ( relu_prelu_a[0]                ),
    .fm_in_trdy_o          ( fm_in_trdy_nl_o[0]            ),
    .fm_in_irdy_i          ( fm_out_irdy_lut_o[0]            ),	       
    .fm_in_i               ( fm_out_lut_o[0]                 ),   		       
    .fm_in_last_i          ( fm_out_last_lut_o[0]            ),	       
    .fm_in_row_valid_i     ( fm_out_row_valid_lut_o[0]       ),      
    .fm_in_ch_valid_i      ( fm_out_ch_valid_lut_o[0]        ),      
    .fm_out_trdy_i         ( fm_in_trdy_bm_o[0]      ),
    .fm_out_irdy_o         ( fm_out_irdy_nl_o[0]      ),	       
    .fm_out_o              ( fm_out_nl_o[0]           ),		       
    .fm_out_last_o         ( fm_out_last_nl_o[0]      ),	       
    .fm_out_row_valid_o    ( fm_out_row_valid_nl_o[0] ),    	
    .fm_out_ch_valid_o     ( fm_out_ch_valid_nl_o[0]  ),      
    .conv_trim             ( reg_CONV_MODE_trim             ),
    .cu2nl_row_num         ( psum_row_num                   ),
    .cu2nl_col_num         ( psum_col_num                   ),
    .row_frame_num         ( row_frame_num_cu_o[2]          ),
    .nl2wbm_col_num        ( nl_col_num                     ),
    .conv_start            ( conv_start                     ),
    .bn_load_req_o         ( bn_load_req[0]                 ),
    .relu_load_req_o       ( relu_load_req[0]               ),
    .param_rdy             ( pre_load_param_rdy[0]          ),
    .row_frame_p           ( row_frame_p_nl_o[0]                 ),
    .npu_en                ( en || reg_CTRL1_en                         ),
    .conv_finish           ( conv_finish_bm_o[0]                 )
);

npu_nl u_nl1(
    .clk                   ( clk                            ),                   
    .rst_n                 ( rst_n                          ),
    .nl_en_i               ( reg_NL_MODE_nl_en              ),               
    .reg_order_i           ( reg_NL_MODE_nl_order           ),          
    .bn_en_i               ( reg_NL_MODE_bn_en              ),               
    .pool_en_i             ( reg_NL_MODE_pool_en            ),             
    .pool_stride_i         ( reg_NL_MODE_pool_stride        ),
    .pool_kernel_i         ( reg_NL_MODE_pool_kernel        ),
    .pool_mode_i           ( reg_NL_MODE_pool_mode          ),
    .pool_pad_t_i          ( reg_POOL_PAD_t                 ),          
    .pool_pad_b_i          ( reg_POOL_PAD_b                 ),
    .pool_pad_l_i          ( reg_POOL_PAD_l                 ),
    .relu_en_i             ( reg_NL_MODE_relu_en            ),             
    .relu_mode_i           ( reg_NL_MODE_relu_mode          ),
    .bn_beta_i             ( bn_beta[1]                     ),
    .bn_gama_i             ( bn_gama[1]                     ),
    .bn_shift_i            ( bn_shift[1]                    ),
    .relu6_threshold_i     ( relu6_threshold[1]             ),
    .relu_prelu_a_i        ( relu_prelu_a[1]                ),
    .fm_in_trdy_o          ( fm_in_trdy_nl_o[1]            ),
    .fm_in_irdy_i          ( fm_out_irdy_lut_o[1]            ),	       
    .fm_in_i               ( fm_out_lut_o[1]                 ),   		       
    .fm_in_last_i          ( fm_out_last_lut_o[1]            ),	       
    .fm_in_row_valid_i     ( fm_out_row_valid_lut_o[1]       ),      
    .fm_in_ch_valid_i      ( fm_out_ch_valid_lut_o[1]        ),      
    .fm_out_trdy_i         ( fm_in_trdy_bm_o[1]      ),
    .fm_out_irdy_o         ( fm_out_irdy_nl_o[1]      ),	       
    .fm_out_o              ( fm_out_nl_o[1]           ),		       
    .fm_out_last_o         ( fm_out_last_nl_o[1]      ),	       
    .fm_out_row_valid_o    ( fm_out_row_valid_nl_o[1] ),    	
    .fm_out_ch_valid_o     ( fm_out_ch_valid_nl_o[1]  ),      
    .conv_trim             ( reg_CONV_MODE_trim             ),
    .cu2nl_row_num         ( psum_row_num                   ),
    .cu2nl_col_num         ( psum_col_num                   ),
    .row_frame_num         ( row_frame_num_cu_o[3]          ),
    .nl2wbm_col_num        ( nl_col_num                     ),
    .conv_start            ( conv_start                     ),
    .bn_load_req_o         ( bn_load_req[1]                 ),
    .relu_load_req_o       ( relu_load_req[1]               ),
    .param_rdy             ( pre_load_param_rdy[1]          ),
    .row_frame_p           ( row_frame_p_nl_o[1]                 ),
    .npu_en                ( en || reg_CTRL1_en                         ),
    .conv_finish           ( conv_finish_bm_o[1]                 )
);

npu_wt_array u_wt(
    .clk                    (clk                        ),
    .rst_n                  (rst_n                      ),
    .fifo_i                 (fifo_wt_in                    ),
    .weight_load_req_i      (weight_load_req_o       ),
    .mode                   (reg_CONV_MODE_mode                       ),
    .wt_pre_rdy_o           (pre_load_weight_rdy   ),
    .cu_wt_out              (wt_i                    ),
    .conv_idx               (count_conv_o            ),
    .psum_load_req_i        (psum_load_req              ),
    .bn_load_req_i          (bn_load_req                ),
    .relu_load_req_i        (relu_load_req              ),
    .psum_coarse_shift_o    (psum_coarse_shift          ),
    .psum_bias_o            (psum_bias                  ),
    .psum_fine_shift_o      (psum_fine_shift            ),
    .bn_beta_o              (bn_beta                    ),
    .bn_gama_o              (bn_gama                    ),
    .bn_shift_o             (bn_shift                   ),
    .relu6_threshold_o      (relu6_threshold            ),
    .relu_prelu_a_o         (relu_prelu_a               ),
    .pre_load_param_rdy_o   (pre_load_param_rdy         ),
    .fifo_req_o             (fifo_req                   ),
    .conv_finish            (conv_finish_bm_o[1]             ),
    .fm_och_num_st          (reg_FM_OCH_ST_och_st              ),
    .fm_och_num_ed          (reg_FM_OCH_ED_och_ed              ),
    .fm_ich_num             (reg_FM_ICH_ich                 ),
    .nl_order               (reg_NL_MODE_nl_order       ),
    .nl_en                  (reg_NL_MODE_nl_en          ),
    .bn_en                  (reg_NL_MODE_bn_en          ),
    .relu_en                (reg_NL_MODE_relu_en        ),
    .fifo_count             (fifo_count                 ),
    .conv_busy_i            (conv_busy                ),
    .npu_en                 (en || reg_CTRL1_en                     ),
    .conv_start             (conv_start                 )
);

npu_cm #(
    .CMD_LEN          ( CMD_LEN            ),
	.CMD_DEPTH        ( CMD_DEPTH          ),
    .INT_NUM          ( INT_NUM            ),
    .REG_IDX          ( REG_IDX            ),
    .REG_VAL          ( REG_VAL            )
) u_npu_cm (
    .clk              ( clk                ),
    .rst_n            ( rst_n              ),
    .enable           ( en || reg_CTRL1_en ), // Launch
    .go               ( go || reg_CTRL2_go ), // Launch
    //.cmd_fifo_write   ( cmd_fifo_write     ), // Command FIFO
    //.cmd              ( cmd                ), // Command FIFO
    //.cmd_fifo_full    ( cmd_fifo_full      ), // Command FIFO
    //.cmd_fifo_empty   ( cmd_fifo_empty     ), // Command FIFO
    .cmd_cs           ( cmd_cs             ), // SRAM External Interface
    .cmd_we           ( cmd_we             ), // SRAM External Interface
    .cmd_addr         ( cmd_addr           ), // SRAM External Interface
    .cmd              ( cmd                ), // SRAM External Interface
    .cmd_out          ( cmd_out            ),
	.npu_wr_idx       ( npu_wr_idx         ), // Internal Control
    .npu_wr_val       ( npu_wr_val         ), // Internal Control
    .reg_inc          ( reg_inc            ),  // Internal Control for NPU
    .interrupt        ( interrupt          ), // Internal Control
    .conv_start       ( conv_start         ), // Internal Control
    .conv_busy        ( conv_busy          ), // Internal Control  
    .conv_end         ( conv_finish_bm_o[1]           ), // Internal Control
    .sel_cpu_npu      ( sel_cpu_npu        )
);

npu_reg #(
    .REG_IDX       ( REG_IDX        ),
    .REG_VAL       ( REG_VAL        )
) u_npu_reg (
    .clk                        ( clk                       ),
    .rst_n                      ( rst_n                     ),
    .base_reg_addr              ( 'b0             ), 
    .sys_addr                   ( sys_addr                  ), 
    .sys_wr                     ( sys_wr                    ), 
    .sys_rd                     ( sys_rd                    ), 
    .sys_wr_val                 ( sys_wr_val                ), 
    .sys_ack                    ( sys_ack                   ), 
    .sys_rd_val                 ( sys_rd_val                ), 
    .npu_wr_idx                 ( npu_wr_idx                ), 
    .npu_wr_val                 ( npu_wr_val                ), 
    .reg_inc                    ( reg_inc                   ), 
	.sel_cpu_npu                ( sel_cpu_npu               ), 
    .reg_CTRL1_en               ( reg_CTRL1_en              ), 
    .reg_CTRL2_go               ( reg_CTRL2_go              ), 
    .reg_CONV_MODE_upsample     (reg_CONV_MODE_upsample     ),
    .reg_CONV_MODE_ch_st        (reg_CONV_MODE_ch_st        ),
    .reg_CONV_MODE_full_ch      (reg_CONV_MODE_full_ch      ),
    .reg_CONV_MODE_AB_order     ( reg_CONV_MODE_AB_order    ), 
    .reg_CONV_MODE_trim         ( reg_CONV_MODE_trim        ), 
    .reg_CONV_MODE_mode         ( reg_CONV_MODE_mode        ), 
    .reg_FM_ROW_row             ( reg_FM_ROW_row            ), 
    .reg_FM_COL_col             ( reg_FM_COL_col            ), 
    .reg_FM_ICH_ich             ( reg_FM_ICH_ich            ), 
    .reg_FM_OCH_ST_och_st       ( reg_FM_OCH_ST_och_st      ), 
    .reg_FM_OCH_ED_och_ed       ( reg_FM_OCH_ED_och_ed      ), 
    .reg_NL_MODE_LUT_en         ( reg_NL_MODE_LUT_en        ),
    .reg_NL_MODE_nl_order       ( reg_NL_MODE_nl_order      ),
    .reg_NL_MODE_nl_en          ( reg_NL_MODE_nl_en         ), 
    .reg_NL_MODE_bn_en          ( reg_NL_MODE_bn_en         ), 
    .reg_NL_MODE_relu_en        ( reg_NL_MODE_relu_en       ), 
    .reg_NL_MODE_pool_en        ( reg_NL_MODE_pool_en       ), 
    .reg_NL_MODE_relu_mode      ( reg_NL_MODE_relu_mode     ), 
    .reg_NL_MODE_pool_stride    ( reg_NL_MODE_pool_stride   ), 
    .reg_NL_MODE_pool_kernel    ( reg_NL_MODE_pool_kernel   ), 
    .reg_NL_MODE_pool_mode      ( reg_NL_MODE_pool_mode     ), 
    .reg_POOL_PAD_t             ( reg_POOL_PAD_t            ), 
    .reg_POOL_PAD_b             ( reg_POOL_PAD_b            ), 
    .reg_POOL_PAD_l             ( reg_POOL_PAD_l            ), 
    .reg_POOL_PAD_r             ( reg_POOL_PAD_r            ), 
    .reg_MEM_IN1_offset_x       ( reg_MEM_IN1_offset_x      ), 
    .reg_MEM_IN1_offset_y       ( reg_MEM_IN1_offset_y      ), 
    .reg_MEM_IN2_offset_x       ( reg_MEM_IN2_offset_x      ), 
    .reg_MEM_IN2_offset_y       ( reg_MEM_IN2_offset_y      ), 
    .reg_MEM_OUT_offset_x       ( reg_MEM_OUT_offset_x      ), 
    .reg_MEM_OUT_offset_y       ( reg_MEM_OUT_offset_y      ), 
    .reg_CROP_row_st            ( reg_CROP_row_st           ), 
    .reg_CROP_col_st            ( reg_CROP_col_st           ), 
    .reg_CROP_ROW_row_out       ( reg_CROP_ROW_row_out      ), 
    .reg_CROP_COL_col_out       ( reg_CROP_COL_col_out      ), 
    .reg_PAD1_t                 ( reg_PAD1_t                ), 
    .reg_PAD1_b                 ( reg_PAD1_b                ), 
    .reg_PAD2_l                 ( reg_PAD2_l                ), 
    .reg_PAD2_r                 ( reg_PAD2_r                ), 
    .reg_MEM_PSM_offset_x       (reg_MEM_PSM_offset_x       ),
    .reg_MEM_PSM_offset_y       (reg_MEM_PSM_offset_y       )
);

npu_row_col_num_manager u_npu_row_col_num_manager(
    .clk                        ( clk                    ),
    .rst_n                      ( rst_n                  ),
    .reg_CONV_MODE_upsample     (reg_CONV_MODE_upsample  ),
    .reg_CONV_MODE_trim         (reg_CONV_MODE_trim      ),
    .reg_CONV_MODE_mode         (reg_CONV_MODE_mode      ),
    .reg_CROP_ROW_row_out       (reg_CROP_ROW_row_out    ),
    .reg_CROP_COL_col_out       (reg_CROP_COL_col_out    ),
    .reg_PAD1_t                 (reg_PAD1_t              ),
    .reg_PAD1_b                 (reg_PAD1_b              ),
    .reg_PAD2_l                 (reg_PAD2_l              ),
    .reg_PAD2_r                 (reg_PAD2_r              ),
    .reg_NL_MODE_nl_en          (reg_NL_MODE_nl_en       ),
    .reg_NL_MODE_pool_en        (reg_NL_MODE_pool_en     ),
    .reg_NL_MODE_pool_stride    (reg_NL_MODE_pool_stride ),
    .reg_NL_MODE_pool_kernel    (reg_NL_MODE_pool_kernel ),
    .reg_POOL_PAD_t             (reg_POOL_PAD_t          ),
    .reg_POOL_PAD_b             (reg_POOL_PAD_b          ),
    .reg_POOL_PAD_l             (reg_POOL_PAD_l          ),
    .reg_POOL_PAD_r             (reg_POOL_PAD_r          ),
    .rbm_row_num_o              (fm_row_num             ),
    .rbm_col_num_pe_o           (rbm_col_num_pe          ),
    .psum_row_num_o             (psum_row_num            ),
    .psum_col_num_o             (psum_col_num            ),
    .nl_row_num_o               (nl_row_num              ),
    .nl_col_num_o               (nl_col_num              )
);

wdec #(
    .DATA_WIDTH       ( WINWIDTH           ),
	.WEIGHT_WIDTH     ( WWIDTH             ),
    .AFIFO_WIDTH      ( WINWIDTH           ),
    .AFIFO_DEPTH      ( AFIFO_DEPTH        ),
    .AFIFO_AWIDTH     ( AFIFO_AWIDTH       ),
    .SFIFO_WIDTH      ( SFIFO_WIDTH        ),
    .SFIFO_DEPTH      ( SFIFO_DEPTH        )
) u_wdec (
    .clk_axi       ( axi_clk           ),
    .clk           ( clk               ),
    .rstn          ( rst_n             ),
    .afifo_wr      ( wt_w              ),
    .afifo_full    ( wt_full           ),
    .afifo_afull   ( wt_afull          ),
    .data_in       ( wt_in             ),
    .read          ( fifo_req          ),
    .weight        ( fifo_wt_in        ),
    .wfifo_cnt     ( fifo_count        )
);

endmodule