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

module mem_dc_4096x8to32r
(
    // Z80 side (4096 x 8-bit)
    input          clock_a,
    input          rden_a,
    input          wren_a,
    input   [11:0] address_a,
    input    [7:0] data_a,
    output   [7:0] q_a,
    // GPU side (1024 x 32-bit)
    input          clock_b,
    input          rden_b,
    input          wren_b,
    input    [9:0] address_b,
    input   [31:0] data_b,
    output  [31:0] q_b
);
    parameter [255:0] INIT_FILE = "NONE";
    
    // ========================================================
    /* verilator lint_off MULTIDRIVEN */
    
    // Registered output A
    reg  [7:0] r_q_a_p0;
    reg  [7:0] r_q_a_p1;

    // Registered output B
    reg [31:0] r_q_b_p0;
    reg [31:0] r_q_b_p1;
    
    // 1 x 4096 x 8 bit memory blocks
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
    
    // Port A write
    always @(posedge clock_a) begin : WR_PORT_A
        if (wren_a) begin
            r_mem_blk[address_a] <= data_a;
        end
    end
    
    // Port A read
    always @(posedge clock_a) begin : RD_PORT_A
        if (rden_a) begin
            r_q_a_p0 <= r_mem_blk[address_a];
        end
        r_q_a_p1 <= r_q_a_p0;
    end
    
    assign q_a = r_q_a_p1;
    
    // ========================================================
    
    // Port B write
    always @(posedge clock_b) begin : WR_PORT_B
        if (wren_b) begin
            r_mem_blk[{ address_b, 2'd0 }] <= data_b[ 7: 0];
            r_mem_blk[{ address_b, 2'd1 }] <= data_b[15: 8];
            r_mem_blk[{ address_b, 2'd2 }] <= data_b[23:16];
            r_mem_blk[{ address_b, 2'd3 }] <= data_b[31:24];
        end
    end
    
    // Port B read
    always @(posedge clock_b) begin : RD_PORT_B
        if (rden_b) begin
            r_q_b_p0[ 7: 0] <= r_mem_blk[{ address_b, 2'd0 }];
            r_q_b_p0[15: 8] <= r_mem_blk[{ address_b, 2'd1 }];
            r_q_b_p0[23:16] <= r_mem_blk[{ address_b, 2'd2 }];
            r_q_b_p0[31:24] <= r_mem_blk[{ address_b, 2'd3 }];
        end
        r_q_b_p1 <= r_q_b_p0;
    end
    
    assign q_b = r_q_b_p1;
    
    /* verilator lint_on MULTIDRIVEN */
    // ========================================================
    
endmodule
