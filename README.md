# -SRAM-interface
从npu IP 中引出SRAM接口并根据寄存器的配置对数据进行处理，并可以实现对数据读写功能。（下面是原NPU IP的顶层和SRAM接口相关的几个模块）
sramif 模块的npu data sram interface 部分接口

module sramif #(parameter integer NUM_CPUS = 1,parameter integer AXI_SRAM_ID = 14)  // 将这个AXI_SRAM_ID改为和顶层一样AXI_SRAM_ID = 12
(
  // ACE slave interface
  (* mark_debug = "true" *) output wire                    ace_awready_o,
  (* mark_debug = "true" *) input  wire                    ace_awvalid_i,
  input  wire [(AXI_SRAM_ID-1):0]   ace_awid_i,
 (* mark_debug = "true" *) input  wire [31:0]             ace_awaddr_i,
  (* mark_debug = "true" *) input  wire [7:0]              ace_awlen_i,
  (* mark_debug = "true" *) input  wire [2:0]              ace_awsize_i,
  (* mark_debug = "true" *) input  wire [1:0]              ace_awburst_i,
  //input  wire [1:0]              ace_awbar_i,
  //input  wire [1:0]              ace_awdomain_i,
  input  wire                    ace_awlock_i,
  input  wire [3:0]              ace_awcache_i,
  input  wire [2:0]              ace_awprot_i,
  //input  wire [2:0]              ace_awsnoop_i,
  //input  wire                    ace_awunique_i,
  (* mark_debug = "true" *) output wire                    ace_wready_o,
  (* mark_debug = "true" *) input  wire                    ace_wvalid_i,
  //input  wire [5:0]              ace_wid_i,
  (* mark_debug = "true" *) input  wire [127:0]            ace_wdata_i,
  (* mark_debug = "true" *) input  wire [15:0]             ace_wstrb_i,
  (* mark_debug = "true" *) input  wire                    ace_wlast_i,
  input  wire                    ace_bready_i,
  output wire                    ace_bvalid_o,
  output wire [(AXI_SRAM_ID-1):0]              ace_bid_o,
  output wire [1:0]              ace_bresp_o,
  output wire                    ace_arready_o,
  input  wire                    ace_arvalid_i,
  input  wire [(AXI_SRAM_ID-1):0]              ace_arid_i,
  input  wire [31:0]             ace_araddr_i,
  input  wire [7:0]              ace_arlen_i,
  input  wire [2:0]              ace_arsize_i,
  input  wire [1:0]              ace_arburst_i,
  //input  wire [1:0]              ace_arbar_i,
  //input  wire [1:0]              ace_ardomain_i,
  input  wire                    ace_arlock_i,
  input  wire [3:0]              ace_arcache_i,
  input  wire [2:0]              ace_arprot_i,
  //input  wire [3:0]              ace_arsnoop_i,
  input  wire                    ace_rready_i,
  output wire                    ace_rvalid_o,
  output wire [(AXI_SRAM_ID-1):0]              ace_rid_o,
  output wire [127:0]            ace_rdata_o,
  output wire [1:0]              ace_rresp_o,
  output wire                    ace_rlast_o,

  input  wire                   clk,
  input  wire                   reset_n,

  // npu axi register
  input logic [5:0]                 fifo_count     ,

  // npu register interface
  output logic [31:0]               sys_addr       , // System Interface
  output logic                      sys_wr         , // System Interface
  output logic [15:0]               sys_wr_val     , // System Interface
  output logic                      sys_rd         , // System Interface
  input                             sys_ack        , // System Interface
  input        [15:0]               sys_rd_val     , // System Interface

  // npu data sram interface 
  output logic [1:0][15:0]               bankA_dma_cs         ,
  output logic [1:0][15:0]               bankA_dma_we         ,
  output logic [1:0][15:0][10:0]         bankA_dma_addr       , 
  output logic [1:0][15:0][127:0]        bankA_dma_din        , 
  output logic [1:0][15:0][15:0]         bankA_dma_byte_en    ,
  input        [1:0][15:0][127:0]        bankA_dma_dout       , 
  output logic [1:0][15:0]               bankB_dma_cs         ,
  output logic [1:0][15:0]               bankB_dma_we         ,
  output logic [1:0][15:0][10:0]         bankB_dma_addr       , 
  output logic [1:0][15:0][127:0]        bankB_dma_din        , 
  output logic [1:0][15:0][15:0]         bankB_dma_byte_en    ,
  input        [1:0][15:0][127:0]        bankB_dma_dout       ,

  // npu lut sram  
  output logic [15:0]                     dma_lut_cs          ,
  output logic [15:0]                     dma_lut_we          ,
  output logic [15:0][11:0]               dma_lut_addr        ,
  output logic [15:0][15:0]               dma_lut_din         ,
  output logic [15:0][1:0]                dma_lut_byte_en     ,
  input        [15:0][15:0]               dma_lut_dout        ,

  // Command manager interface
	output logic                            cmd_cs         ,
  output logic                            cmd_we         ,
  output logic [10-1:0]                   cmd_addr       ,
  input  logic [32-1:0]                   cmd_out        ,
  output logic [32-1:0]                   cmd            ,
  
  // new addr control signal
  output logic select_bankAB_rd                          ,
  output logic select_bankAB_wr                                                                
/*
  input  wire                             bist_mode       ,
  // clk / rst_n          
  input  wire                             i_apb_clk       ,

  // apb port         
  input  wire                             i_psel          ,
  input  wire [11:0]                      i_paddr         ,
  input  wire                             i_penable       ,
  input  wire                             i_pwrite        ,
  input  wire [31:0]                      i_pwdata        ,
  output wire [31:0]                      o_prdata        ,
  output wire                             npum_ctrl       , //default:0
  output wire [15:0]                      npum_ramclk
   */
   
);

或者在顶层npu_axi_top.sv中bankA/B对应的信号进行操作，引出或者修改添加interface（相应逻辑代码如下）


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

































