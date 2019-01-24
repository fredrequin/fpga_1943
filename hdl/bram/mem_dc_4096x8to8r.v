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

module mem_dc_4096x8to8r
(
    // Write port (4096 x 8-bit)
    input          wrclock,
    input          wren,
    input   [11:0] wraddress,
    input    [7:0] data,
    // Read port (4096 x 8-bit)
    input          rdclock,
    input          rden,
    input   [11:0] rdaddress,
    output   [7:0] q
);
    parameter [255:0] INIT_FILE = "NONE";
    
    // ========================================================

    // Registered output B
    reg  [7:0] r_q_p0;
    reg  [7:0] r_q_p1;
    
    // 1 x 4096 x 8 bit memory block
    reg  [7:0] r_mem_blk [0:4095];
    
    integer i;

    // ========================================================
    
    initial
    begin
        if (INIT_FILE == "NONE") begin
            for (i = 0; i < 4096; i = i + 1) begin
                r_mem_blk[i] = 8'h00;
            end
        end
        else begin
            $readmemh(INIT_FILE, r_mem_blk);
        end
    end
    
    // ========================================================
    
    // Write port
    always @(posedge wrclock) begin : WR_PORT
        if (wren) begin
            r_mem_blk[wraddress] <= data;
        end
    end
    
    // ========================================================
    
    // Read port
    always @(posedge rdclock) begin : RD_PORT
        if (rden) begin
            r_q_p0 <= r_mem_blk[rdaddress];
        end
        r_q_p1 <= r_q_p0;
    end
    
    assign q = r_q_p1;
    
    // ========================================================
    
endmodule
