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
//  Combinatorial address incrementer for ACE and Skyros subsystems.  The
//  address only increments over 4kB, so bits 12 and greater won't change.
//
//  Note that this logic calcultes the NEXT address in the burst, not the
//  current address.
//------------------------------------------------------------------------------

module execution_tb_ace_sky_addr_inc
(
  // Un-incremented and incremented address
  input  wire [11:0] unpk_addr_i,      // Current address
  output wire [11:0] unpk_addr_incr_o, // Next address

  // Axi burst information
  input  wire  [7:0] burst_len_i,      // Burst length
  input  wire  [2:0] burst_size_i,     // Burst size
  input  wire  [1:0] burst_type_i      // Burst type
);


  //----------------------------------------------------------------------------
  // Local constants
  //----------------------------------------------------------------------------

  // Burst type encodings. These are compatible with the ACE burst types.
  localparam [1:0] BURST_FIXED = 2'b00;
  localparam [1:0] BURST_WRAP  = 2'b10;


  //----------------------------------------------------------------------------
  // Signal declarations
  //----------------------------------------------------------------------------

  wire [11:0] offset_addr;    // Shifted address
  wire [11:0] incr_addr;      // Incremented address
  wire [11:0] wrap_addr;      // Wrapped address
  wire [11:0] mux_addr;       // Address selected by burst type
  wire [11:0] unpk_addr_incr; // Output address


  //----------------------------------------------------------------------------
  // Combinational address shift right
  //
  //  Extract the significant bits of interest, depending on the transaction
  //  size.
  //----------------------------------------------------------------------------

  assign offset_addr = unpk_addr_i >> burst_size_i;

  // Increment the address
  assign incr_addr = offset_addr + 12'h001;


  //----------------------------------------------------------------------------
  // Address wrapping
  //
  //  The address of the next transfer should wrap if the boundary is reached.
  //
  //  Note that for wrapping bursts the start address is aligned to burst_size_i
  //  and the length of the burst must be 2, 4, 8, or 16
  //  (burst_len_i = 1, 3, 7, 15).
  //----------------------------------------------------------------------------

  // Upper bits of wrapped address remain static
  assign wrap_addr[11:4] = offset_addr[11:4];

  // Wrap lower bits according to length of burst
  assign wrap_addr[3:0]  = ( burst_len_i[3:0] &   incr_addr[3:0]) |
                           (~burst_len_i[3:0] & offset_addr[3:0]);


  //---------------------------------------------------------------------------
  // Combinational address multiplexer
  //
  //  Choose the final offset address depending on burst type
  //---------------------------------------------------------------------------

  assign mux_addr = (burst_type_i == BURST_WRAP) ? wrap_addr : incr_addr;


  //---------------------------------------------------------------------------
  //  Combinational address shift left
  //
  //  Shift the bits of interest to the correct bits of the resultant address
  //---------------------------------------------------------------------------

  assign unpk_addr_incr = (burst_type_i == BURST_FIXED) ? unpk_addr_i : (mux_addr << burst_size_i);


  //----------------------------------------------------------------------------
  // Output assignments
  //----------------------------------------------------------------------------

  assign unpk_addr_incr_o = unpk_addr_incr;

endmodule

