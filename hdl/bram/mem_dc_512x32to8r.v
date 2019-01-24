// Copyright 2008-2019 Frederic Requin
//
// This file is part of the 1943 FPGA core
//
// The 1943 FPGA core is free software; you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation; either version 3 of the License, or
// (at your option) any later version.
//
// The 1943 FPGA core is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU General Public License for more details.
//
// You should have received a copy of the GNU General Public License
// along with this program.  If not, see <http://www.gnu.org/licenses/>.

module mem_dc_512x32to8r
(
    // Write port
    input         wrclock,
    input         wren,
    input   [8:0] wraddress,
    input  [31:0] data,
    // Read port
    input         rdclock,
    input         rden,
    input  [10:0] rdaddress,
    output  [7:0] q
);
    // ========================================================
    
    // Registered output
    reg  [7:0] r_q_p0;
    reg  [7:0] r_q_p1;

    // 4 x 512 x 8 bit memory blocks
    reg  [7:0] r_mem_blk_0 [0:511];
    reg  [7:0] r_mem_blk_1 [0:511];
    reg  [7:0] r_mem_blk_2 [0:511];
    reg  [7:0] r_mem_blk_3 [0:511];
    
    integer i;

    // ========================================================
    
    initial
    begin
        for (i = 0; i < 512; i = i + 1) begin
            r_mem_blk_0[i] = 8'hFF;
            r_mem_blk_1[i] = 8'hFF;
            r_mem_blk_2[i] = 8'hFF;
            r_mem_blk_3[i] = 8'hFF;
        end
    end
    
    // ========================================================
    
    // Write port
    always @(posedge wrclock) begin : WR_PORT
    
        if (wren) begin
            r_mem_blk_0[wraddress] <= data[ 7: 0];
            r_mem_blk_1[wraddress] <= data[15: 8];
            r_mem_blk_2[wraddress] <= data[23:16];
            r_mem_blk_3[wraddress] <= data[31:24];
        end
    end

    // Read port
    always @(posedge rdclock) begin : RD_PORT
        
        if (rden) begin
            case (rdaddress[1:0])
                2'd0 : r_q_p0 <= r_mem_blk_0[rdaddress[10:2]];
                2'd1 : r_q_p0 <= r_mem_blk_1[rdaddress[10:2]];
                2'd2 : r_q_p0 <= r_mem_blk_2[rdaddress[10:2]];
                2'd3 : r_q_p0 <= r_mem_blk_3[rdaddress[10:2]];
            endcase
        end
        r_q_p1 <= r_q_p0;
    end
    
    assign q = r_q_p1;

    // ========================================================
    
endmodule
