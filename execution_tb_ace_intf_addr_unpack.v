//-----------------------------------------------------------------------------
// The confidential and proprietary information contained in this file may
// only be used by a person authorised under and to the extent permitted
// by a subsisting licensing agreement from ARM Limited.
//
//            (C) COPYRIGHT 2013-2014 ARM Limited.
//                ALL RIGHTS RESERVED
//
// This entire notice must be reproduced on all copies of this file
// and copies of this file may only be made by a person if such person is
// permitted to do so under the terms of a subsisting license agreement
// from ARM Limited.
//
//      SVN Information
//
//      Checked In          : $Date: 2014-07-02 16:52:21 +0100 (Wed, 02 Jul 2014) $
//
//      Revision            : $Revision: 283836 $
//
//      Release Information : CORTEXA53-r0p4-00rel0
//
//-----------------------------------------------------------------------------
// Description:
//
//   Converts a burst-based ACE address into a sequence of individual addresses
//   with valid/ready signalling for each address.
//------------------------------------------------------------------------------

module execution_tb_ace_intf_addr_unpack #(parameter integer ADDR_WIDTH = 32)
(
  // Clocks and resets
  input  wire                    clk,
  input  wire                    reset_n,

  // ACE interface
  input  wire [(ADDR_WIDTH-1):0] ace_axaddr_i,
  input  wire [2:0]              ace_axsize_i,
  input  wire [1:0]              ace_axburst_i,
  input  wire [7:0]              ace_axlen_i,
  input  wire [2:0]              ace_axprot_i,
  input  wire                    ace_axvalid_i,
  output wire                    ace_axready_o,

  // output ace_axlen
  output wire [7:0]              len_addr_count,

  // Unpacked address interface
  output wire [(ADDR_WIDTH-1):0] unpk_addr_o,     // Incrementing address
  output wire                    unpk_last_o,     // Last address in burst
  output wire                    unpk_valid_o,    // Address valid
  input  wire                    unpk_ready_i     // Address accepted
);


  //----------------------------------------------------------------------------
  // Signal declarations
  //----------------------------------------------------------------------------

  // Unpacked interface signals
  reg                       unpk_valid;
  reg  [11:0]               unpk_addr;         // Incrementing address (lower 12 bits)
  reg                       unpk_last;
  wire                      nxt_unpk_valid;
  wire [11:0]               nxt_unpk_addr;
  wire                      nxt_unpk_last;
  wire                      unpk_addr_we;

  // ACE signals
  wire                      ace_axready;
  wire                      new_ace_addr;      // New ACE address is available
  reg  [(ADDR_WIDTH-1):12]  ace_axaddr_reg;    // Registered input ACE address (upper bits)
  reg  [2:0]                ace_axsize_reg;    // Registered input ACE size
  reg  [1:0]                ace_axburst_reg;   // Registered input ACE burst type
  reg  [7:0]                ace_axlen_reg;     // Registered input ACE burst length

  // Incrementer
  wire [11:0]               unpk_addr_incr;    // Incremented address
  reg  [7:0]                addr_count;        // Burst counter
  wire [7:0]                nxt_addr_count;
  wire                      addr_count_we;


  //----------------------------------------------------------------------------
  // Combinatorial address incrementer
  //----------------------------------------------------------------------------

  // Note that as a burst cannot cross 4KB boundary, the incrementer only
  // operates on the lease significant 12 bits of the address
  execution_tb_ace_sky_addr_inc
    u_execution_tb_ace_sky_addr_inc
      (// Inputs
       .unpk_addr_i      (unpk_addr),
       .burst_len_i      (ace_axlen_reg),
       .burst_size_i     (ace_axsize_reg),
       .burst_type_i     (ace_axburst_reg),
       // Outputs
       .unpk_addr_incr_o (unpk_addr_incr)
      );


  //----------------------------------------------------------------------------
  // Control signal registers
  //----------------------------------------------------------------------------

  // Enable for address registers.  This signal indicates that there is a new
  // address on the ACE input interface
  assign new_ace_addr = ace_axvalid_i & ace_axready;

  // Address registers
  always @ (posedge clk or negedge reset_n)
    if (!reset_n) begin
      ace_axaddr_reg    <= {(ADDR_WIDTH-12){1'b0}};
      ace_axsize_reg    <= 3'b000;
      ace_axburst_reg   <= 2'b00;
      ace_axlen_reg     <= 8'h00;
    end else if (new_ace_addr) begin
      ace_axaddr_reg    <= ace_axaddr_i[(ADDR_WIDTH-1):12];
      ace_axsize_reg    <= ace_axsize_i;
      ace_axburst_reg   <= ace_axburst_i;
      ace_axlen_reg     <= ace_axlen_i;
    end


  //----------------------------------------------------------------------------
  // Incremented address
  //----------------------------------------------------------------------------

  // Next address is either from the ACE interface on the first transfer or
  // the address from the incrementer on subsequent transfers.
  assign nxt_unpk_addr = new_ace_addr ? ace_axaddr_i[11:0] : unpk_addr_incr;
  assign unpk_addr_we  = new_ace_addr | unpk_ready_i;

  // Address register
  always @ (posedge clk or negedge reset_n)
    if (!reset_n)
      unpk_addr <= {12{1'b0}};
    else if (unpk_addr_we)
      unpk_addr <= nxt_unpk_addr;


  //----------------------------------------------------------------------------
  // Address counter
  //
  //   Determines how many addresses there are in the burst, and indicates when
  //   the final address of the burst is issued.
  //----------------------------------------------------------------------------

  // The count increments when a new burst is started, or when an incrementing
  // address is accepted
  assign nxt_addr_count = new_ace_addr ? ace_axlen_i : (addr_count - 8'h01);
  assign nxt_unpk_last  = (nxt_addr_count == 8'h00);
  assign addr_count_we  = new_ace_addr | (unpk_valid & unpk_ready_i);
  // assign len_addr_count = addr_count;  // for preproc=2, dma continous write

  always @ (posedge clk or negedge reset_n)
    if (!reset_n) begin
      addr_count <= 8'h00;
      unpk_last  <= 1'b0;
    end else if (addr_count_we) begin
      addr_count <= nxt_addr_count;
      unpk_last  <= nxt_unpk_last;
    end


  //----------------------------------------------------------------------------
  // Address valid indicator
  //----------------------------------------------------------------------------

  // unpk_valid is high when an address is accepted and goes low when the last
  // address is accepted, unless another burst is started.
  always @ (posedge clk or negedge reset_n)
    if (!reset_n)
      unpk_valid <= 1'b0;
    else
      unpk_valid <= nxt_unpk_valid;

  assign nxt_unpk_valid = new_ace_addr | (unpk_valid & ~(unpk_last & unpk_ready_i));


  //----------------------------------------------------------------------------
  // READY logic
  //----------------------------------------------------------------------------

  // A new ACE address can be accepted when no valid address is stored
  assign ace_axready = ~unpk_valid;


  //----------------------------------------------------------------------------
  // Output assignments
  //----------------------------------------------------------------------------

  // Unpacked interface
  assign unpk_addr_o    = {ace_axaddr_reg, unpk_addr};
  assign unpk_last_o    = unpk_last;
  assign unpk_valid_o   = unpk_valid;

  // ACE signals
  assign ace_axready_o  = ace_axready;

endmodule

