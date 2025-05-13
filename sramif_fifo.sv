module sramif_fifo #(
    parameter WIDTH =   128,  // FIFO entry width
    parameter DEPTH =   8   // FIFO depth
) (
    input               clk      ,
    input               rst_n    ,
    input               flush    ,
    input               write    ,
    input [WIDTH-1:0]   data_in  ,
    input               read     ,
    output [WIDTH-1:0]  data_out ,
    output              full     ,
    output              almost_empty ,
    output              empty_b1 ,
    output              empty    
);

localparam ADDR_W = $clog2(DEPTH);

logic [WIDTH-1:0] mem [DEPTH-1:0];
logic [ADDR_W:0] w_ptr, r_ptr;

always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        w_ptr <= {(ADDR_W+1){1'b0}};
        r_ptr <= {(ADDR_W+1){1'b0}};
    end else begin
        w_ptr <= flush ? {(ADDR_W+1){1'b0}} : write ? w_ptr + {{ADDR_W{1'b0}}, 1'b1} : w_ptr;
        r_ptr <= flush ? {(ADDR_W+1){1'b0}} : read ? r_ptr + {{ADDR_W{1'b0}}, 1'b1} : r_ptr;
    end
end

assign empty = w_ptr[ADDR_W:0] == r_ptr[ADDR_W:0];
assign full = (w_ptr[ADDR_W] != r_ptr[ADDR_W]) && (w_ptr[ADDR_W-1:0] == r_ptr[ADDR_W-1:0]);

assign empty_b1 = ((w_ptr[ADDR_W:0] == (r_ptr[ADDR_W:0] + {{ADDR_W{1'b0}}, 1'b1})) & (~write & read)) | (empty & ~write);
assign almost_empty = w_ptr[ADDR_W:0] == (r_ptr[ADDR_W:0] + {{ADDR_W{1'b0}}, 1'b1});

genvar i;
generate
for (i = 0; i < DEPTH; i = i + 1) begin
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            mem[i] <= {WIDTH{1'b0}};
        end else begin
            mem[i] <= (write && w_ptr[ADDR_W-1:0] == i[ADDR_W-1:0]) ? data_in : mem[i];
        end
    end
end
endgenerate

assign data_out = mem[r_ptr[ADDR_W-1:0]];

endmodule
