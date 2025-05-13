module npu_buffer_manager(
    input   logic                       clk_i                   ,
    input   logic                       rst_n                   ,
    //trigger signal    
    input   logic                       conv_start_i            ,
    output  logic                       conv_finish_o           ,//what does it mean and what is the difference between conv_end and fm_out_last ?
    //bank A ram interface  
    output  logic   [15:0]              bankA_cs_o              ,
    output  logic   [15:0]              bankA_we_o              ,
    output  logic   [15:0][10:0]        bankA_addr_o            , //different from doc
    output  logic   [15:0][127:0]       bankA_data_in_o         , //dif from doc
    output  logic   [15:0][15:0]        bankA_byte_enable_o     ,
    input   logic   [15:0][127:0]       bankA_data_out_i        , //dif from doc
    //bank B ram interface  
    output  logic   [15:0]              bankB_cs_o              ,
    output  logic   [15:0]              bankB_we_o              ,
    output  logic   [15:0][10:0]        bankB_addr_o            , //different from doc
    output  logic   [15:0][127:0]       bankB_data_in_o         , //dif from doc
    output  logic   [15:0][15:0]        bankB_byte_enable_o     ,
    input   logic   [15:0][127:0]       bankB_data_out_i        , //dif from doc
    //configuration registers   
    input   logic   [7:0]               reg_CONV_MODE_mode      ,
    input   logic                       reg_CONV_MODE_upsample  ,
    input   logic   [10:0]              reg_FM_ROW_row          , 
    input   logic   [10:0]              reg_FM_COL_col          , 
    input   logic   [11:0]              reg_FM_ICH_ich          , 
    input   logic   [11:0]              reg_FM_OCH_ST_och_st    ,
    input   logic   [11:0]              reg_FM_OCH_ED_och_ed    ,
    input   logic                       reg_CONV_MODE_AB_order  ,
    input   logic   [10:0]              reg_MEM_IN1_offset_x    ,
    input   logic   [3:0]               reg_MEM_IN1_offset_y    ,
    input   logic   [10:0]              reg_MEM_IN2_offset_x    ,
    input   logic   [3:0]               reg_MEM_IN2_offset_y    ,
    input   logic   [10:0]              reg_MEM_OUT_offset_x    ,
    input   logic   [3:0]               reg_MEM_OUT_offset_y    ,
    input   logic   [7:0]               reg_CROP_row_st         ,
    input   logic   [7:0]               reg_CROP_col_st         ,
    input   logic   [10:0]              reg_CROP_ROW_row_out    ,    
    input   logic   [10:0]              reg_CROP_COL_col_out    ,    
    input   logic   [7:0]               reg_PAD1_t              ,
    input   logic   [7:0]               reg_PAD1_b              ,
    input   logic   [7:0]               reg_PAD2_l              ,
    input   logic   [7:0]               reg_PAD2_r              ,
    input   logic                       reg_CONV_MODE_ch_st     ,
    input   logic                       reg_CONV_MODE_full_ch   ,
    input   logic                       en_i                    ,
    //from row_col_num_manager  
    input   logic   [10:0]              nl_col_num_i            ,
    input   logic   [10:0]              nl_row_num_i            ,
    input   logic   [10:0]              rbm_col_num_pe_i        ,
    //data path read port   
    output  logic   [7:0][9:0][15:0]    fm_out_o                ,
    output  logic                       fm_out_irdy_o           ,
    input   logic                       fm_out_trdy_i           ,
    output  logic                       fm_out_last_o           ,
    output  logic   [9:0]               fm_out_row_valid_o      ,
    output  logic   [7:0]              fm_out_ch_valid_o       ,
    //data path write port  
    input   logic   [3:0][7:0][15:0]    fm_in_i                 ,
    input   logic   [7:0]               fm_in_row_valid_i       ,
    input   logic                       fm_in_irdy_i            ,
    output  logic                       fm_in_trdy_o            ,//how to control this signal set to 1
    input   logic                       fm_in_last_i            ,//what does it mean : end of row frame
    input   logic   [3:0]               fm_in_ch_valid_i        ,
    input   logic                       datapath_finish_i       ,
    input   logic                       row_frame_p
);

logic   [15:0]          read_cs             ;
logic   [15:0][10:0]    read_addr           ;
logic   [15:0][127:0]   read_data_out       ;
logic   [15:0]          write_cs            ;
logic   [15:0]          write_enable        ;
logic   [15:0][10:0]    write_addr          ;
logic   [15:0][127:0]   write_data_in       ;
logic   [15:0][15:0]    write_byte_enable   ;
logic   [7:0]           rbm_frame_num       ;
//chip select
//value "0": bank A for read and bank B for write
//value "1": bank B for read and bank A for write
always_comb begin
    if(reg_CONV_MODE_AB_order == 1'b0) begin
        for(int i=0;i<16;i++) begin
            //bankA
            bankA_cs_o[i] = read_cs[i];
            bankA_addr_o[i] = read_addr[i];
            read_data_out[i] = bankA_data_out_i[i];
            bankA_we_o[i] = 1'b0;
            bankA_data_in_o[i] = 512'b0;
            bankA_byte_enable_o[i] = 'b0;
            //bankB
            bankB_cs_o[i] = write_cs[i];
            bankB_addr_o[i] = write_addr[i];
            bankB_data_in_o[i] = write_data_in[i];
            bankB_we_o[i] = write_enable[i];
            bankB_byte_enable_o[i] = write_byte_enable[i];
        end
    end else begin
        for(int i=0;i<16;i++) begin
            //bankB
            bankA_cs_o[i] = write_cs[i];
            bankA_addr_o[i] = write_addr[i];//what about unwanted bankA_data_out
            bankA_data_in_o[i] = write_data_in[i];
            bankA_we_o[i] = write_enable[i];
            bankA_byte_enable_o[i] = write_byte_enable[i];
            //bankA
            bankB_cs_o[i] = read_cs[i];
            bankB_addr_o[i] = read_addr[i];
            read_data_out[i] = bankB_data_out_i[i];
            bankB_we_o[i] = 1'b0;
            bankB_data_in_o[i] = 512'b0;
            bankB_byte_enable_o[i] = 'b0;
        end
    end
end
npu_read_buffer_manager u_rbm(
    .clk_i              (clk_i                  ),
    .rst_n              (rst_n                  ),
    //command signal
    .conv_start_i       (conv_start_i           ),
    //ram_interface
    .read_cs_o          (read_cs                ),
    .read_addr_o        (read_addr              ),
    .read_data_out_i    (read_data_out          ),
    //configuration
    .reg_CONV_MODE_upsample (reg_CONV_MODE_upsample ),
    .reg_MEM_IN1_offset_x   (reg_MEM_IN1_offset_x   ),
    .reg_MEM_IN1_offset_y   (reg_MEM_IN1_offset_y   ),
    .reg_MEM_IN2_offset_x   (reg_MEM_IN2_offset_x   ),
    .reg_MEM_IN2_offset_y   (reg_MEM_IN2_offset_y   ),
    .reg_CROP_row_st        (reg_CROP_row_st        ),
    .reg_CROP_col_st        (reg_CROP_col_st        ),
    .reg_CROP_ROW_row_out   (reg_CROP_ROW_row_out   ),
    .reg_CROP_COL_col_out   (reg_CROP_COL_col_out   ),
    .reg_PAD1_t             (reg_PAD1_t             ),
    .reg_PAD1_b             (reg_PAD1_b             ),
    .reg_PAD2_l             (reg_PAD2_l             ),
    .reg_PAD2_r             (reg_PAD2_r             ),
    .reg_CONV_MODE_mode     (reg_CONV_MODE_mode     ),
    .reg_FM_ROW_row         (reg_FM_ROW_row         ),
    .reg_FM_COL_col         (reg_FM_COL_col         ),
    .reg_FM_ICH_ich         (reg_FM_ICH_ich         ),
    .reg_FM_OCH_ST_och_st    (reg_FM_OCH_ST_och_st  ),
    .reg_FM_OCH_ED_och_ed    (reg_FM_OCH_ED_och_ed  ),
    //from top
    .en_i               (en_i               ),
    //from wbm
    .conv_finish_i      (conv_finish_o      ),
    //read port 
    .fm_out_o           (fm_out_o           ),
    .fm_out_irdy_o      (fm_out_irdy_o      ),
    .fm_out_trdy_i      (fm_out_trdy_i      ),
    // .fm_out_trdy_i      (1      ),
    .fm_out_last_o      (fm_out_last_o      ),
    .fm_out_row_valid_o (fm_out_row_valid_o ),
    .fm_out_ch_valid_o  (fm_out_ch_valid_o  ),
    //from row_col_num_manager
    .rbm_col_num_pe_i   (rbm_col_num_pe_i   ),
    //to wbm
    .rbm_frame_num_o    (rbm_frame_num      )
);
npu_write_buffer_manager u_wbm (
    .clk_i                          (clk_i                          ),
    .rst_n                          (rst_n                          ),
    .conv_finish_o                  (conv_finish_o                  ),
    .write_cs_o                     (write_cs                       ),
    .write_addr_o                   (write_addr                     ),
    .write_data_in_o                (write_data_in                  ),
    .write_enable_o                 (write_enable                   ),
    .write_byte_enable_o            (write_byte_enable              ),
    .reg_MEM_OUT_offset_x           (reg_MEM_OUT_offset_x           ),
    .reg_MEM_OUT_offset_y           (reg_MEM_OUT_offset_y           ),
    .reg_CONV_MODE_mode             (reg_CONV_MODE_mode             ),
    .reg_FM_OCH_ST_och_st           (reg_FM_OCH_ST_och_st           ),
    .reg_FM_OCH_ED_och_ed           (reg_FM_OCH_ED_och_ed           ),
    .reg_CONV_MODE_ch_st            (reg_CONV_MODE_ch_st            ),
    .reg_CONV_MODE_full_ch          (reg_CONV_MODE_full_ch          ),
    .en_i                           (en_i                           ),
    .nl_col_num_i                   (nl_col_num_i                   ),
    .nl_row_num_i                   (nl_row_num_i                   ),
    .rbm_frame_num_i                (rbm_frame_num                  ),
    .fm_in_i                        (fm_in_i                        ),
    .fm_in_irdy_i                   (fm_in_irdy_i                   ),
    .fm_in_trdy_o                   (fm_in_trdy_o                   ),
    .fm_in_last_i                   (fm_in_last_i                   ),
    .fm_in_row_valid_i              (fm_in_row_valid_i              ),
    .fm_in_ch_valid_i               (fm_in_ch_valid_i               ),
    .datapath_finish_i              (datapath_finish_i              ),
    .row_frame_p                    (row_frame_p                    )
);

endmodule