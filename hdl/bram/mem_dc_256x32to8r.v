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

module mem_dc_256x32to8r
(
    // Write port
    input         wrclock,
    input         wren,
    input   [7:0] wraddress,
    input   [3:0] byteena_a,
    input  [31:0] data,
    // Read port
    input         rdclock,
    input         rden,
    input   [9:0] rdaddress,
    output  [7:0] q
);
    // ========================================================
    
    // Registered output
    reg  [7:0] r_q_p0;
    reg  [7:0] r_q_p1;

    // 4 x 256 x 8 bit memory blocks
    reg  [7:0] r_mem_blk_0 [0:255];
    reg  [7:0] r_mem_blk_1 [0:255];
    reg  [7:0] r_mem_blk_2 [0:255];
    reg  [7:0] r_mem_blk_3 [0:255];
    
    integer i;

    // ========================================================
    
    initial
    begin
        for (i = 0; i < 256; i = i + 1) begin
            r_mem_blk_0[i] = 8'h00;
            r_mem_blk_1[i] = 8'h00;
            r_mem_blk_2[i] = 8'h00;
            r_mem_blk_3[i] = 8'h00;
        end
    end
    
    // ========================================================
    
    // Write port
    always @(posedge wrclock) begin : WR_PORT
    
        if (wren) begin
            if (byteena_a[0]) r_mem_blk_0[wraddress] <= data[ 7: 0];
            if (byteena_a[1]) r_mem_blk_1[wraddress] <= data[15: 8];
            if (byteena_a[2]) r_mem_blk_2[wraddress] <= data[23:16];
            if (byteena_a[3]) r_mem_blk_3[wraddress] <= data[31:24];
        end
    end

    // ========================================================
    
    // Read port
    always @(posedge rdclock) begin : RD_PORT
        
        if (rden) begin
            case (rdaddress[1:0])
                2'd0 : r_q_p0 <= r_mem_blk_0[rdaddress[9:2]];
                2'd1 : r_q_p0 <= r_mem_blk_1[rdaddress[9:2]];
                2'd2 : r_q_p0 <= r_mem_blk_2[rdaddress[9:2]];
                2'd3 : r_q_p0 <= r_mem_blk_3[rdaddress[9:2]];
            endcase
        end
        r_q_p1 <= r_q_p0;
    end
    
    assign q = r_q_p1;

    // ========================================================
    
endmodule
