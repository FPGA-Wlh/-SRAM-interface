module npu_buffer #(
    parameter DWIDTH    = 'd128  ,
    parameter BYTE_EN   = 'd16   ,
    parameter DATA_ADDR = 'd11
)(
    input                   clk                 ,
    input                   rstn                ,
    input                   en                  ,
    // input                   conv_busy           ,
//    input                   sram_mode           ,  //
    input                   sel_cpu_npu         ,
    // Bank interface: From buffer manager
    input           [15:0]                  A_bm_cs       ,
    input           [15:0]                  A_bm_we       ,
    input           [15:0][DATA_ADDR-1:0]   A_bm_addr     , //different from doc
    input           [15:0][DWIDTH-1:0]      A_bm_din      , //dif from doc
    input           [15:0][BYTE_EN-1:0]     A_bm_byte_en  ,
    output  logic   [15:0][DWIDTH-1:0]      A_bm_dout     , //dif from doc
    input           [15:0]                  B_bm_cs       ,
    input           [15:0]                  B_bm_we       ,
    input           [15:0][DATA_ADDR-1:0]   B_bm_addr     , //different from doc
    input           [15:0][DWIDTH-1:0]      B_bm_din      , //dif from doc
    input           [15:0][BYTE_EN-1:0]     B_bm_byte_en  ,
    output  logic   [15:0][DWIDTH-1:0]      B_bm_dout     , //dif from doc

    // Bank interface: From DMA
    input           [15:0]                  A_dma_cs      ,
    input           [15:0]                  A_dma_we      ,
    input           [15:0][DATA_ADDR-1:0]   A_dma_addr    , //different from doc
    input           [15:0][DWIDTH-1:0]      A_dma_din     , //dif from doc
    input           [15:0][BYTE_EN-1:0]     A_dma_byte_en ,
    output  logic   [15:0][DWIDTH-1:0]      A_dma_dout    , //dif from doc
    input           [15:0]                  B_dma_cs      ,
    input           [15:0]                  B_dma_we      ,
    input           [15:0][DATA_ADDR-1:0]   B_dma_addr    , //different from doc
    input           [15:0][DWIDTH-1:0]      B_dma_din     , //dif from doc
    input           [15:0][BYTE_EN-1:0]     B_dma_byte_en ,
    output  logic   [15:0][DWIDTH-1:0]      B_dma_dout      //dif from doc
);

// ---------------------------------------------
// Arbitration:
// When buffer manager is actively using sram bank,
// block DMA access
logic [15:0] A_cs ;  
logic [15:0] A_we ;  
logic [15:0][DATA_ADDR-1:0] A_addr ;
logic [15:0][BYTE_EN-1:0] A_byte_en ;
logic [15:0][DWIDTH-1:0] A_din ;
logic [15:0][DWIDTH-1:0] A_dout ;

logic [15:0] B_cs ;  
logic [15:0] B_we ;  
logic [15:0][DATA_ADDR-1:0] B_addr ;
logic [15:0][BYTE_EN-1:0] B_byte_en ;
logic [15:0][DWIDTH-1:0] B_din ;
logic [15:0][DWIDTH-1:0] B_dout ;
// assign A_cs   = (en & conv_busy) ? A_bm_cs : A_dma_cs;  
// assign B_cs   = (en & conv_busy) ? B_bm_cs : B_dma_cs;  
// assign A_we   = (en & conv_busy) ? A_bm_we : A_dma_we;  
// assign B_we   = (en & conv_busy) ? B_bm_we : B_dma_we;  
// assign A_addr = (en & conv_busy) ? A_bm_addr : A_dma_addr;  
// assign B_addr = (en & conv_busy) ? B_bm_addr : B_dma_addr;  
// assign A_din  = (en & conv_busy) ? A_bm_din : A_dma_din;  
// assign B_din  = (en & conv_busy) ? B_bm_din : B_dma_din;  
// assign A_byte_en  = (en & conv_busy) ? A_bm_byte_en : A_dma_byte_en;  
// assign B_byte_en  = (en & conv_busy) ? B_bm_byte_en : B_dma_byte_en;  
assign A_cs       = (en & sel_cpu_npu) ? A_bm_cs : A_dma_cs;  
assign B_cs       = (en & sel_cpu_npu) ? B_bm_cs : B_dma_cs;  
assign A_we       = (en & sel_cpu_npu) ? A_bm_we : A_dma_we;  
assign B_we       = (en & sel_cpu_npu) ? B_bm_we : B_dma_we;  
assign A_addr     = (en & sel_cpu_npu) ? A_bm_addr : A_dma_addr;  
assign B_addr     = (en & sel_cpu_npu) ? B_bm_addr : B_dma_addr;  
assign A_din      = (en & sel_cpu_npu) ? A_bm_din : A_dma_din;  
assign B_din      = (en & sel_cpu_npu) ? B_bm_din : B_dma_din;  
assign A_byte_en  = (en & sel_cpu_npu) ? A_bm_byte_en : A_dma_byte_en;  
assign B_byte_en  = (en & sel_cpu_npu) ? B_bm_byte_en : B_dma_byte_en;  
assign A_bm_dout  = A_dout;
assign B_bm_dout  = B_dout;
assign A_dma_dout = A_dout;
assign B_dma_dout = B_dout;
//assign A_dout  = (en & conv_busy) ? A_bm_dout : A_dma_dout;  
//assign B_dout  = (en & conv_busy) ? B_bm_dout : B_dma_dout;  


srambank u_sram_bankA (
    .clk       ( clk        ),
    .rstn      ( rstn       ),
    .cs        ( A_cs       ),
    .byte_en   ( A_byte_en  ),
    .we        ( A_we       ), 
    .addr      ( A_addr     ), 
    .din       ( A_din      ),
    .dout      ( A_dout     )
);

srambank u_sram_bankB (
    .clk       ( clk        ),
    .rstn      ( rstn       ),
    .cs        ( B_cs       ),
    .byte_en   ( B_byte_en  ),
    .we        ( B_we       ), 
    .addr      ( B_addr     ), 
    .din       ( B_din      ),
    .dout      ( B_dout     )
);

endmodule
