module sramif #(parameter integer NUM_CPUS = 1,parameter integer AXI_SRAM_ID = 12)
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
  output logic [32-1:0]                   cmd            
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
  output wire [15:0]                      npum_ramclk */
);

  localparam ADDR_WIDTH = 32;
  //----------------------------------------------------------------------------
  // Signal declarations
  //----------------------------------------------------------------------------
  //reg                    ace_rready_i_tmp;
  //always@(posedge clk)begin
  //    ace_rready_i_tmp <= ace_rready_i;
  //end
  logic [7:0]              len_addr_count;
  logic [7:0]              len_addr_count_d1;

  // Read/write arbitration
  reg                     write_sel;
  wire                    nxt_write_sel;
  wire                    write_sel_we;

  // Unpacked address/control
  wire [(ADDR_WIDTH-1):0] unpk_wr_addr;
  wire                    unpk_wr_last;
  wire                    unpk_wr_valid;
  wire                    unpk_wr_ready;
  wire [(ADDR_WIDTH-1):0] unpk_rd_addr;
  wire                    unpk_rd_last;
  wire                    unpk_rd_valid;
  wire                    unpk_rd_ready;
  reg                     unpk_rd_valid_d1;
  reg                     unpk_rd_last_d1;
  reg                     unpk_rd_last_d2;

  // ACE signals
  wire                    ace_awready;
  wire                    ace_arready;
  reg  [(AXI_SRAM_ID-1):0]              ace_arid_reg;
  reg  [(AXI_SRAM_ID-1):0]              ace_arid_d2;
  wire                    ace_arid_reg_we;
  reg  [(AXI_SRAM_ID-1):0]              ace_rid;
  wire                    ace_rid_we;
  reg  [(AXI_SRAM_ID-1):0]              ace_bid;
  wire                    ace_bid_we;
  reg                     ace_wready;
  wire                    nxt_ace_wready;
  reg                     ace_bvalid;
  wire                    nxt_ace_bvalid;
  wire [1:0]              ace_bresp;
  reg  [127:0]            ace_rdata;
  reg                     ace_rvalid;
  wire                    nxt_ace_rvalid;
  reg                     ace_rlast;
  reg                     ace_rlast_temp;
  wire [1:0]              ace_rresp;

  // Validation read/write
  wire                    val_read;
  reg                     val_read_d1; // read data delay one cycle
  reg                     val_read_d2; // read data delay two cycle
  wire [127:0]            val_rd_data; // Read data
  wire [127:0]            val_rd_data_big; // Read data
  wire                    val_write;
  wire                    val_rd_ongoing;
  reg                     val_rd_ongoing_reg;

  logic unpk_wr_valid_d1;
  logic unpk_wr_valid_d2;
  logic preproc_valid;
  logic [1:0]   pre_type;
  logic bvalid_delay;
  logic ace_wvalid_d1;
  logic wstart;
  
  logic empty;
  logic empty_b1;
  logic almost_empty;
/*
  //apb signals
  wire                   o_sw_SLEEP_P0;
  wire                   o_sw_SLEEP_P1;
  wire                   o_sw_SLEEP_P2;
  wire                   o_sw_SLEEP_P3;
  wire                   o_sw_SLEEP_P4;
  wire                   o_sw_SLEEP_P5;
  wire                   o_sw_SLEEP_P6;
  wire                   o_sw_SLEEP_P7;
  wire                   o_sw_SLEEP_P8;
  wire                   o_sw_SLEEP_P9;
  wire                   o_sw_SLEEP_P10;
  wire                   o_sw_SLEEP_P11;
  wire                   o_sw_SLEEP_P12;
  wire                   o_sw_SLEEP_P13;
  wire                   o_sw_SLEEP_P14;
  wire                   o_sw_SLEEP_P15;


apb_reg_memctl u_apb_reg_memctl
(
  .i_clk         (i_apb_clk     ),
  .i_rst_n       (reset_n       ),
  .i_psel        (i_psel        ),
  .i_paddr       (i_paddr       ),
  .i_penable     (i_penable     ),
  .i_pwrite      (i_pwrite      ),
  .i_pwdata      (i_pwdata      ),
  .o_prdata      (o_prdata      ),
  .o_sw_SLEEP_P0 (o_sw_SLEEP_P0 ),
  .o_sw_SLEEP_P1 (o_sw_SLEEP_P1 ),
  .o_sw_SLEEP_P2 (o_sw_SLEEP_P2 ),
  .o_sw_SLEEP_P3 (o_sw_SLEEP_P3 ),
  .o_sw_SLEEP_P4 (o_sw_SLEEP_P4 ),
  .o_sw_SLEEP_P5 (o_sw_SLEEP_P5 ),
  .o_sw_SLEEP_P6 (o_sw_SLEEP_P6 ),
  .o_sw_SLEEP_P7 (o_sw_SLEEP_P7 ),
  .o_sw_SLEEP_P8 (o_sw_SLEEP_P8 ),
  .o_sw_SLEEP_P9 (o_sw_SLEEP_P9 ),
  .o_sw_SLEEP_P10(o_sw_SLEEP_P10),
  .o_sw_SLEEP_P11(o_sw_SLEEP_P11),
  .o_sw_SLEEP_P12(o_sw_SLEEP_P12),
  .o_sw_SLEEP_P13(o_sw_SLEEP_P13),
  .o_sw_SLEEP_P14(o_sw_SLEEP_P14),
  .o_sw_SLEEP_P15(o_sw_SLEEP_P15),
  .o_sw_NPUM_CTRL(npum_ctrl     ) 
);

  //----------------------------------------------------------------------------
  //Power Down Mode
  //----------------------------------------------------------------------------
ca53_cell_clkgate clkgate_ram_clk0   (.clk_i(clk),.clk_enable_i(!o_sw_SLEEP_P0 ), .clk_senable_i(bist_mode),.clk_gated_o(npum_ramclk[0 ]));
ca53_cell_clkgate clkgate_ram_clk1   (.clk_i(clk),.clk_enable_i(!o_sw_SLEEP_P1 ), .clk_senable_i(bist_mode),.clk_gated_o(npum_ramclk[1 ]));
ca53_cell_clkgate clkgate_ram_clk2   (.clk_i(clk),.clk_enable_i(!o_sw_SLEEP_P2 ), .clk_senable_i(bist_mode),.clk_gated_o(npum_ramclk[2 ]));
ca53_cell_clkgate clkgate_ram_clk3   (.clk_i(clk),.clk_enable_i(!o_sw_SLEEP_P3 ), .clk_senable_i(bist_mode),.clk_gated_o(npum_ramclk[3 ]));
ca53_cell_clkgate clkgate_ram_clk4   (.clk_i(clk),.clk_enable_i(!o_sw_SLEEP_P4 ), .clk_senable_i(bist_mode),.clk_gated_o(npum_ramclk[4 ]));
ca53_cell_clkgate clkgate_ram_clk5   (.clk_i(clk),.clk_enable_i(!o_sw_SLEEP_P5 ), .clk_senable_i(bist_mode),.clk_gated_o(npum_ramclk[5 ]));
ca53_cell_clkgate clkgate_ram_clk6   (.clk_i(clk),.clk_enable_i(!o_sw_SLEEP_P6 ), .clk_senable_i(bist_mode),.clk_gated_o(npum_ramclk[6 ]));
ca53_cell_clkgate clkgate_ram_clk7   (.clk_i(clk),.clk_enable_i(!o_sw_SLEEP_P7 ), .clk_senable_i(bist_mode),.clk_gated_o(npum_ramclk[7 ]));
ca53_cell_clkgate clkgate_ram_clk8   (.clk_i(clk),.clk_enable_i(!o_sw_SLEEP_P8 ), .clk_senable_i(bist_mode),.clk_gated_o(npum_ramclk[8 ]));
ca53_cell_clkgate clkgate_ram_clk9   (.clk_i(clk),.clk_enable_i(!o_sw_SLEEP_P9 ), .clk_senable_i(bist_mode),.clk_gated_o(npum_ramclk[9 ]));
ca53_cell_clkgate clkgate_ram_clk10  (.clk_i(clk),.clk_enable_i(!o_sw_SLEEP_P10), .clk_senable_i(bist_mode),.clk_gated_o(npum_ramclk[10]));
ca53_cell_clkgate clkgate_ram_clk11  (.clk_i(clk),.clk_enable_i(!o_sw_SLEEP_P11), .clk_senable_i(bist_mode),.clk_gated_o(npum_ramclk[11]));
ca53_cell_clkgate clkgate_ram_clk12  (.clk_i(clk),.clk_enable_i(!o_sw_SLEEP_P12), .clk_senable_i(bist_mode),.clk_gated_o(npum_ramclk[12]));
ca53_cell_clkgate clkgate_ram_clk13  (.clk_i(clk),.clk_enable_i(!o_sw_SLEEP_P13), .clk_senable_i(bist_mode),.clk_gated_o(npum_ramclk[13]));
ca53_cell_clkgate clkgate_ram_clk14  (.clk_i(clk),.clk_enable_i(!o_sw_SLEEP_P14), .clk_senable_i(bist_mode),.clk_gated_o(npum_ramclk[14]));
ca53_cell_clkgate clkgate_ram_clk15  (.clk_i(clk),.clk_enable_i(!o_sw_SLEEP_P15), .clk_senable_i(bist_mode),.clk_gated_o(npum_ramclk[15]));
*/
  //----------------------------------------------------------------------------
  // ACE address unpacking
  //
  //   An ACE read/write request can specify a burst while only providing the
  //   address for the first transfer in the burst.  To access the validation
  //   memory resources these 'packed' addresses are unpacked into a series of
  //   requests, each providing the full address.
  //----------------------------------------------------------------------------

  // Write channel
  execution_tb_ace_intf_addr_unpack #(.ADDR_WIDTH(ADDR_WIDTH))
    u_execution_tb_ace_intf_addr_unpack_wr
      (// Clocks and resets
       .clk             (clk),
       .reset_n         (reset_n),

       // ACE write address channel
       .ace_axaddr_i    (ace_awaddr_i),
       .ace_axburst_i   (ace_awburst_i),
       .ace_axsize_i    (ace_awsize_i),
       .ace_axlen_i     (ace_awlen_i),
       .ace_axprot_i    (ace_awprot_i),
       .ace_axvalid_i   (ace_awvalid_i),
       .ace_axready_o   (ace_awready),

       .len_addr_count  (len_addr_count),

       // Unpacked write address/control
       .unpk_addr_o     (unpk_wr_addr),
       .unpk_last_o     (unpk_wr_last),
       .unpk_valid_o    (unpk_wr_valid),
       .unpk_ready_i    (unpk_wr_ready)
      );
  // The ACE write address channel is stalled until the ACE write channel
  // provides data on a completed W channel handshake.
  //
  // However, for the last beat of the burst the stall is extended until the end
  // of the ACE write response channel handshake.  This is required so that no
  // other requests on the AW channel are started until the current request has
  // completely cleared; the address unpacker can only handle a single
  // outstanding write.
  assign unpk_wr_ready = (ace_wvalid_i & ace_wready & ~unpk_wr_last) |
                         (ace_bvalid & ace_bready_i);

  // Read channel
  execution_tb_ace_intf_addr_unpack
    u_execution_tb_ace_intf_addr_unpack_rd
      (// Clocks and resets
       .clk             (clk),
       .reset_n         (reset_n),

       // ACE read address channel
       .ace_axaddr_i    (ace_araddr_i),
       .ace_axburst_i   (ace_arburst_i),
       .ace_axsize_i    (ace_arsize_i),
       .ace_axlen_i     (ace_arlen_i),
       .ace_axprot_i    (ace_arprot_i),
       .ace_axvalid_i   (ace_arvalid_i),
       .ace_axready_o   (ace_arready),

       .len_addr_count  (),

       // Unpacked write address channel
       .unpk_addr_o     (unpk_rd_addr),
       .unpk_last_o     (unpk_rd_last),
       .unpk_valid_o    (unpk_rd_valid),
       .unpk_ready_i    (unpk_rd_ready)
      );

  always @ (posedge clk or negedge reset_n)
    if(!reset_n)
      len_addr_count_d1 <= {8{1'b0}};
    else
      len_addr_count_d1 <= len_addr_count;


  // The ACE read address channel stalls until the read is issued to the
  // validation subsystem.
  assign unpk_rd_ready = val_read;


  //----------------------------------------------------------------------------
  // ACE transaction IDs
  //----------------------------------------------------------------------------

  // ARID register:
  //   Capture ARID on a completed ACE AR handskake to form the correct ID for
  //   the read response
  always @ (posedge clk or negedge reset_n)
    if (!reset_n)
      ace_arid_reg <= {(AXI_SRAM_ID){1'b0}};
    else if (ace_arid_reg_we)
      ace_arid_reg <= ace_arid_i;

  assign ace_arid_reg_we = ace_arready & ace_arvalid_i;
  
  // read data delay a cycle and rid need delay a cycle
  always @ (posedge clk or negedge reset_n)
    if (!reset_n)
      ace_arid_d2 <= {(AXI_SRAM_ID){1'b0}};
    else
      ace_arid_d2 <= ace_arid_reg;
//    else if (ace_arid_reg_we)
//      //ace_arid_d2 <= ace_arid_i;
//      ace_arid_d2 <= ace_arid_reg;

  // RID:
  //   RID will normally be from ace_arid_reg, but because we can accept the
  //   next AR request while waiting for the previous request's RREADY we have
  //   to cover this extra window.
  always @ (posedge clk or negedge reset_n)
    if (!reset_n)
      ace_rid <= {(AXI_SRAM_ID){1'b0}};
    else if (ace_rid_we)
      ace_rid <= ace_arid_d2;

  assign ace_rid_we = unpk_rd_valid_d1 & ~(ace_rlast & ace_rvalid & ~ace_rready_i);
  always @ (posedge clk or negedge reset_n)
    if (!reset_n)
      unpk_rd_valid_d1 <= 1'b0;
    else
      unpk_rd_valid_d1 <= unpk_rd_valid;


  // BID:
  //   Takes a copy of AWID when the write address handshake is complete.
  //   Bits[1:0] of the ID contains the CPU number of the CPU that made the
  //   request.
  always @ (posedge clk or negedge reset_n)
    if (!reset_n)
      ace_bid <= {(AXI_SRAM_ID){1'b0}};
    else if (ace_bid_we)
      ace_bid <= ace_awid_i;

  assign ace_bid_we = ace_awready & ace_awvalid_i;


  //----------------------------------------------------------------------------
  // Write channel handshake
  //
  //   Once a write address handshake has completed, writes for that transaction
  //   do not incur any stalls.  Therefore WREADY is brought high after a write
  //   address handshake and stays high until the handshake for the last data
  //   beat completes and the write response has handshaked.
  //
  //   We must wait for the write response handshake to complete so as not to
  //   handshake any new write transactions that the processor may have
  //   presented.
  //----------------------------------------------------------------------------

  always @ (posedge clk or negedge reset_n)
    if (!reset_n)
      ace_wready <= 1'b0;
    else
      ace_wready <= nxt_ace_wready;

  assign nxt_ace_wready = unpk_wr_valid & preproc_valid &                 // Ongoing write
                          ~(ace_wvalid_i & ace_wready & ace_wlast_i) &  // Not last beat
                          ~ace_bvalid;                                  // Not waiting for BREAD

  // unpk_valid delay one cycle for val_write_i
  always @ (posedge clk or negedge reset_n)
    if (!reset_n)
      unpk_wr_valid_d1 <= 1'b0;
    else
      unpk_wr_valid_d1 <= unpk_wr_valid;
  // unpk_valid delay 2 cycle for val_write_i
  always @ (posedge clk or negedge reset_n)
    if (!reset_n)
      unpk_wr_valid_d2 <= 1'b0;
    else
      unpk_wr_valid_d2 <= unpk_wr_valid_d1;

  //----------------------------------------------------------------------------
  // Write response channel handshake
  //
  //   The write response is driven after the final beat of write data has been
  //   written (i.e. its write handshake has completed.)  BVALID stays high
  //   until the processor completes the handshake.
  //----------------------------------------------------------------------------

  always @ (posedge clk or negedge reset_n)
    if (!reset_n)
      ace_bvalid <= 1'b0;
    else
      ace_bvalid <= nxt_ace_bvalid;

  //assign nxt_ace_bvalid = ~bvalid_delay & ((ace_wvalid_i & ace_wready & unpk_wr_last) | ace_bvalid) &
  assign nxt_ace_bvalid = ((ace_wvalid_i & ace_wready & unpk_wr_last) | ace_bvalid) &
                          ~(ace_bvalid & ace_bready_i);

  assign ace_bresp = 2'b00; // OKAY response


  //----------------------------------------------------------------------------
  // Read channel data register and handshake
  //
  //   Read data from the validation memory model is registered before being
  //   sent to the processor.
  //
  //   RVALID is set high at the same time and stays high until the processor
  //   completes the handshake.
  //----------------------------------------------------------------------------

//  always @ (posedge clk or negedge reset_n)
//    if (!reset_n)
//      ace_rdata <= {128{1'b0}};
//    else if (val_read_d2)
//      ace_rdata <= val_rd_data_big;

sramif_fifo u_sramif_fifo(
    .clk      (clk     ),
    .rst_n    (reset_n ),
    .flush    ( 1'b0   ),
    .write    (val_read_d2 ),
    .data_in  (val_rd_data_big ),
    .read     (~empty & ace_rready_i ),
    .data_out (ace_rdata ),
    .full     ( ),
    .almost_empty    (almost_empty ),
    .empty_b1 (empty_b1 ),
    .empty    (empty )
);

assign val_rd_data_big[31:0]    = {val_rd_data[7:0], val_rd_data[15:8], val_rd_data[23:16], val_rd_data[31:24]};
assign val_rd_data_big[63:32]   = {val_rd_data[39:32], val_rd_data[47:40], val_rd_data[55:48], val_rd_data[63:56]};
assign val_rd_data_big[95:64]   = {val_rd_data[71:64], val_rd_data[79:72], val_rd_data[87:80], val_rd_data[95:88]};
assign val_rd_data_big[127:96]   = {val_rd_data[103:96], val_rd_data[111:104], val_rd_data[119:112], val_rd_data[127:120]};

  // RVALID
  always @ (posedge clk or negedge reset_n)
    if (!reset_n)
      ace_rvalid <= 1'b0;
    else
      ace_rvalid <= nxt_ace_rvalid;

  assign nxt_ace_rvalid = val_rd_ongoing | (ace_rvalid & ~ace_rready_i);

  // Drive RLAST from the unpacked interface when the read is ongoing
  always @ (posedge clk or negedge reset_n)
    if (!reset_n)
      ace_rlast <= 1'b0;
    else if (ace_rvalid & ace_rready_i & ace_rlast)
      ace_rlast <= 1'b0;
    else if (val_read_d2)
      ace_rlast <= unpk_rd_last_d2;

  always @ (posedge clk or negedge reset_n)
    if (!reset_n)
      unpk_rd_last_d1 <= 1'b0;
    else
      unpk_rd_last_d1 <= unpk_rd_last;
  always @ (posedge clk or negedge reset_n)
    if (!reset_n)
      unpk_rd_last_d2 <= 1'b0;
    else
      unpk_rd_last_d2 <= unpk_rd_last_d1;

  // The validation memories never give an error response
  assign ace_rresp = 2'b00;  // OKAY response


  //----------------------------------------------------------------------------
  // Validation read/write valid
  //
  //   A read to the validation memory interface is valid when the address
  //   unpacker signals a valid read and we are not waiting on RREADY (which
  //   stalls the next read.)
  //
  //   Since write data is accepted as soon as it is provided by the processor,
  //   a write to the validation memory interface is valid when there's
  //   a completed ACE write channel handshake.
  //----------------------------------------------------------------------------

  assign val_read  = unpk_rd_valid & ~(ace_rvalid & ~ace_rready_i);
  assign val_write = ace_wvalid_i & ((ace_wready & pre_type != 2'h2) | 
    (unpk_wr_valid_d1 & pre_type == 2'h2 & (!unpk_wr_valid_d2 || wstart ||
    (len_addr_count != len_addr_count_d1 && len_addr_count_d1 != 8'b0))));

//  assign val_write = ace_wvalid_i & ((ace_wready & pre_type != 2'h2) | 
//    (unpk_wr_valid_d1 & pre_type == 2'h2 & (!unpk_wr_valid_d2 || 
//    (len_addr_count != len_addr_count_d1 && len_addr_count_d1 != 8'b0))));

  always @ (posedge clk or negedge reset_n)
    if (!reset_n)
      wstart <= 1'b0;
    else if(unpk_wr_valid_d1 && ~unpk_wr_valid_d2 && ~ace_wvalid_i)
      wstart <= 1'b1;
    else if(ace_wvalid_i)
      wstart <= 1'b0;
  
//  assign val_write = ace_wvalid_i & ((ace_wready & pre_type != 2'h2) | (unpk_wr_valid_d1 & ~unpk_wr_valid_d2 & pre_type == 2'h2));
// write data valid after unpk wr addr valid one cycle
//  assign val_write = ace_wvalid_i & ace_wready;

  always @ (posedge clk or negedge reset_n)
    if (!reset_n)
      val_read_d1 <= 1'b0;
    else
      val_read_d1 <= val_read;
  always @ (posedge clk or negedge reset_n)
    if (!reset_n)
      val_read_d2 <= 1'b0;
    else
      val_read_d2 <= val_read_d1;

  // Set a flag when a read is sent to the validation components and stays high
  // until the read data is presented to the ACE interface, accounting for any
  // stalls from the RVALID/RREADY handshake
  assign val_rd_ongoing = ~empty_b1 | (val_rd_ongoing_reg & ~(ace_rvalid & ace_rready_i));

  always @ (posedge clk or negedge reset_n)
    if (!reset_n)
      val_rd_ongoing_reg <= 1'b0;
    else
      val_rd_ongoing_reg <= val_rd_ongoing;


  //----------------------------------------------------------------------------
  // Output assignments
  //----------------------------------------------------------------------------

//  wire                    val_read_o,    // Read valid
  wire [(ADDR_WIDTH-1):0] val_rd_addr; // Read address
//  wire                    val_write_o,   // Write valid
  wire [(ADDR_WIDTH-1):0] val_wr_addr; // Write address
  wire [15:0]             val_wr_strb; // Write strobes
  wire [127:0]            val_wr_data;  // Write data

  // Validation memory interface
  //assign val_read      = val_read;
  assign val_rd_addr   = unpk_rd_addr;
  //assign val_write     = val_write;
  assign val_wr_addr   = unpk_wr_addr;
  // change little-big endian
  assign val_wr_data[31:0]   = {ace_wdata_i[7:0], ace_wdata_i[15:8], ace_wdata_i[23:16], ace_wdata_i[31:24]};
  assign val_wr_data[63:32]   = {ace_wdata_i[39:32], ace_wdata_i[47:40], ace_wdata_i[55:48], ace_wdata_i[63:56]};
  assign val_wr_data[95:64]   = {ace_wdata_i[71:64], ace_wdata_i[79:72], ace_wdata_i[87:80], ace_wdata_i[95:88]};
  assign val_wr_data[127:96]   = {ace_wdata_i[103:96], ace_wdata_i[111:104], ace_wdata_i[119:112], ace_wdata_i[127:120]};
  //assign val_wr_data   = ace_wdata_i;
  //assign val_wr_strb   = ace_wstrb_i;
  assign val_wr_strb   = {ace_wstrb_i[12], ace_wstrb_i[13],ace_wstrb_i[14],ace_wstrb_i[15],
                          ace_wstrb_i[8], ace_wstrb_i[9],ace_wstrb_i[10],ace_wstrb_i[11],
                          ace_wstrb_i[4], ace_wstrb_i[5],ace_wstrb_i[6],ace_wstrb_i[7],
                          ace_wstrb_i[0], ace_wstrb_i[1],ace_wstrb_i[2],ace_wstrb_i[3]};

  //reg                    ace_rvalid_o_tmp;
  //reg [5:0]              ace_rid_o_tmp;
  //reg [3:0]              ace_rresp_o_tmp;
  //reg                    ace_rlast_o_tmp;
  //always@(posedge clk)begin
  //    ace_rvalid_o_tmp <= ace_rid    ;
  //    ace_rid_o_tmp    <= ace_rresp  ;
  //    ace_rresp_o_tmp  <= ace_rlast  ;
  //    ace_rlast_o_tmp  <= ace_rvalid ;
  //end

  // ACE outputs
  assign ace_awready_o = ace_awready;
  assign ace_wready_o  = ace_wready;
  assign ace_bvalid_o  = ace_bvalid;
  assign ace_bid_o     = ace_bid;
  assign ace_bresp_o   = ace_bresp;
  assign ace_arready_o = ace_arready;
  assign ace_rvalid_o  = ace_rvalid;
  assign ace_rid_o     = ace_rid;
  assign ace_rdata_o   = ace_rdata;
  //assign ace_rdata_o   = val_rd_data;
  assign ace_rresp_o   = ace_rresp;
  assign ace_rlast_o   = ace_rlast;


  //----------------------------------------------------------------------------
  // System address decoder
  //
  //   The validation memory starts at address 0x000_0000_0000 and aliases
  //   through the whole memory map, except for the region 0x000_1300_0000 to
  //   0x000_13FF_FFFF which is reserved for the tube and trickbox registers.
  //
  //   This region contains:
  //
  //     0x000_1300_0000 : Tube
  //     0x000_1300_0008 : Trickbox - FIQ counter load
  //     0x000_1300_000C : Trickbox - FIQ clear
  //
  //   Other locations in the trickbox region are reserved.
  //----------------------------------------------------------------------------

  sramif_decoder
    u_sramif_decoder
      (
           .clk             (clk),
           .reset_n         (reset_n),

         // Read port
         .val_read_i          (val_read),
         .val_rd_addr_i       (val_rd_addr),
         .val_rd_data_o       (val_rd_data),

         // Write port
         .val_write_i         (val_write),
         .val_wr_addr_i       (val_wr_addr),
         .val_wr_strb_i       (val_wr_strb),
         .val_wr_data_i       (val_wr_data),

         // unpack address
         // a cycle ahead w_data_en
       .unpk_valid_i    (unpk_wr_valid),
         
         // axi fifo register interface
         .fifo_count          (fifo_count),

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
        .bankB_dma_dout      ( bankB_dma_dout      ),

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

endmodule
