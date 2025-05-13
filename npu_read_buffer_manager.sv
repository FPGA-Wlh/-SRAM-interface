module npu_read_buffer_manager(
    input   logic                       clk_i,
    input   logic                       rst_n,
    //commander signal
    input   logic                       conv_start_i,//pulse signal to trigger the beginning of reading data
    //ram interface
    output  logic   [15:0]              read_cs_o,//chip select of ram
    output  logic   [15:0][10:0]        read_addr_o,//address of read data
    input   logic   [15:0][127:0]       read_data_out_i,//data read from bank A or bank B
    //configuration registers held during convolution
    input   logic                       reg_CONV_MODE_upsample,//upsample enable
    input   logic   [10:0]              reg_MEM_IN1_offset_x,
    input   logic   [3:0]               reg_MEM_IN1_offset_y,
    input   logic   [10:0]              reg_MEM_IN2_offset_x,//additional offset for elementwise calculation
    input   logic   [3:0]               reg_MEM_IN2_offset_y,//additional offset for elementwise calculation
    input   logic   [7:0]               reg_CROP_row_st,//row start value
    input   logic   [7:0]               reg_CROP_col_st,//colum start value
    input   logic   [10:0]              reg_CROP_ROW_row_out,//row number
    input   logic   [10:0]              reg_CROP_COL_col_out,//colum number
    input   logic   [7:0]               reg_PAD1_t,//pad top
    input   logic   [7:0]               reg_PAD1_b,//pad bottom
    input   logic   [7:0]               reg_PAD2_l,//pad left
    input   logic   [7:0]               reg_PAD2_r,//pad right
    input   logic   [7:0]               reg_CONV_MODE_mode,//convolution mode
    input   logic   [10:0]              reg_FM_ROW_row,//total row number for each group
    input   logic   [10:0]              reg_FM_COL_col,//total colum number for each group
    input   logic   [11:0]              reg_FM_ICH_ich,//input channel 
    input   logic   [11:0]              reg_FM_OCH_ST_och_st,//output channel start
    input   logic   [11:0]              reg_FM_OCH_ED_och_ed,//output channel end
    //from top
    input   logic                       en_i,//enable signal for whole npu
    //from wbm
    input   logic                       conv_finish_i,//convolution finish signal from write buffer manager
    //read port
    output  logic   [7:0][9:0][15:0]    fm_out_o,//frame out
    output  logic                       fm_out_irdy_o,//input ready
    input   logic                       fm_out_trdy_i,//transform ready
    output  logic                       fm_out_last_o,//last colum of each frame
    output  logic   [9:0]               fm_out_row_valid_o,// row valid
    output  logic   [7:0]               fm_out_ch_valid_o,//channel valid
    //from row_col_num_manager
    input   logic   [10:0]              rbm_col_num_pe_i,//column number plus empty
    //to wbm
    output  logic   [7:0]               rbm_frame_num_o//frame number from read buffer manager
);

localparam BYPASS = 8'h0;
localparam CONV3x3 = 8'h1;
localparam CONV3x3RGBA = 8'h2;
localparam CONV3x3DW = 8'h3;
localparam CONV1x1 = 8'h4;
localparam ELEMENTWISE_ADD = 8'h5;
localparam ELEMENTWISE_MUL = 8'h6;

logic [15:0][7:0][15:0] read_data_reg_1;//the first line of data buffer
logic [15:0][7:0][15:0] read_data_reg_2;//the second line of data buffer
logic [2:0] pip_stall_dly;//pipline stall delay 1 cycle

logic   [11:0]  rbm_och;//output channel from the vision of rbm

logic   [17:0]  dividend_for_offset;//dividend for calculation of in1_offset_x and in1_offset_y
logic   [10:0]  in1_offset_x;
logic   [3:0]   in1_offset_y;

logic           pip_stall;// stall registers during running mode
logic           pip_stall_state;//when pip_stall_state == 1, pip_stall is controled by fm_out_trdy_i

logic   [11:0]  och_st_exa_div_32;//output channel start exactly divided by 32
logic   [11:0]  och_for_group;//output channel end subtract channel start(exactly divided by 32) and plus 1, for calculation of group num in bypass, dw and ele mode
logic   [7:0]   num_group;//total group number

logic   [15:0]  full_col_num_plus_empty;//include reg_FM_COL_col, reg_PAD2_l and reg_PAD2_r
logic   [15:0]  col_out_plus_pad;//column out plus pad left and pad right ??diffrence/？？

logic   [7:0]   pad_t_frame_row;//pad_t
logic   [10:0]  row_plus_t_pad;//row plus top pad
logic   [10:0]  row_plus_pad;// row plus pad top and pad bottom
logic   [10:0]  row_plus_pad_sub_2;// row plus pad top and pad bottom substract 2

logic   [7:0]   pad_t_frame_row_sub_2;//pad top subtract 2

logic   [7:0]   num_row_frame;//total frame number
logic   [3:0]   num_row_per_frame;//row number per row frame    // 位宽改为了【4：0】
logic   [7:0]   num_row_frame_padt_rowout;//frame number including pad top and row out
logic   [7:0]   num_t_zero_frame;//frame number of pad top (all zero)
logic   [8:0]   num_traversal;//traversal times

//arrays of depth 2 are adopted for elementwise reading
logic   [3:0]   mem_start_index [1:0];//memory start index
logic   [3:0]   mem_end_index [1:0];//memory end index

logic   [10:0]  mem_col_start_1 [1:0];//memory column start
logic   [10:0]  mem_col_start_2 [1:0];

logic   [10:0]  read_addr_1 [1:0];
logic   [10:0]  read_addr_2 [1:0];

logic           wrap_around[1:0];//memory start index < memory start index


logic   [7:0]   row_num_pad_t;//number of top padding rows in row_frame_pad_t
logic   [15:0]  row_num_not_pad_b;//number of no bottom padding rows in row_frame_pad_b
logic   [15:0]  row_valid_num;//number of valid rows in last row frame

logic           ele_enable;//elementwise mode enable
logic           channel4_enable;//channel4 mode enable
logic           dw_enable;//depthwise enable
logic           bypass_enable;//bypass enable

logic   [15:0]  st_idx_plus_in1_os_y;//start index plus in1 offset y
logic   [15:0]  ed_idx_plus_in1_os_y;//end index plus in1 offset y
logic   [15:0]  st_idx_plus_in2_os_y;//start index plus in2 offset y
logic   [15:0]  ed_idx_plus_in2_os_y;//end index plus in2 offset y

logic   [9:0][7:0][15:0]   fm_out_wire;//frame out wire

logic   [8:0]   group_col_div_8;//column number divide by 8

logic           half_group_beginning;//the beginning half group in the first group
logic           half_group_threshold;//the threshold half group in the last group
logic           ele_select_last_th;//threshold signal for ele_select signal of the last col of row frame
//delay
logic           col_last_d1, col_last_d2, col_last_d3;
logic           frame_last_d1, frame_last_d2, frame_last_d3;
logic   [3:0]   mem_start_index_d1, mem_start_index_d2, mem_start_index_d3;
logic           read_zero_d1, read_zero_d2, read_zero_d3;
logic           row_frame_pad_t_d1, row_frame_pad_t_d2, row_frame_pad_t_d3;
logic           row_frame_pad_b_d1, row_frame_pad_b_d2, row_frame_pad_b_d3;
logic   [7:0]   row_num_pad_t_d1, row_num_pad_t_d2, row_num_pad_t_d3;
logic   [15:0]   row_num_not_pad_b_d1, row_num_not_pad_b_d2, row_num_not_pad_b_d3;
logic   [15:0]   row_valid_num_d1, row_valid_num_d2, row_valid_num_d3;
logic   [2:0]   count_4c_d1, count_4c_d2, count_4c_d3, count_4c_d4;
logic           read_valid_d1, read_valid_d2, read_valid_d3;
logic           read_irdy_d1, read_irdy_d2, read_irdy_d3;
logic           half_group_select_d1, half_group_select_d2, half_group_select_d3;
logic           read_enable_d1, read_enable_d2;
logic   [4:0]   conv_start_dly;
logic   [2:0]   group_last_dly;

logic   [9:0][7:0][15:0]    read_data_out_barrel ;//read data after barrel shifter
logic   [9:0][7:0][15:0]    fm_out  ;//feature map out
logic   [9:0]               fm_row_valid ;
logic   [15:0][7:0][15:0]   read_data_out ;

//fsm
enum logic [2:0] {IDLE, RUNNING, RUNNING_BYPASS, RUNNING_ELE, RUNNING_4CHANNEL} CS, NS;
logic   [7:0]   curr_row_frame_cs, curr_row_frame_ns;//current row frame
logic   [15:0]  col_cs, col_ns;//including origin reg_CROP_COL_col_out and reg_PAD2_l and reg_PAD2_r
logic   [15:0]  col_nzero_ns;//current no-pad column
logic   [15:0]  col_in_matrix_cs, col_in_matrix_ns;//the column index in the matrix in the sram
logic           ele_select_cs, ele_select_ns;//elementwise select signal
logic           upsample_hold_cs, upsample_hold_ns;//upsample mode need one cycle of holding state
logic           half_group_select_cs, half_group_select_ns;//select of higher or lower 16 channels in readed 32 channels
logic           read_4c_enable_cs, read_4c_enable_ns;//high when read is needed next clock cycle in RUNNING_4CHANNEL
logic   [10:0]  curr_group_cs, curr_group_ns;//current group
logic   [15:0]  group_offset_cs, group_offset_ns;//group offset, interger multiple of reg_FM_COL_col
logic   [11:0]  curr_traversal_cs, curr_traversal_ns;//current traversal
logic   [15:0]  start_index_cs, start_index_ns;//start index
logic   [15:0]  end_index_cs, end_index_ns;//end index
logic           read_enable_cs, read_enable_ns;//read enable signal
logic           read_zero_cs, read_zero_ns;//read zero(pad) signal
logic           read_valid_cs, read_valid_ns;//read valid signal (including pad)
logic           read_irdy_cs, read_irdy_ns;//read valid signal (including pad)
logic           col_last;
logic           frame_last;
logic           group_last;
logic           traversal_last;
logic           row_frame_pad_t;//signal represent current row frame includes top padding (possibly) and data from ram
logic           row_frame_pad_b;//signal represent current row frame includes bottom padding (possibly) and data from ram

logic [15:0] col_out_add_pad2_l;//column out add pad left

logic   [10:0] row_num_pad_t_11bit;//row number of pad top in the row frame containing pad top and row out

assign rbm_och = reg_FM_OCH_ED_och_ed - reg_FM_OCH_ST_och_st + 1;
assign dividend_for_offset = reg_FM_OCH_ST_och_st[11:4] * reg_FM_ROW_row + reg_MEM_IN1_offset_y;
always_comb begin
    if(dw_enable) begin
        in1_offset_x = reg_MEM_IN1_offset_x + dividend_for_offset[17:4] * reg_FM_COL_col;
        in1_offset_y = dividend_for_offset[3:0];
    end else begin
        in1_offset_x = reg_MEM_IN1_offset_x;
        in1_offset_y = reg_MEM_IN1_offset_y;
    end
end
always_ff @(negedge rst_n, posedge clk_i) begin
    if(!rst_n) begin
        pip_stall_state <= 1'b0;
    end else begin
        if(conv_start_dly[3]) begin //first col of first row frame has been outputed
            pip_stall_state <= 1'b1;
        end else if(conv_finish_i) begin
            pip_stall_state <= 1'b0;
        end else begin
            pip_stall_state <= pip_stall_state;
        end
    end
end
assign pip_stall = pip_stall_state & (~fm_out_trdy_i) &(fm_out_irdy_o);
assign group_col_div_8 = (reg_FM_COL_col[2:0] == 0) ? reg_FM_COL_col[10:3] : (reg_FM_COL_col[10:3] + 1);

always_comb begin
    case (reg_CONV_MODE_mode)
        BYPASS: begin
            if(reg_CONV_MODE_upsample) begin
                num_row_per_frame = 4;
            end else begin
                num_row_per_frame = 8;
            end
        end
        CONV1x1, ELEMENTWISE_ADD, ELEMENTWISE_MUL: begin
            num_row_per_frame = 8;
        end
        CONV3x3, CONV3x3RGBA, CONV3x3DW: begin
            num_row_per_frame = 10;
        end
        default: begin
            num_row_per_frame = 0;
        end
    endcase
end
assign row_plus_pad = reg_PAD1_t + reg_PAD1_b + reg_CROP_ROW_row_out;
assign row_plus_pad_sub_2 = row_plus_pad - 2;
assign row_plus_t_pad = reg_PAD1_t + reg_CROP_ROW_row_out;
assign pad_t_frame_row = reg_PAD1_t;
assign pad_t_frame_row_sub_2 = pad_t_frame_row - 2;

always_comb begin
    if(num_row_per_frame == 8) begin
        num_row_frame = (row_plus_pad[2:0] == 3'b0) ? row_plus_pad[10:3] : (row_plus_pad[10:3] + 1);
    end else if(num_row_per_frame == 10) begin
        num_row_frame = (row_plus_pad_sub_2[2:0] == 3'b0) ? row_plus_pad_sub_2[10:3] : (row_plus_pad_sub_2[10:3] + 1);
    end else begin //num_row_per_frame == 4
        num_row_frame = (row_plus_pad[1:0] == 2'b0) ? row_plus_pad[10:2] : (row_plus_pad[10:2] + 1);
    end
end
assign rbm_frame_num_o = num_row_frame;
always_comb begin
    if(num_row_per_frame == 8) begin
        num_row_frame_padt_rowout = (row_plus_t_pad[2:0] == 3'b0) ? row_plus_t_pad[10:3] : (row_plus_t_pad[10:3] + 1);
    end else if(num_row_per_frame == 10) begin
        if(row_plus_t_pad[2:0] == 1 && (reg_PAD1_b == 0 || reg_PAD1_b == 1)) begin
        //no extra row frame including row_out or pad_t
            num_row_frame_padt_rowout = num_row_frame;
        end else if(row_plus_t_pad[2:0] == 2 && reg_PAD1_b == 0) begin
        //no extra row frame including row_out or pad_t
            num_row_frame_padt_rowout = num_row_frame;
        end else begin
        //including two case
        //1. remainder belongs to {1, 2}: num_row_frame_padt_rowout = �?(row_plus_t_pad-2)/8�? + 1 = ⌈row_plus_t_pad/8�?
        //2. remainder belongs to {3, 4, 5, 6, 7, 0}: num_row_frame_padt_rowout = �?(row_plus_t_pad-2)/8�? = ⌈row_plus_t_pad/8�?
        //extra row frame including row_out or pad_t
            num_row_frame_padt_rowout = (row_plus_t_pad[2:0] == 3'b0) ? row_plus_t_pad[10:3] : (row_plus_t_pad[10:3] + 1);
        end
    end else begin //num_row_per_frame == 4
        num_row_frame_padt_rowout = num_row_frame;
    end
end
always_comb begin
    if(num_row_per_frame == 8) begin
        num_t_zero_frame = {3'b0, pad_t_frame_row[7:3]};
    end else if(num_row_per_frame == 10)begin
        if(pad_t_frame_row < 2) begin
            num_t_zero_frame = 0;
        end else begin
            num_t_zero_frame = {3'b0, pad_t_frame_row_sub_2[7:3]};
        end
    end else begin //num_row_per_frame == 4
        num_t_zero_frame = 0;
    end
end
always_comb begin
    if(dw_enable || ele_enable || bypass_enable) begin
        num_traversal = 1;
    end else begin
        num_traversal = (rbm_och[2:0] == 3'b0) ? rbm_och[11:3] : (rbm_och[11:3] + 1);
    end
end
assign row_num_pad_t_11bit = {3'b0, pad_t_frame_row} - {curr_row_frame_cs, 3'b0};
assign row_num_pad_t = row_num_pad_t_11bit[7:0];
always_comb begin
    if(reg_CONV_MODE_upsample == 1'b1) begin
        row_valid_num = {{row_plus_pad - {curr_row_frame_cs, 2'b0}}, 1'b0};
        row_num_not_pad_b = {{row_plus_t_pad - {curr_row_frame_cs, 2'b0}}, 1'b0};
    end else begin
        row_valid_num = row_plus_pad - {curr_row_frame_cs, 3'b0};
        row_num_not_pad_b = row_plus_t_pad - {curr_row_frame_cs, 3'b0};
    end
end
always_comb begin
    if(num_row_per_frame == 8) begin
        if(({3'b0, pad_t_frame_row} > {curr_row_frame_cs, 3'b0}) && row_num_pad_t < 8) begin
            row_frame_pad_t = 1'b1;
        end else begin
            row_frame_pad_t = 1'b0;
        end
    end else if(num_row_per_frame == 10) begin
        if(({3'b0, pad_t_frame_row} > {curr_row_frame_cs, 3'b0}) && row_num_pad_t < 10) begin
            row_frame_pad_t = 1'b1;
        end else begin
            row_frame_pad_t = 1'b0;
        end
    end else begin //num_row_per_frame == 4
        row_frame_pad_t = 1'b0;
    end
end
always_comb begin
    if(num_row_per_frame == 8) begin
        if((row_plus_t_pad > {curr_row_frame_cs, 3'b0}) && row_num_not_pad_b < 8) begin
            row_frame_pad_b = 1'b1;
        end else begin
            row_frame_pad_b = 1'b0;
        end
    end else begin
        if((row_plus_t_pad > {curr_row_frame_cs, 3'b0}) && row_num_not_pad_b < 10) begin
            row_frame_pad_b = 1'b1;
        end else begin
            row_frame_pad_b = 1'b0;
        end
    end
end

assign col_out_plus_pad = reg_CROP_COL_col_out + reg_PAD2_l + reg_PAD2_r;
assign full_col_num_plus_empty = rbm_col_num_pe_i;
assign ele_select_last_th = (full_col_num_plus_empty == col_out_plus_pad);
assign och_st_exa_div_32 = {reg_FM_OCH_ST_och_st[11:5], 5'b0};
assign och_for_group = reg_FM_OCH_ED_och_ed - och_st_exa_div_32 + 1;
always_comb begin
    if(dw_enable || ele_enable || bypass_enable) begin
        num_group = (och_for_group[4:0] == 3'b0) ? och_for_group[11:4] : (och_for_group[11:4] + 1);
    end else if(channel4_enable)begin
        num_group = 2;
    end else begin
        num_group = (reg_FM_ICH_ich[3:0] == 4'b0) ? reg_FM_ICH_ich[11:4] : (reg_FM_ICH_ich[11:4] + 1);
    end
end

always_comb begin
    if(ele_enable || bypass_enable || dw_enable) begin
        if(reg_FM_OCH_ST_och_st[3] == 1) begin//
            half_group_beginning = 1'b1;
        end else begin
            half_group_beginning = 1'b0;
        end
    end else begin
        half_group_beginning = 1'b0;
    end
end
always_comb begin
    if(ele_enable || bypass_enable || dw_enable) begin
        if(reg_FM_OCH_ED_och_ed[3] == 0) begin//
            half_group_threshold = 1'b0;
        end else begin
            half_group_threshold = 1'b1;
        end
    end else begin
        half_group_threshold = 1'b0;
    end
end
assign ele_enable = (reg_CONV_MODE_mode == ELEMENTWISE_ADD || reg_CONV_MODE_mode == ELEMENTWISE_MUL);
assign channel4_enable = (reg_CONV_MODE_mode == CONV3x3RGBA);
assign dw_enable = (reg_CONV_MODE_mode == CONV3x3DW);
assign bypass_enable = (reg_CONV_MODE_mode == BYPASS);

always_comb begin
    case (CS)
        IDLE: begin
            if(conv_start_i) begin
                case (reg_CONV_MODE_mode)
                    CONV1x1, CONV3x3: begin NS = RUNNING; end
                    BYPASS, CONV3x3DW: begin NS = RUNNING_BYPASS; end
                    ELEMENTWISE_ADD, ELEMENTWISE_MUL: begin NS = RUNNING_ELE; end
                    CONV3x3RGBA: begin NS = RUNNING_4CHANNEL; end
                    default: begin NS = CS; end
                endcase
            end else begin
                NS = CS;
            end
        end
        RUNNING, RUNNING_4CHANNEL: begin//RUNNING includes CONV_3x3 and CONV_1x1, RUNNING_4CHANNEL includes CONV_3x3RGBA
            if (en_i == 0 || conv_finish_i == 1) begin
                NS = IDLE;
            end else begin
                if(col_cs == full_col_num_plus_empty-1 && frame_last==1'b1 && group_last==1'b1 && traversal_last==1'b1) begin
                    NS = IDLE;
                end else begin
                    NS = CS;
                end
            end
        end
        RUNNING_BYPASS: begin//including BYPASS and CONV_3x3DW mode
            if (en_i == 0 || conv_finish_i == 1) begin
                NS = IDLE;
            end else begin
                if(reg_CONV_MODE_upsample == 1'b1) begin
                    if(upsample_hold_cs == 1'b1 && col_cs == col_out_plus_pad-1 && frame_last==1'b1 && half_group_select_cs == half_group_threshold && group_last==1'b1) begin
                        NS = IDLE;
                    end else begin
                        NS = CS;
                    end
                end else begin
                    if(col_cs == full_col_num_plus_empty-1 && frame_last==1'b1 && half_group_select_cs == half_group_threshold && group_last==1'b1) begin
                        NS = IDLE;
                    end else begin
                        NS = CS;
                    end
                end
            end
        end
        RUNNING_ELE: begin
            if (en_i == 0 || conv_finish_i == 1) begin
                NS = IDLE;
            end else begin
                if(ele_select_cs==ele_select_last_th && col_cs == full_col_num_plus_empty-1 && frame_last==1'b1 && half_group_select_cs == 1'b1 && group_last==1'b1) begin
                    NS = IDLE;
                end else begin
                    NS = CS;
                end
            end
        end
        default: begin NS = IDLE; end
    endcase
end

always_ff @(negedge rst_n, posedge clk_i) begin
    if(!rst_n) begin
        CS <= IDLE;
    end else begin
        CS <= NS;
    end
end

always_comb begin
    if(conv_start_i) begin
        col_ns = 16'b0;
    end else begin
        if(pip_stall) begin
            col_ns = col_cs;
        end else begin
            case(CS)
                IDLE: begin col_ns = col_cs; end
                RUNNING, RUNNING_4CHANNEL: begin
                    if(col_cs == full_col_num_plus_empty-1) begin
                        col_ns = 16'b0;
                    end else begin
                        col_ns = col_cs + 1;
                    end
                end
                RUNNING_BYPASS: begin
                    if(reg_CONV_MODE_upsample == 1'b1) begin
                        if(upsample_hold_ns == 1'b0) begin
                            if(col_cs == col_out_plus_pad-1) begin
                                col_ns = 16'b0;
                            end else begin
                                col_ns = col_cs + 1;
                            end
                        end else begin
                            col_ns = col_cs;
                        end
                    end else begin
                        if(col_cs == full_col_num_plus_empty-1) begin
                            col_ns = 16'b0;
                        end else begin
                            col_ns = col_cs + 1;
                        end
                    end
                end
                RUNNING_ELE: begin
                    if(col_cs == full_col_num_plus_empty-1) begin
                        if(ele_select_cs == ele_select_last_th) begin
                            col_ns = 16'b0;
                        end else begin
                            col_ns = col_cs;
                        end
                    end else begin
                        if(ele_select_cs == 1) begin
                            col_ns = col_cs + 1;
                        end else begin
                            col_ns = col_cs;
                        end
                    end
                end
                default: begin
                    col_ns = col_cs;
                end
            endcase
        end
    end
end
always_ff @(negedge rst_n, posedge clk_i) begin
    if(!rst_n) begin
        col_cs <= 16'b0;
    end else begin
        col_cs <= col_ns;
    end
end
assign col_out_add_pad2_l = {8'b0, reg_PAD2_l} + {5'b0, reg_CROP_COL_col_out};
always_comb begin
    if(col_ns < {8'b0, reg_PAD2_l} || col_ns >= col_out_add_pad2_l) begin
        col_nzero_ns = 16'b0;
    end else begin
        col_nzero_ns = col_ns - reg_PAD2_l;
    end
end
assign col_in_matrix_ns = reg_CROP_col_st + col_nzero_ns;
always_ff @(negedge rst_n, posedge clk_i) begin
    if(!rst_n) begin
        col_in_matrix_cs <= 16'b0;
    end else begin
        col_in_matrix_cs <= col_in_matrix_ns;
    end
end

always_comb begin
    if(conv_start_i) begin
        curr_row_frame_ns = 8'b0;
    end else begin
        if(pip_stall) begin
            curr_row_frame_ns = curr_row_frame_cs;
        end else begin
            case (CS)
                IDLE: begin 
                    curr_row_frame_ns = curr_row_frame_cs; 
                end
                RUNNING, RUNNING_4CHANNEL, RUNNING_ELE, RUNNING_BYPASS: begin
                    if((col_ns == 16'b0) && (ele_select_ns == 1'b0) && (upsample_hold_ns == 1'b0)) begin
                        if(curr_row_frame_cs == num_row_frame-1) begin
                            curr_row_frame_ns = 8'b0;
                        end else begin
                            curr_row_frame_ns = curr_row_frame_cs + 1;
                        end
                    end else begin
                        curr_row_frame_ns = curr_row_frame_cs;
                    end
                end
                default: begin
                    curr_row_frame_ns = curr_row_frame_cs;
                end
            endcase
        end
    end
end
always_ff @(negedge rst_n, posedge clk_i) begin
    if(!rst_n) begin
        curr_row_frame_cs <= 8'b0;
    end else begin
        curr_row_frame_cs <= curr_row_frame_ns;
    end
end

always_comb begin
    if(conv_start_i) begin
        curr_group_ns = 11'b0;
        group_offset_ns = 16'b0;
    end else begin
        if(pip_stall) begin
            curr_group_ns = curr_group_cs;
            group_offset_ns = group_offset_cs;
        end else begin
            case (CS)
                IDLE: begin 
                    curr_group_ns = curr_group_cs;
                    group_offset_ns = group_offset_cs;
                end
                RUNNING, RUNNING_4CHANNEL, RUNNING_ELE, RUNNING_BYPASS: begin
                    if((col_ns == 16'b0) && (ele_select_ns == 1'b0) && (upsample_hold_ns == 1'b0) && (curr_row_frame_ns == 8'b0) && (half_group_select_ns == 1'b0)) begin
                        if(curr_group_cs == num_group - 1) begin
                            curr_group_ns = 11'b0;
                            group_offset_ns = 16'b0;
                        end else begin
                            curr_group_ns = curr_group_cs + 1;
                            group_offset_ns = group_offset_cs + reg_FM_ROW_row;
                        end
                    end else begin
                        curr_group_ns = curr_group_cs;
                        group_offset_ns = group_offset_cs;
                    end
                end
                default: begin
                    curr_group_ns = curr_group_cs;
                    group_offset_ns = group_offset_cs;
                end
            endcase
        end
    end
end

always_ff @(negedge rst_n, posedge clk_i) begin
    if(!rst_n) begin
        curr_group_cs <= 11'b0;
        group_offset_cs <= 16'b0;
    end else begin
        curr_group_cs <= curr_group_ns;
        group_offset_cs <= group_offset_ns;
    end
end

always_comb begin
    if(conv_start_i) begin
        curr_traversal_ns = 11'b0;
    end else begin
        if(pip_stall) begin
            curr_traversal_ns = curr_traversal_cs;
        end else begin
            case (CS)
                IDLE: begin 
                    curr_traversal_ns = curr_traversal_cs;
                end
                RUNNING, RUNNING_4CHANNEL: begin
                    if((col_ns == 16'b0) && (curr_row_frame_ns == 8'b0) && (curr_group_ns == 11'b0)) begin
                        if(curr_traversal_cs == num_traversal - 1) begin
                            curr_traversal_ns = 11'b0;
                        end else begin
                            curr_traversal_ns = curr_traversal_cs + 1;
                        end
                    end else begin
                        curr_traversal_ns = curr_traversal_cs;
                    end
                end
                default: begin
                    curr_traversal_ns = curr_traversal_cs;
                end
            endcase
        end
    end
end

always_ff @(negedge rst_n, posedge clk_i) begin
    if(!rst_n) begin
        curr_traversal_cs <= 11'b0;
    end else begin
        curr_traversal_cs <= curr_traversal_ns;
    end
end

always_comb begin
    if(conv_start_i) begin
        ele_select_ns = 1'b0;
    end else begin
        if(pip_stall) begin
            ele_select_ns = ele_select_cs;
        end else begin
            if(CS == RUNNING_ELE) begin
                if (full_col_num_plus_empty != col_out_plus_pad) begin
                    if (col_cs == full_col_num_plus_empty - 1 && ele_select_cs == ele_select_last_th) begin
                        ele_select_ns = 1'b0;
                    end else begin
                        ele_select_ns = ~ele_select_cs;
                    end
                end else begin
                    ele_select_ns = ~ele_select_cs;
                end
            end else begin
                ele_select_ns = 1'b0;
            end
        end
    end
end
always_ff @(negedge rst_n, posedge clk_i) begin
    if(!rst_n) begin
        ele_select_cs <= 1'b0;
    end else begin
        ele_select_cs <= ele_select_ns;
    end
end
always_comb begin
    if(conv_start_i) begin
        upsample_hold_ns = 1'b0;
    end else begin
        if(pip_stall) begin
            upsample_hold_ns = upsample_hold_cs;
        end else begin
            if(CS == RUNNING_BYPASS && reg_CONV_MODE_upsample == 1'b1) begin
                upsample_hold_ns = ~upsample_hold_cs;
            end else begin
                upsample_hold_ns = 1'b0;
            end
        end
    end
end
always_ff @(negedge rst_n, posedge clk_i) begin
    if(!rst_n) begin
        upsample_hold_cs <= 1'b0;
    end else begin
        upsample_hold_cs <= upsample_hold_ns;
    end
end
always_comb begin
    if(conv_start_i) begin
        half_group_select_ns = half_group_beginning;
    end else begin
        if(pip_stall) begin
            half_group_select_ns = half_group_select_cs;
        end else begin
            if(CS == RUNNING_ELE || CS == RUNNING_BYPASS) begin
                if((col_ns == 16'b0) && (ele_select_ns == 1'b0) && (upsample_hold_ns == 1'b0) && (curr_row_frame_ns == 8'b0)) begin
                    half_group_select_ns = ~half_group_select_cs;
                end else begin
                    half_group_select_ns = half_group_select_cs;
                end
            end else begin
                half_group_select_ns = 1'b0;
            end
        end
    end
end
always_ff @(negedge rst_n, posedge clk_i) begin
    if(!rst_n) begin
        half_group_select_cs <= 1'b0;
    end else begin
        half_group_select_cs <= half_group_select_ns;
    end
end
always_comb begin
    if(conv_start_i) begin
        if(channel4_enable && reg_PAD2_l == 8'b0) begin
            read_4c_enable_ns = 1'b1;
        end else begin
            read_4c_enable_ns = 1'b0;
        end
    end else begin
        if(pip_stall) begin
            read_4c_enable_ns = read_4c_enable_cs;
        end else begin
            if(CS == RUNNING_4CHANNEL) begin
                if(col_ns < {8'b0, reg_PAD2_l} || col_ns >= col_out_add_pad2_l) begin
                    read_4c_enable_ns = 1'b0;
                end else if(col_ns == {8'b0, reg_PAD2_l}) begin
                    read_4c_enable_ns = 1'b1;
                end else if(col_in_matrix_ns[2:0] == 3'b0) begin
                    read_4c_enable_ns = 1'b1;
                end else begin
                    read_4c_enable_ns = 1'b0;
                end
            end else begin
                read_4c_enable_ns = 1'b0;
            end
        end
    end
end
always_ff @(negedge rst_n, posedge clk_i) begin
    if(!rst_n) begin
        read_4c_enable_cs <= 1'b0;
    end else begin
        read_4c_enable_cs <= read_4c_enable_ns;
    end
end

always_ff @(negedge rst_n, posedge clk_i) begin
    if(!rst_n) begin
        col_last <= 1'b0;
    end else begin
        if(conv_start_i) begin
            if((reg_CONV_MODE_mode != ELEMENTWISE_ADD) && (reg_CONV_MODE_mode != ELEMENTWISE_MUL) && (reg_PAD2_l + reg_PAD2_r + reg_CROP_COL_col_out == 16'h1)) begin
                col_last <= 1'b1;
            end else begin
                col_last <= 1'b0;
            end
        end else begin
            if(pip_stall) begin
                col_last <= col_last;
            end else begin
                case (CS)
                    RUNNING, RUNNING_4CHANNEL: begin
                        if(col_ns == col_out_plus_pad-1) begin
                            col_last <= 1'b1;
                        end else begin
                            col_last <= 1'b0;
                        end
                    end
                    RUNNING_BYPASS: begin
                        if(reg_CONV_MODE_upsample == 1'b1) begin
                            if(col_ns == col_out_plus_pad-1 && upsample_hold_ns == 1'b1) begin
                                col_last <= 1'b1;
                            end else begin
                                col_last <= 1'b0;
                            end
                        end else begin
                            if(col_ns == col_out_plus_pad-1) begin
                                col_last <= 1'b1;
                            end else begin
                                col_last <= 1'b0;
                            end
                        end
                    end
                    RUNNING_ELE: begin
                        if((col_ns == col_out_plus_pad-1) && ele_select_ns == 1'b1) begin
                            col_last <= 1'b1;
                        end else begin
                            col_last <= 1'b0;
                        end
                    end
                    default: begin
                        col_last <= 1'b0;
                    end
                endcase
            end
        end
    end
end

always_ff @(negedge rst_n, posedge clk_i) begin
    if(!rst_n) begin
        frame_last <= 1'b0;
    end else begin
        if(conv_start_i) begin
            if(num_row_frame == 8'h1) begin
                frame_last <= 1'b1;
            end else begin
                frame_last <= 1'b0;
            end
        end else begin
            if(pip_stall) begin
                frame_last <= frame_last;
            end else begin
                case (CS)
                    RUNNING, RUNNING_4CHANNEL, RUNNING_ELE, RUNNING_BYPASS: begin
                        if(curr_row_frame_ns == num_row_frame-1) begin
                            frame_last <= 1'b1;
                        end else begin
                            frame_last <= 1'b0;
                        end
                    end
                    default: begin
                        frame_last <= 1'b0;
                    end
                endcase
            end
        end
    end
end

always_ff @(negedge rst_n, posedge clk_i) begin
    if(!rst_n) begin
        group_last <= 1'b0;
    end else begin
        if(conv_start_i) begin
            if(num_group == 8'h1) begin
                group_last <= 1'b1;
            end else begin
                group_last <= 1'b0;
            end
        end else begin
            if(pip_stall) begin
                group_last <= group_last;
            end else begin
                case (CS)
                    RUNNING, RUNNING_4CHANNEL, RUNNING_ELE, RUNNING_BYPASS: begin
                        if(curr_group_ns == num_group-1) begin
                            group_last <= 1'b1;
                        end else begin
                            group_last <= 1'b0;
                        end
                    end
                    default: begin
                        group_last <= 1'b0;
                    end
                endcase
            end
        end
    end
end

always_ff @(negedge rst_n, posedge clk_i) begin
    if(!rst_n) begin
        traversal_last <= 1'b0;
    end else begin
        if(conv_start_i) begin
            if(num_traversal == 1) begin
                traversal_last <= 1'b1;
            end else begin
                traversal_last <= 1'b0;
            end
        end else begin
            if(pip_stall) begin
                traversal_last <= traversal_last;
            end else begin
                case (CS)
                    RUNNING, RUNNING_4CHANNEL: begin
                        if(curr_traversal_ns == num_traversal-1) begin
                            traversal_last <= 1'b1;
                        end else begin
                            traversal_last <= 1'b0;
                        end
                    end
                    default: begin
                        traversal_last <= 1'b0;
                    end
                endcase
            end
        end
    end
end

always_comb begin
    if(conv_start_i) begin
        if(read_zero_ns == 1'b1 || read_valid_ns == 1'b0) begin
            read_enable_ns = 1'b0;
        end else begin
            read_enable_ns = 1'b1;
        end
    end else begin
        if(pip_stall) begin
            read_enable_ns = read_enable_cs;
        end else begin
            if(read_zero_ns == 1'b1 || read_valid_ns == 1'b0) begin
                read_enable_ns = 1'b0;
            end else begin
                case (CS)
                    RUNNING, RUNNING_ELE, RUNNING_BYPASS: begin
                        read_enable_ns = 1'b1;
                    end
                    RUNNING_4CHANNEL: begin
                        read_enable_ns = read_4c_enable_ns;
                    end
                    default: begin
                        read_enable_ns = 1'b0;
                    end
                endcase
            end
        end
    end
end
always_ff @(negedge rst_n, posedge clk_i) begin
    if(!rst_n) begin
        read_enable_cs <= 1'b0;
    end else begin
        read_enable_cs <= read_enable_ns;
    end
end
always_comb begin
    if(conv_start_i) begin
        if(num_t_zero_frame == 8'b0 && reg_PAD2_l == 0) begin
            read_zero_ns = 1'b0;
        end else begin
            read_zero_ns = 1'b1;
        end
    end else begin
        if(pip_stall) begin
            read_zero_ns = read_zero_cs;
        end else begin
            if(read_valid_ns == 1'b0) begin
                read_zero_ns = 1'b0;
            end else begin
                case (CS)
                    RUNNING, RUNNING_4CHANNEL, RUNNING_ELE, RUNNING_BYPASS: begin
                        if((num_t_zero_frame != 0 && curr_row_frame_ns < num_t_zero_frame) || (curr_row_frame_ns >= num_row_frame_padt_rowout)) begin
                            read_zero_ns = 1'b1;
                        end else if(col_ns < {8'b0, reg_PAD2_l} || col_ns >= col_out_add_pad2_l) begin
                            read_zero_ns = 1'b1;
                        end else begin
                            read_zero_ns = 1'b0;
                        end
                    end
                    default: begin
                        read_zero_ns = 1'b0;
                    end
                endcase
            end
        end
    end
end
always_ff @(negedge rst_n, posedge clk_i) begin
    if(!rst_n) begin
        read_zero_cs <= 1'b0;
    end else begin
        read_zero_cs <= read_zero_ns;
    end
end

always_comb begin
    if(conv_start_i) begin
        read_valid_ns = 1'b1;
    end else begin
        if(pip_stall) begin
            read_valid_ns = read_valid_cs;
        end else begin
            case (CS)
                RUNNING, RUNNING_4CHANNEL, RUNNING_ELE, RUNNING_BYPASS: begin
                    if(col_ns >= col_out_plus_pad) begin
                        read_valid_ns = 1'b0;
                    end else begin
                        read_valid_ns = 1'b1;
                    end
                end
                default: begin
                    read_valid_ns = 1'b0;
                end
            endcase
        end
    end
end

always_ff @(negedge rst_n, posedge clk_i) begin
    if(!rst_n) begin
        read_valid_cs <= 1'b0;
    end else begin
        read_valid_cs <= read_valid_ns;
    end
end
// always_comb begin
//     if(conv_start_i) begin
//         read_irdy_ns = 1'b1;
//     end else begin
//         if(pip_stall) begin
//             read_irdy_ns = read_irdy_cs;
//         end else begin
//             case (CS)
//                 RUNNING, RUNNING_4CHANNEL, RUNNING_ELE, RUNNING_BYPASS: begin
//                     if(col_ns >= col_out_plus_pad) begin
//                         read_irdy_ns = 1'b0;
//                     end else begin
//                         read_irdy_ns = 1'b1;
//                     end
//                 end
//                 default: begin
//                     read_irdy_ns = 1'b0;
//                 end
//             endcase
//         end
//     end
// end


// //-----------change by me---------------------------------
// always_comb begin
//     if(conv_start_i) begin
//         read_irdy_ns = 1'b1;
//     end else begin
//         if(pip_stall) begin
//             read_irdy_ns = read_irdy_cs;
//         end else begin
//             case (NS)
//                 RUNNING, RUNNING_4CHANNEL, RUNNING_ELE, RUNNING_BYPASS: begin
//                     if(col_ns >= col_out_plus_pad) begin
//                         read_irdy_ns = 1'b0;
//                     end else begin
//                         read_irdy_ns = 1'b1;
//                     end
//                 end
//                 default: begin
//                     read_irdy_ns = 1'b0;
//                 end
//             endcase
//         end
//     end
// end
// //------------------------------------------------------------

// always_ff @(negedge rst_n, posedge clk_i) begin
//     if(!rst_n) begin
//         read_irdy_cs <= 1'b0;
//     end else begin
//         read_irdy_cs <= read_irdy_ns;
//     end
// end


//-----------change by me---------------------------------
always_comb begin
    if(conv_start_i) begin
        read_irdy_ns = 1'b1;
    end else begin
        case (NS)
            RUNNING, RUNNING_4CHANNEL, RUNNING_ELE, RUNNING_BYPASS: begin
                if(col_ns >= col_out_plus_pad) begin
                    read_irdy_ns = 1'b0;
                end else begin
                    read_irdy_ns = 1'b1;
                end
            end
            default: begin
                read_irdy_ns = 1'b0;
            end
        endcase
    end
end
//------------------------------------------------------------

always_ff @(negedge rst_n, posedge clk_i) begin
    if(!rst_n) begin
        read_irdy_cs <= 1'b0;
    end else if(pip_stall)begin
        read_irdy_cs <= read_irdy_cs;
    end else begin
        read_irdy_cs <= read_irdy_ns;
    end
end

always_comb begin
    if(conv_start_i) begin
        if(num_t_zero_frame == 8'b0) begin
            start_index_ns = reg_CROP_row_st + group_offset_ns;
        end else begin
            start_index_ns = 16'b0;
        end
    end else begin
        if(pip_stall) begin
            start_index_ns = start_index_cs;
        end else begin
            case (CS)
                RUNNING, RUNNING_4CHANNEL, RUNNING_ELE, RUNNING_BYPASS: begin
                    if(num_row_per_frame == 8 || num_row_per_frame == 10) begin
                        if((col_ns == 16'b0) && (ele_select_ns == 1'b0)) begin
                            if((num_t_zero_frame != 0 && curr_row_frame_ns < num_t_zero_frame) || (curr_row_frame_ns >= num_row_frame_padt_rowout)) begin
                                start_index_ns = 16'b0;
                            end else if(curr_row_frame_ns == num_t_zero_frame) begin
                                start_index_ns = reg_CROP_row_st + group_offset_ns;
                            end else if(curr_row_frame_ns == num_t_zero_frame + 1) begin
                                start_index_ns = start_index_cs + 8 - row_num_pad_t;
                            end else begin
                                start_index_ns = start_index_cs + 8;
                            end
                        end else begin
                            start_index_ns = start_index_cs;
                        end
                    end else begin //num_row_per_frame == 4
                        if((col_ns == 16'b0) && (upsample_hold_ns == 1'b0)) begin
                            if(frame_last) begin
                                start_index_ns = reg_CROP_row_st + group_offset_ns;
                            end else begin
                                start_index_ns = start_index_cs + 4;
                            end
                        end else begin
                            start_index_ns = start_index_cs;
                        end
                    end
                end
                default: begin
                    start_index_ns = start_index_cs;
                end
            endcase
        end
    end
end
always_ff @(negedge rst_n, posedge clk_i) begin
    if(!rst_n) begin
        start_index_cs <= 16'b0;
    end else begin
        start_index_cs <= start_index_ns;
    end
end
always_comb begin
    if(pip_stall) begin
        end_index_ns = end_index_cs;
    end else begin
        case (NS)
            RUNNING, RUNNING_4CHANNEL, RUNNING_ELE, RUNNING_BYPASS: begin
                if(num_row_per_frame == 10 || num_row_per_frame == 8) begin
                    if((col_ns == 16'b0) && (ele_select_ns == 1'b0)) begin
                        if((num_t_zero_frame != 0 && curr_row_frame_ns < num_t_zero_frame) || (curr_row_frame_ns >= num_row_frame_padt_rowout)) begin
                            end_index_ns = 16'b0;
                        end else if(curr_row_frame_ns == num_row_frame_padt_rowout-1) begin
                            end_index_ns = group_offset_ns + reg_CROP_row_st + reg_CROP_ROW_row_out - 1;
                        end else if(num_t_zero_frame != 0 && curr_row_frame_ns == num_t_zero_frame) begin
                            if(num_row_per_frame == 8) begin
                                end_index_ns = start_index_ns + (7 - pad_t_frame_row[2:0]);
                            end else begin // num_row_per_frame == 10
                                end_index_ns = start_index_ns + (7 - pad_t_frame_row_sub_2[2:0]);
                            end
                        end else begin
                            if(num_row_per_frame == 8) begin
                                end_index_ns = start_index_ns + 7;
                            end else begin // num_row_per_frame == 10
                                end_index_ns = start_index_ns + 9;
                            end
                        end
                    end else begin
                        end_index_ns = end_index_cs;
                    end
                end else begin //num_row_per_frame == 4
                    if((col_ns == 16'b0) && (ele_select_ns == 1'b0)) begin
                        if(curr_row_frame_ns == num_row_frame_padt_rowout-1) begin
                            end_index_ns = group_offset_ns + reg_CROP_row_st + reg_CROP_ROW_row_out - 1;
                        end else begin
                            end_index_ns = start_index_ns + 3;
                        end
                    end else begin
                        end_index_ns = end_index_cs;
                    end
                end
            end
            default: begin
                end_index_ns = end_index_cs;
            end
        endcase
    end
end
always_ff @(negedge rst_n, posedge clk_i) begin
    if(!rst_n) begin
        end_index_cs <= 16'b0;
    end else begin
        end_index_cs <= end_index_ns;
    end
end

//modified
assign st_idx_plus_in1_os_y = start_index_cs + in1_offset_y;
assign ed_idx_plus_in1_os_y = end_index_cs + in1_offset_y;
assign st_idx_plus_in2_os_y = start_index_cs + reg_MEM_IN2_offset_y;
assign ed_idx_plus_in2_os_y = end_index_cs + reg_MEM_IN2_offset_y;
//modified
always_comb begin
    if(ele_enable == 1'b0) begin
        mem_start_index[0] = st_idx_plus_in1_os_y[3:0];
        mem_end_index[0] = ed_idx_plus_in1_os_y[3:0];
        mem_start_index[1] = 4'b0;
        mem_end_index[1] = 4'b0;
    end else begin
        mem_start_index[0] = st_idx_plus_in1_os_y[3:0];
        mem_end_index[0] = ed_idx_plus_in1_os_y[3:0];
        mem_start_index[1] = st_idx_plus_in2_os_y[3:0];
        mem_end_index[1] = ed_idx_plus_in2_os_y[3:0];
    end
end
always_comb begin
    if(ele_enable == 1'b0) begin
        if(channel4_enable) begin
            mem_col_start_1[0] = st_idx_plus_in1_os_y[15:4] * group_col_div_8 + in1_offset_x;
            mem_col_start_2[0] = ed_idx_plus_in1_os_y[15:4] * group_col_div_8 + in1_offset_x;
            mem_col_start_1[1] = 16'b0;
            mem_col_start_2[1] = 16'b0;
        end else begin
            mem_col_start_1[0] = st_idx_plus_in1_os_y[15:4] * reg_FM_COL_col + in1_offset_x;
            mem_col_start_2[0] = ed_idx_plus_in1_os_y[15:4] * reg_FM_COL_col + in1_offset_x;
            mem_col_start_1[1] = 16'b0;
            mem_col_start_2[1] = 16'b0;
        end
    end else begin
        mem_col_start_1[0] = st_idx_plus_in1_os_y[15:4] * reg_FM_COL_col + in1_offset_x;
        mem_col_start_2[0] = ed_idx_plus_in1_os_y[15:4] * reg_FM_COL_col + in1_offset_x;
        mem_col_start_1[1] = st_idx_plus_in2_os_y[15:4] * reg_FM_COL_col + reg_MEM_IN2_offset_x;
        mem_col_start_2[1] = ed_idx_plus_in2_os_y[15:4] * reg_FM_COL_col + reg_MEM_IN2_offset_x;
    end
end

assign wrap_around[0] = mem_start_index[0] > mem_end_index[0];
assign wrap_around[1] = mem_start_index[1] > mem_end_index[1];
//ram interface

always_comb begin
    for(int i=0;i<2;i++) begin
        if(channel4_enable) begin
            read_addr_1[i] = mem_col_start_1[i] + col_in_matrix_cs[10:3];
            read_addr_2[i] = mem_col_start_2[i] + col_in_matrix_cs[10:3];
        end else begin
            read_addr_1[i] = mem_col_start_1[i] + col_in_matrix_cs[10:0];
            read_addr_2[i] = mem_col_start_2[i] + col_in_matrix_cs[10:0];
        end
    end
end
always_ff @(negedge rst_n, posedge clk_i) begin
    if(!rst_n) begin
        for(int unsigned i=0;i<16;i++) begin
            read_addr_o[i] <= 11'b0;
            read_cs_o[i] <= 1'b0;
        end
    end else begin
        for(int unsigned i=0;i<16;i++) begin
            if(pip_stall) begin
                read_addr_o[i] <= read_addr_o[i];
                read_cs_o[i] <= read_cs_o[i];
            end else if(read_enable_cs == 1'b1) begin
                if(ele_enable == 1'b1) begin //elementwise case
                    if(ele_select_cs == 1'b0) begin
                        if(wrap_around[0]) begin
                            if(i >= mem_start_index[0]) begin
                                read_addr_o[i] <= read_addr_1[0];
                                read_cs_o[i] <= 1'b1;
                            end else if(i <= mem_end_index[0]) begin
                                read_addr_o[i] <= read_addr_2[0];
                                read_cs_o[i] <= 1'b1;
                            end else begin
                                read_addr_o[i] <= read_addr_o[i];
                                read_cs_o[i] <= 1'b0;
                            end
                        end else begin
                            if((i >= mem_start_index[0]) && (i <= mem_end_index[0])) begin
                                read_addr_o[i] <= read_addr_1[0];
                                read_cs_o[i] <= 1'b1;
                            end else begin
                                read_addr_o[i] <= read_addr_o[i];
                                read_cs_o[i] <= 1'b0;
                            end
                        end
                    end else begin
                        if(wrap_around[1]) begin
                            if(i >= mem_start_index[1]) begin
                                read_addr_o[i] <= read_addr_1[1];
                                read_cs_o[i] <= 1'b1;
                            end else if(i <= mem_end_index[1]) begin
                                read_addr_o[i] <= read_addr_2[1];
                                read_cs_o[i] <= 1'b1;
                            end else begin
                                read_addr_o[i] <= read_addr_o[i];
                                read_cs_o[i] <= 1'b0;
                            end
                        end else begin
                            if((i >= mem_start_index[1]) && (i <= mem_end_index[1])) begin
                                read_addr_o[i] <= read_addr_1[1];
                                read_cs_o[i] <= 1'b1;
                            end else begin
                                read_addr_o[i] <= read_addr_o[i];
                                read_cs_o[i] <= 1'b0;
                            end
                        end
                    end
                end else begin
                    if(wrap_around[0]) begin
                        if(i >= mem_start_index[0]) begin
                            read_addr_o[i] <= read_addr_1[0];
                            read_cs_o[i] <= 1'b1;
                        end else if(i <= mem_end_index[0]) begin
                            read_addr_o[i] <= read_addr_2[0];
                            read_cs_o[i] <= 1'b1;
                        end else begin
                            read_addr_o[i] <= read_addr_o[i];
                            read_cs_o[i] <= 1'b0;
                        end
                    end else begin
                        if((i >= mem_start_index[0]) && (i <= mem_end_index[0])) begin
                            read_addr_o[i] <= read_addr_1[0];
                            read_cs_o[i] <= 1'b1;
                        end else begin
                            read_addr_o[i] <= read_addr_o[i];
                            read_cs_o[i] <= 1'b0;
                        end
                    end
                end
            end else begin
                read_addr_o[i] <= read_addr_o[i];
                read_cs_o[i] <= 1'b0;
            end
        end
    end
end
always_ff @(negedge rst_n, posedge clk_i) begin
    if(!rst_n) begin
        pip_stall_dly <= 3'b0;
    end else begin
        pip_stall_dly[0] <= pip_stall;
        pip_stall_dly[1] <= pip_stall_dly[0];
        pip_stall_dly[2] <= pip_stall_dly[1];
    end
end
always_ff @(negedge rst_n, posedge clk_i) begin
    if(!rst_n) begin
        read_data_reg_1 <= 2048'b0;
    end else begin
        for(int i=0;i<16;i++) begin
            for(int j=0;j<8;j++) begin
                for(int k=0;k<16;k++) begin
                    if(pip_stall_dly[0]) begin
                        read_data_reg_1[i][j][k] <= read_data_reg_1[i][j][k];
                    end else if(read_enable_d2 == 1'b1) begin
                        read_data_reg_1[i][j][k] <= read_data_out_i[i][16*j+k];
                    end else begin
                        read_data_reg_1[i][j][k] <= read_data_reg_1[i][j][k];
                    end
                end
            end
        end
    end
end
always_ff @(negedge rst_n, posedge clk_i) begin
    if(!rst_n) begin
        read_data_reg_2 <= 2048'b0;
    end else begin
        if(pip_stall_dly[0]) begin
            read_data_reg_2 <= read_data_reg_2;
        end else begin
            read_data_reg_2 <= read_data_reg_1;
        end
    end
end
always_comb begin
    if(pip_stall_dly[0]) begin
        read_data_out = read_data_reg_2;
    end else begin
        read_data_out = read_data_reg_1;
    end
end
//signal delay
always_ff @(negedge rst_n, posedge clk_i) begin
    if(!rst_n) begin
        read_enable_d1 <= 1'b0;
        read_enable_d2 <= 1'b0;
    end else begin
        if(pip_stall) begin
            read_enable_d1 <= read_enable_d1;
            read_enable_d2 <= read_enable_d2;
        end else begin
            read_enable_d1 <= read_enable_cs;
            read_enable_d2 <= read_enable_d1;
        end
    end
end
always_ff @(negedge rst_n, posedge clk_i) begin
    if(!rst_n) begin
        col_last_d1 <= 1'b0;
        col_last_d2 <= 1'b0;
        col_last_d3 <= 1'b0;
    end else begin
        if(pip_stall) begin
            col_last_d1 <= col_last_d1;
            col_last_d2 <= col_last_d2;
            col_last_d3 <= col_last_d3;
        end else begin
            col_last_d1 <= col_last;
            col_last_d2 <= col_last_d1;
            col_last_d3 <= col_last_d2;
        end
    end
end
always_ff @(negedge rst_n, posedge clk_i) begin
    if(!rst_n) begin
        frame_last_d1 <= 1'b0;
        frame_last_d2 <= 1'b0;
        frame_last_d3 <= 1'b0;
    end else begin
        if(pip_stall) begin
            frame_last_d1 <= frame_last_d1;
            frame_last_d2 <= frame_last_d2;
            frame_last_d3 <= frame_last_d3;
        end else begin
            frame_last_d1 <= frame_last;
            frame_last_d2 <= frame_last_d1;
            frame_last_d3 <= frame_last_d2;
        end
    end
end

always_ff @(negedge rst_n, posedge clk_i) begin
    if(!rst_n) begin
        mem_start_index_d1 <= 4'b0;
        mem_start_index_d2 <= 4'b0;
        mem_start_index_d3 <= 4'b0;
    end else begin
        if(pip_stall) begin
            mem_start_index_d1 <= mem_start_index_d1;
            mem_start_index_d2 <= mem_start_index_d2;
            mem_start_index_d3 <= mem_start_index_d3;
        end else begin
            mem_start_index_d1 <= (ele_select_cs == 1'b0) ? mem_start_index[0] : mem_start_index[1];
            mem_start_index_d2 <= mem_start_index_d1;
            mem_start_index_d3 <= mem_start_index_d2;
        end
    end
end
always_ff @(negedge rst_n, posedge clk_i) begin
    if(!rst_n) begin
        read_zero_d1 <= 1'b0;
        read_zero_d2 <= 1'b0;
        read_zero_d3 <= 1'b0;
    end else begin
        if(pip_stall) begin
            read_zero_d1 <= read_zero_d1;
            read_zero_d2 <= read_zero_d2;
            read_zero_d3 <= read_zero_d3;
        end else begin
            read_zero_d1 <= read_zero_cs;
            read_zero_d2 <= read_zero_d1;
            read_zero_d3 <= read_zero_d2;
        end
    end
end
always_ff @(negedge rst_n, posedge clk_i) begin
    if(!rst_n) begin
        row_frame_pad_t_d1 <= 1'b0;
        row_frame_pad_t_d2 <= 1'b0;
        row_frame_pad_t_d3 <= 1'b0;
        row_frame_pad_b_d1 <= 1'b0;
        row_frame_pad_b_d2 <= 1'b0;
        row_frame_pad_b_d3 <= 1'b0;
    end else begin
        if(pip_stall) begin
            row_frame_pad_t_d1 <= row_frame_pad_t_d1;
            row_frame_pad_t_d2 <= row_frame_pad_t_d2;
            row_frame_pad_t_d3 <= row_frame_pad_t_d3;
            row_frame_pad_b_d1 <= row_frame_pad_b_d1;
            row_frame_pad_b_d2 <= row_frame_pad_b_d2;
            row_frame_pad_b_d3 <= row_frame_pad_b_d3;
        end else begin
            row_frame_pad_t_d1 <= row_frame_pad_t;
            row_frame_pad_t_d2 <= row_frame_pad_t_d1;
            row_frame_pad_t_d3 <= row_frame_pad_t_d2;
            row_frame_pad_b_d1 <= row_frame_pad_b;
            row_frame_pad_b_d2 <= row_frame_pad_b_d1;
            row_frame_pad_b_d3 <= row_frame_pad_b_d2;
        end
    end
end
// logic   [7:0]   row_num_pad_t_d1, row_num_pad_t_d2, row_num_pad_t_d3;
// logic   [15:0]   row_num_not_pad_b_d1, row_num_not_pad_b_d2, row_num_not_pad_b_d3;
// logic   [15:0]   row_valid_num_d1, row_valid_num_d2, row_valid_num_d3;
always_ff @(negedge rst_n, posedge clk_i) begin
    if(!rst_n) begin
        row_num_pad_t_d1 <= 8'b0;
        row_num_pad_t_d2 <= 8'b0;
        row_num_pad_t_d3 <= 8'b0;
        row_num_not_pad_b_d1 <= 16'b0;
        row_num_not_pad_b_d2 <= 16'b0;
        row_num_not_pad_b_d3 <= 16'b0;
        row_valid_num_d1 <= 16'b0;
        row_valid_num_d2 <= 16'b0;
        row_valid_num_d3 <= 16'b0;
    end else begin
        if(pip_stall) begin
            row_num_pad_t_d1 <= row_num_pad_t_d1;
            row_num_pad_t_d2 <= row_num_pad_t_d2;
            row_num_pad_t_d3 <= row_num_pad_t_d3;
            row_num_not_pad_b_d1 <= row_num_not_pad_b_d1;
            row_num_not_pad_b_d2 <= row_num_not_pad_b_d2;
            row_num_not_pad_b_d3 <= row_num_not_pad_b_d3;
            row_valid_num_d1 <= row_valid_num_d1;
            row_valid_num_d2 <= row_valid_num_d2;
            row_valid_num_d3 <= row_valid_num_d3;
        end else begin
            row_num_pad_t_d1 <= row_num_pad_t;
            row_num_pad_t_d2 <= row_num_pad_t_d1;
            row_num_pad_t_d3 <= row_num_pad_t_d2;
            row_num_not_pad_b_d1 <= row_num_not_pad_b;
            row_num_not_pad_b_d2 <= row_num_not_pad_b_d1;
            row_num_not_pad_b_d3 <= row_num_not_pad_b_d2;
            row_valid_num_d1 <= row_valid_num;
            row_valid_num_d2 <= row_valid_num_d1;
            row_valid_num_d3 <= row_valid_num_d2;
        end
    end
end
always_ff @(negedge rst_n, posedge clk_i) begin
    if(!rst_n) begin
        count_4c_d1 <= 3'b0;
        count_4c_d2 <= 3'b0;
        count_4c_d3 <= 3'b0;
        count_4c_d4 <= 3'b0;
    end else begin
        if(pip_stall) begin
            count_4c_d1 <= count_4c_d1;
            count_4c_d2 <= count_4c_d2;
            count_4c_d3 <= count_4c_d3;
            count_4c_d4 <= count_4c_d4;
        end else begin
            count_4c_d1 <= col_in_matrix_ns[2:0];
            count_4c_d2 <= count_4c_d1;
            count_4c_d3 <= count_4c_d2;
            count_4c_d4 <= count_4c_d3;
        end
    end
end
always_ff @(negedge rst_n, posedge clk_i) begin
    if(!rst_n) begin
        read_valid_d1 <= 1'b0;
        read_valid_d2 <= 1'b0;
        read_valid_d3 <= 1'b0;
    end else begin
        if(pip_stall) begin
            read_valid_d1 <= read_valid_d1;
            read_valid_d2 <= read_valid_d2;
            read_valid_d3 <= read_valid_d3;
        end else begin
            read_valid_d1 <= read_valid_cs;
            read_valid_d2 <= read_valid_d1;
            read_valid_d3 <= read_valid_d2;
        end
    end
end
always_ff @(negedge rst_n, posedge clk_i) begin
    if(!rst_n) begin
        read_irdy_d1 <= 1'b0;
        read_irdy_d2 <= 1'b0;
        read_irdy_d3 <= 1'b0;
    end else begin
        if(pip_stall) begin
            read_irdy_d1 <= read_irdy_d1;
            read_irdy_d2 <= read_irdy_d2;
            read_irdy_d3 <= read_irdy_d3;
        end else begin
            read_irdy_d1 <= read_irdy_cs;
            read_irdy_d2 <= read_irdy_d1;
            read_irdy_d3 <= read_irdy_d2;
        end
    end
end
always_ff @(negedge rst_n, posedge clk_i) begin
    if(!rst_n) begin
        half_group_select_d1 <= 1'b0;
        half_group_select_d2 <= 1'b0;
        half_group_select_d3 <= 1'b0;
    end else begin
        if(pip_stall) begin
            half_group_select_d1 <= half_group_select_d1;
            half_group_select_d2 <= half_group_select_d2;
            half_group_select_d3 <= half_group_select_d3;
        end else if(dw_enable || ele_enable || bypass_enable) begin
            half_group_select_d1 <= half_group_select_cs;
            half_group_select_d2 <= half_group_select_d1;
            half_group_select_d3 <= half_group_select_d2;
        end else begin
            half_group_select_d1 <= 1'b0;
            half_group_select_d2 <= 1'b0;
            half_group_select_d3 <= 1'b0;
        end
    end
end
always_ff @(negedge rst_n, posedge clk_i) begin
    if(!rst_n) begin
        conv_start_dly <= 4'b0;
    end else begin
        conv_start_dly[0] <= conv_start_i;
        for(int i=1;i<5;i++) begin
            conv_start_dly[i] <= conv_start_dly[i-1];
        end
    end
end
always_ff @(negedge rst_n, posedge clk_i) begin
    if(!rst_n) begin
        group_last_dly <= 3'b0;
    end else begin
        if(pip_stall) begin
            group_last_dly <= group_last_dly;
        end else begin
            group_last_dly[0] <= group_last;
            for(int i=1;i<3;i++) begin
                group_last_dly[i] <= group_last_dly[i-1];
            end
        end
    end
end
//data path port
always_comb begin
    for(int i=0;i<10;i++) begin
        for(int j=0;j<8;j++) begin
            case (mem_start_index_d3)
                4'h0: begin read_data_out_barrel[i][j] = read_data_out[(i+0)%16][j]; end
                4'h1: begin read_data_out_barrel[i][j] = read_data_out[(i+1)%16][j]; end
                4'h2: begin read_data_out_barrel[i][j] = read_data_out[(i+2)%16][j]; end
                4'h3: begin read_data_out_barrel[i][j] = read_data_out[(i+3)%16][j]; end
                4'h4: begin read_data_out_barrel[i][j] = read_data_out[(i+4)%16][j]; end
                4'h5: begin read_data_out_barrel[i][j] = read_data_out[(i+5)%16][j]; end
                4'h6: begin read_data_out_barrel[i][j] = read_data_out[(i+6)%16][j]; end
                4'h7: begin read_data_out_barrel[i][j] = read_data_out[(i+7)%16][j]; end
                4'h8: begin read_data_out_barrel[i][j] = read_data_out[(i+8)%16][j]; end
                4'h9: begin read_data_out_barrel[i][j] = read_data_out[(i+9)%16][j]; end
                4'ha: begin read_data_out_barrel[i][j] = read_data_out[(i+10)%16][j]; end
                4'hb: begin read_data_out_barrel[i][j] = read_data_out[(i+11)%16][j]; end
                4'hc: begin read_data_out_barrel[i][j] = read_data_out[(i+12)%16][j]; end
                4'hd: begin read_data_out_barrel[i][j] = read_data_out[(i+13)%16][j]; end
                4'he: begin read_data_out_barrel[i][j] = read_data_out[(i+14)%16][j]; end
                4'hf: begin read_data_out_barrel[i][j] = read_data_out[(i+15)%16][j]; end
            endcase
        end
    end
end
always_comb begin
    for(int i=0;i<10;i++) begin
        for(int j=0;j<8;j++) begin
            if(channel4_enable) begin
                if(j < 1) begin
                    case (count_4c_d4)
                        3'h0: begin fm_out[i][j] = read_data_out_barrel[i][j]; end
                        3'h1: begin fm_out[i][j] = read_data_out_barrel[i][j+1]; end
                        3'h2: begin fm_out[i][j] = read_data_out_barrel[i][j+2]; end
                        3'h3: begin fm_out[i][j] = read_data_out_barrel[i][j+3]; end
                        3'h4: begin fm_out[i][j] = read_data_out_barrel[i][j+4]; end
                        3'h5: begin fm_out[i][j] = read_data_out_barrel[i][j+5]; end
                        3'h6: begin fm_out[i][j] = read_data_out_barrel[i][j+6]; end
                        3'h7: begin fm_out[i][j] = read_data_out_barrel[i][j+7]; end
                    endcase
                end else begin
                    fm_out[i][j] = 0;
                end
            end else if(dw_enable || ele_enable) begin
                if(half_group_select_d3 == 1'b1) begin
                    fm_out[i][j] = read_data_out_barrel[i][(j+4)%8];
                end else begin
                    fm_out[i][j] = read_data_out_barrel[i][j];
                end
            end else if(bypass_enable) begin
                if(reg_CONV_MODE_upsample) begin
                    if(half_group_select_d3 == 1'b1) begin
                        fm_out[i][j] = read_data_out_barrel[i/2][(j+4)%8];
                    end else begin
                        fm_out[i][j] = read_data_out_barrel[i/2][j];
                    end
                end else begin
                    if(half_group_select_d3 == 1'b1) begin
                        fm_out[i][j] = read_data_out_barrel[i][(j+4)%8];
                    end else begin
                        fm_out[i][j] = read_data_out_barrel[i][j];
                    end
                end
            end else begin
                fm_out[i][j] = read_data_out_barrel[i][j];
            end
        end
    end
end
logic [9:0][7:0][15:0] fm_out_barrel;
always_comb begin
    for(int unsigned i=0;i<10;i++) begin
        for(int unsigned j=0;j<8;j++) begin
            if(row_frame_pad_t_d3) begin
                case(row_num_pad_t_d3)
                    0: begin fm_out_barrel[i][j] = fm_out[(i+0)%10][j]; end
                    1: begin fm_out_barrel[i][j] = fm_out[(i+9)%10][j]; end
                    2: begin fm_out_barrel[i][j] = fm_out[(i+8)%10][j]; end
                    3: begin fm_out_barrel[i][j] = fm_out[(i+7)%10][j]; end
                    4: begin fm_out_barrel[i][j] = fm_out[(i+6)%10][j]; end
                    5: begin fm_out_barrel[i][j] = fm_out[(i+5)%10][j]; end
                    6: begin fm_out_barrel[i][j] = fm_out[(i+4)%10][j]; end
                    7: begin fm_out_barrel[i][j] = fm_out[(i+3)%10][j]; end
                    8: begin fm_out_barrel[i][j] = fm_out[(i+2)%10][j]; end
                    9: begin fm_out_barrel[i][j] = fm_out[(i+1)%10][j]; end
                    default: begin fm_out_barrel[i][j] = fm_out[i][j]; end
                endcase
            end else begin
                fm_out_barrel[i][j] = fm_out[i][j];
            end
        end
    end
end
always_ff @(negedge rst_n, posedge clk_i) begin
    if(!rst_n) begin
        for(int i=0;i<10;i++) begin
            for(int j=0;j<8;j++) begin
                fm_out_wire[i][j] <= 16'b0;
            end
        end
    end else begin
        for(int unsigned j=0;j<8;j++) begin
            if(pip_stall) begin
                for(int unsigned i=0;i<10;i++) begin
                    fm_out_wire[i][j] <= fm_out_wire[i][j];
                end
            end else if(read_valid_d3) begin
                if(read_zero_d3) begin
                    for(int unsigned i=0;i<10;i++) begin
                        fm_out_wire[i][j] <= 16'b0;
                    end
                end else begin
                    if((dw_enable || ele_enable || bypass_enable) && j >= 4) begin
                        for(int unsigned i=0;i<10;i++) begin
                            fm_out_wire[i][j] <= fm_out_wire[i][j];
                        end
                    end else begin
                        if(row_frame_pad_t_d3 == 1'b1 && row_frame_pad_b_d3 == 1'b1) begin
                            for(int unsigned i=0;i<10;i++) begin
                                if(fm_row_valid[i] == 1'b0) begin
                                    fm_out_wire[i][j] <= fm_out_wire[i][j];
                                end else begin
                                    if(i >= row_num_pad_t_d3 && i < row_num_not_pad_b_d3) begin
                                        fm_out_wire[i][j] <= fm_out_barrel[i][j];
                                    end else begin//i < row_num_pad_t_d3 or i >= row_num_not_pad_b_d3
                                        fm_out_wire[i][j] <= 16'b0;
                                    end
                                end
                            end
                        end else if(row_frame_pad_b_d3) begin
                            for(int unsigned i=0;i<10;i++) begin
                                if(fm_row_valid[i] == 1'b1) begin
                                    if(i < row_num_not_pad_b_d3) begin
                                        fm_out_wire[i][j] <= fm_out[i][j];
                                    end else begin
                                        fm_out_wire[i][j] <= 16'b0;
                                    end
                                end else begin
                                    fm_out_wire[i][j] <= fm_out_wire[i][j];
                                end
                            end
                        end else if(row_frame_pad_t_d3) begin
                            for(int unsigned i=0;i<10;i++) begin
                                if(fm_row_valid[i] == 1'b0) begin
                                    fm_out_wire[i][j] <= fm_out_wire[i][j];
                                end else begin
                                    if(i >= row_num_pad_t_d3) begin
                                        fm_out_wire[i][j] <= fm_out_barrel[i][j];
                                    end else begin//i < row_num_pad_t_d3
                                        fm_out_wire[i][j] <= 16'b0;
                                    end
                                end
                            end
                        end else begin
                            for(int unsigned i=0;i<10;i++) begin
                                fm_out_wire[i][j] <= fm_out[i][j];
                            end
                        end
                    end
                end
            end else begin
                for(int unsigned i=0;i<10;i++) begin
                    fm_out_wire[i][j] <= fm_out_wire[i][j];
                end
            end
        end
    end
end
always_comb begin
    for(int i=0;i<10;i++) begin
        for(int j=0;j<8;j++) begin
            fm_out_o[j][i] = fm_out_wire[i][j];
        end
    end
end 
always_comb begin
    if(read_valid_d3) begin
        if(num_row_per_frame == 10) begin
            for(int unsigned i=0;i<10;i++) begin
                if(frame_last_d3 == 1'b1) begin
                    if(i < row_valid_num_d3) begin
                        fm_row_valid[i] = 1'b1;
                    end else begin
                        fm_row_valid[i] = 1'b0;
                    end
                end else begin
                    fm_row_valid[i] = 1'b1;
                end
            end
        end else begin //num_row_per_frame == 8 or upsample
            for(int i=8;i<10;i++) begin
                fm_row_valid[i] = 1'b0;
            end
            for(int unsigned i=0;i<8;i++) begin
                if(frame_last_d3 == 1'b1) begin
                    if(i < row_valid_num_d3) begin
                        fm_row_valid[i] = 1'b1;
                    end else begin
                        fm_row_valid[i] = 1'b0;
                    end
                end else begin
                    fm_row_valid[i] = 1'b1;
                end
            end
        end
    end else begin
        for(int i=0;i<10;i++) begin
            fm_row_valid[i] = 1'b0;
        end
    end
end

always_ff @(negedge rst_n, posedge clk_i) begin
    if(!rst_n) begin
        for(int i=0;i<10;i++) begin
            fm_out_row_valid_o[i] <= 1'b0;
        end
    end else begin
        for(int i=0;i<10;i++) begin
            if(pip_stall) begin
                fm_out_row_valid_o[i] <= fm_out_row_valid_o[i];
            end else begin
                fm_out_row_valid_o[i] <= fm_row_valid[i];
            end
        end
    end
end
always_ff @(negedge rst_n, posedge clk_i) begin
    if(!rst_n) begin
        for(int i=0;i<8;i++) begin
            fm_out_ch_valid_o[i] <= 1'b0;
        end
    end else begin
        if(pip_stall) begin
            fm_out_ch_valid_o <= fm_out_ch_valid_o;
        end else if(read_valid_d3) begin
            if(channel4_enable) begin
                for(int i=0;i<1;i++) begin
                    fm_out_ch_valid_o[i] <= 1'b1;
                end
                for(int i=1;i<8;i++) begin
                    fm_out_ch_valid_o[i] <= 1'b0;
                end
            end else if(dw_enable || ele_enable || bypass_enable) begin
                for(int unsigned i=0;i<4;i++) begin
                    fm_out_ch_valid_o[i] <= 1'b1;
                end
                for(int i=4;i<8;i++) begin
                    fm_out_ch_valid_o[i] <= 1'b0;
                end
            end else begin
                for(int unsigned i=0;i<8;i++) begin
                    fm_out_ch_valid_o[i] <= 1'b1;
                end
            end
        end else begin
            for(int i=0;i<8;i++) begin
                fm_out_ch_valid_o[i] <= 1'b0;
            end
        end
    end
end

always_ff @(negedge rst_n, posedge clk_i) begin
    if(!rst_n) begin
        fm_out_irdy_o <= 1'b0;
    end else begin
        if(pip_stall) begin
            fm_out_irdy_o <= fm_out_irdy_o;
        end else begin
            fm_out_irdy_o <= read_irdy_d3;
        end
    end
end
always_ff @(negedge rst_n, posedge clk_i) begin
    if(!rst_n) begin
        fm_out_last_o <= 1'b0;
    end else begin
        if(pip_stall) begin
            fm_out_last_o <= fm_out_last_o;
        end else begin
            fm_out_last_o <= col_last_d3;
        end
    end
end
endmodule
