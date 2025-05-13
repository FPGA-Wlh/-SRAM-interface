module npu_ram_arbiter (
    input   logic                       clk                     ,
    input   logic                       rst_n                   ,

    //from or to psum
    input   logic   [15:0]              cs_psum                 ,
    input   logic   [15:0][15:0]        byte_en_psum            ,
    input   logic   [15:0][10:0]        addr_psum_wr            ,
    input   logic   [15:0]              we_en_psum              ,
    input   logic   [15:0][127:0]       data_psum_w             ,  
    output  logic   [15:0][127:0]       data_psum_r             ,

    output  logic                       data_psum_trdy_o        ,

    //from or to  buffer maneger
    input   logic   [15:0]              bm_bankA_cs_i              ,
    input   logic   [15:0]              bm_bankA_we_i              ,
    input   logic   [15:0][10:0]        bm_bankA_addr_i            , 
    input   logic   [15:0][127:0]       bm_bankA_data_in_i         , 
    input   logic   [15:0][15:0]        bm_bankA_byte_enable_i     ,
    output  logic   [15:0][127:0]       bm_bankA_data_out_o        , 

    input   logic   [15:0]              bm_bankB_cs_i              ,
    input   logic   [15:0]              bm_bankB_we_i              ,
    input   logic   [15:0][10:0]        bm_bankB_addr_i            , 
    input   logic   [15:0][127:0]       bm_bankB_data_in_i         , 
    input   logic   [15:0][15:0]        bm_bankB_byte_enable_i     ,
    output  logic   [15:0][127:0]       bm_bankB_data_out_o        , 

    //from or to sram
    output  logic   [15:0]              sram_bankA_cs_o              ,
    output  logic   [15:0]              sram_bankA_we_o              ,
    output  logic   [15:0][10:0]        sram_bankA_addr_o            , 
    output  logic   [15:0][127:0]       sram_bankA_data_in_o         , 
    output  logic   [15:0][15:0]        sram_bankA_byte_enable_o     ,
    input   logic   [15:0][127:0]       sram_bankA_data_out_i        , 

    output  logic   [15:0]              sram_bankB_cs_o              ,
    output  logic   [15:0]              sram_bankB_we_o              ,
    output  logic   [15:0][10:0]        sram_bankB_addr_o            ,
    output  logic   [15:0][127:0]       sram_bankB_data_in_o         , 
    output  logic   [15:0][15:0]        sram_bankB_byte_enable_o     ,
    input   logic   [15:0][127:0]       sram_bankB_data_out_i        , 

    input   logic                       reg_CONV_MODE_AB_order                                 
); 
//reg_CONV_MODE_AB_order
//value "0": bank A for read and bank B for write
//value "1": bank B for read and bank A for write

logic   [15:0][127:0]       data_write          ;
logic   [15:0]              cs                  ;
logic   [15:0]              we_en               ;
logic   [15:0][10:0]        addr                ;
logic   [15:0][15:0]        byte_en             ;

logic   [15:0][127:0]       o_data_write          ;
logic   [15:0]              o_cs                  ;
logic   [15:0]              o_we_en               ;
logic   [15:0][10:0]        o_addr                ;
logic   [15:0][15:0]        o_byte_en             ;

logic   [15:0]              cs_bm               ;
logic   [15:0][10:0]        addr_bm_w           ;
logic   [15:0]              we_en_bm            ;
logic   [15:0][127:0]       data_bm_w           ;
logic   [15:0][15:0]        byte_en_bm          ;

logic  flag;
assign flag = ((cs_bm & cs_psum)==16'b0); // 1 can recieve two
assign data_psum_r =  (reg_CONV_MODE_AB_order == 1'b0)? sram_bankB_data_out_i:sram_bankA_data_out_i;
always_ff @(negedge rst_n, posedge clk)begin
    if(~rst_n)begin
        o_data_write <= 'b0;
        o_cs         <= 'b0;
        o_we_en      <= 'b0;
        o_addr       <= 'b0;
        o_byte_en    <= 'b0;
    end else begin
        o_data_write <= data_write ;
        o_cs         <= cs         ;
        o_we_en      <= we_en      ;
        o_addr       <= addr       ;
        o_byte_en    <= byte_en    ;        
    end
end

always_comb begin
    if(reg_CONV_MODE_AB_order == 1'b0)begin
        sram_bankA_cs_o          =   bm_bankA_cs_i          ;
        sram_bankA_we_o          =   bm_bankA_we_i          ;
        sram_bankA_addr_o        =   bm_bankA_addr_i        ;
        sram_bankA_data_in_o     =   bm_bankA_data_in_i     ;
        sram_bankA_byte_enable_o =   bm_bankA_byte_enable_i ;
        bm_bankA_data_out_o         =   sram_bankA_data_out_i    ;
        
        sram_bankB_cs_o          = o_cs;
        sram_bankB_we_o          = o_we_en;
        sram_bankB_addr_o        = o_addr;
        sram_bankB_data_in_o     = o_data_write;
        sram_bankB_byte_enable_o = o_byte_en;
        bm_bankB_data_out_o      =  'b0;
    end else begin
        sram_bankB_cs_o          =   bm_bankB_cs_i          ;
        sram_bankB_we_o          =   bm_bankB_we_i          ;
        sram_bankB_addr_o        =   bm_bankB_addr_i        ;
        sram_bankB_data_in_o     =   bm_bankB_data_in_i     ;
        sram_bankB_byte_enable_o =   bm_bankB_byte_enable_i ;
        bm_bankB_data_out_o    =   sram_bankB_data_out_i    ;

        sram_bankA_cs_o          = o_cs;
        sram_bankA_we_o          = o_we_en;
        sram_bankA_addr_o        = o_addr;
        sram_bankA_data_in_o     = o_data_write;
        sram_bankA_byte_enable_o = o_byte_en;
        bm_bankA_data_out_o         =   'b0    ;
    end
end

always_comb begin
    if(reg_CONV_MODE_AB_order == 1'b0)begin
        cs_bm = bm_bankB_cs_i;
        addr_bm_w = bm_bankB_addr_i;
        we_en_bm = bm_bankB_we_i;
        data_bm_w = bm_bankB_data_in_i;
        byte_en_bm = bm_bankB_byte_enable_i;
    end else begin
        cs_bm = bm_bankA_cs_i;
        addr_bm_w = bm_bankA_addr_i;
        we_en_bm = bm_bankA_we_i;
        data_bm_w = bm_bankA_data_in_i;
        byte_en_bm = bm_bankA_byte_enable_i;
    end
end

always_comb begin
    if(flag == 1'b0)begin
        data_psum_trdy_o = 1'b0;
    end else begin
        data_psum_trdy_o = 1'b1;
    end
end

// always_ff @( posedge clk, negedge rst_n ) begin 
//     if(~rst_n)begin
//         data_psum_trdy_o = 1'b0;
//     end else begin
//         if(flag == 1'b0)begin
//             data_psum_trdy_o = 1'b0;
//         end else begin
//             data_psum_trdy_o = 1'b1;
//         end
//     end
// end

always_comb begin
    if(flag)begin
        for (int i = 0; i < 16; i++)begin
            if(cs_bm[i])begin
                for (int j = 0; j < 128; j++)begin
                    data_write[i][j] = data_bm_w[i][j]; 
                end
            end else if(cs_psum[i]) begin
                for (int j = 0; j < 128; j++)begin
                    data_write[i][j] = data_psum_w[i][j]; 
                end
            end else begin
                // data_write = 8192'b0;
                for (int j = 0; j < 128; j++)begin
                    data_write[i][j] = 'b0; 
                end
            end
        end
    end else begin
        for (int i = 0; i < 16; i++)begin
            for (int j = 0; j < 128; j++)begin
                data_write[i][j] = data_bm_w[i][j];
            end
        end
    end
end

always_comb begin
    if(flag)begin
        cs = cs_bm | cs_psum;
    end else begin
        cs = cs_bm;
    end
end


always_comb begin
    if(flag)begin
        we_en = we_en_bm | we_en_psum;
    end else begin
        we_en = we_en_bm;
    end
end
always_comb begin
    if(flag)begin
        for (int i = 0; i < 16; i++)begin
            if(cs_bm[i])begin
                for (int j = 0; j < 11; j++)begin
                    addr[i][j] = addr_bm_w[i][j]; 
                end
            end else if(cs_psum[i]) begin
                for (int j = 0; j < 11; j++)begin
                    addr[i][j] = addr_psum_wr[i][j]; 
                end
            end else begin
                for (int j = 0; j < 11; j++)begin
                    addr[i][j] = 'b0;
                end
            end
        end
    end else begin
        for (int i = 0; i < 16; i++)begin
            for (int j = 0; j < 11; j++)begin
                addr[i][j] = addr_bm_w[i][j];
            end
        end
    end
end

always_comb begin
    if(flag)begin
        for (int i = 0; i < 16; i++)begin
            if(cs_bm[i])begin
                for (int j = 0; j < 16; j++)begin
                    byte_en[i][j] = byte_en_bm[i][j]; 
                end
            end else if(cs_psum[i]) begin
                for (int j = 0; j < 16; j++)begin
                    byte_en[i][j] = byte_en_psum[i][j]; 
                end
            end else begin
                // byte_en = 'b0;
                for (int j = 0; j < 16; j++)begin
                    byte_en[i][j] = 'b0;
                end
            end
        end
    end else begin
        for (int i = 0; i < 16; i++)begin
            for (int j = 0; j < 16; j++)begin
                byte_en[i][j] = byte_en_bm[i][j];
            end
        end
    end
end
endmodule
