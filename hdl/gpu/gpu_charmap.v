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

module gpu_charmap
(
    // Clock and reset
    input         rst,          // Global reset
    input         clk,          // Master clock (72 MHz)
    // 32 x 32 characters screen (Z80 access)
    input         reg_rd,       // Screen read strobe
    input         reg_wr,       // Screen write strobe
    input  [10:0] reg_addr,     // Screen address (2 KB range)
    input   [7:0] reg_wdata,    // Screen write data
    output  [7:0] reg_rdata,    // Screen read data
    // Signals from video beam generator
    input         bus_dma_ena,  // Bus video DMA enable
    input   [8:0] bus_vpos,     // Bus vertical position
    input         bus_eol,      // Bus end of line
    // Signals from SDRAM controller
    input   [3:0] ram_cyc,      // SDRAM cycles
    input   [3:0] ram_ph,       // SDRAM phases
    input   [8:0] ram_ph_ctr,   // SDRAM phase counter
    // Sprites DMAs
    input         chr_dma_ena,  // Char DMA enable
    output [15:2] chr_dma_addr, // Max : 64 KB (2048 chars of 8 x 8 x 4 bits)
    output        chr_dma_rden, // DMA read enable
    input         chr_data_vld, // Sprite data valid
    input  [15:0] chr_data,     // Sprite data
    // Video FIFOs access
    input   [1:0] vid_line,     // Video line number
    input         vid_read,     // Video data read
    input         vid_next,     // Next video data
    output  [7:0] vid_data,     // Video data
    output        vid_vld       // Video data valid
);

    // =============================================
    // Characters registers
    // =============================================
    
    wire  [9:0] w_chr_regs_addr_p0;
    wire [15:0] w_chr_regs_q_p2;
    
    wire [10:0] w_chr_idx;
    wire  [3:0] w_chr_pal_idx;
    
    assign w_chr_regs_addr_p0 = { ram_ph_ctr[5:1], ~bus_vpos[7:3] };
    
    mem_dc_2048x8to16r U_chr_regs
    (
        // Z80 side
        .clock_a   (clk),
        .rden_a    (reg_rd),
        .wren_a    (reg_wr),
        .address_a ({ reg_addr[9:0], reg_addr[10] }),
        .data_a    (reg_wdata),
        .q_a       (reg_rdata),
        // GPU side
        .clock_b   (clk),
        .rden_b    (1'b1),
        .wren_b    (1'b0),
        .address_b (w_chr_regs_addr_p0),
        .data_b    (16'h0000),
        .q_b       (w_chr_regs_q_p2)
    );
    
    assign w_chr_idx     = { w_chr_regs_q_p2[15:13], w_chr_regs_q_p2[7:0] };
    assign w_chr_pal_idx =   w_chr_regs_q_p2[11:8];
    
    // =============================================
    // Characters addresses
    // =============================================
    
    reg [15:2] r_chr_addr;
    reg        r_chr_rden;
    
    always @(posedge rst or posedge clk) begin : CHR_ADDR
        
        if (rst) begin
            r_chr_addr  <= 14'd0;
            r_chr_rden  <= 1'b0;
        end
        else begin
            if (chr_dma_ena) begin
                // Character index (0 - 2047)
                r_chr_addr[15:5] <= w_chr_idx;
                // Character line number (0 - 7)
                r_chr_addr[4:2]  <= bus_vpos[2:0];
            end
            // Character read enable
            if (ram_cyc[2] & ram_ph[2]) begin
                r_chr_rden <= chr_dma_ena & bus_dma_ena;
            end
        end
    end
    
    assign chr_dma_addr = r_chr_addr;
    assign chr_dma_rden = r_chr_rden;
    
    // ===========================================
    // Characters FIFO write control
    // ===========================================

    reg         r_fifo_gfx_we;
    reg  [15:0] r_fifo_gfx_data;
    reg   [7:0] r_fifo_gfx_waddr;
    wire [31:0] w_fifo_gfx_data;
    
    always @(posedge rst or posedge clk) begin : FIFO_WR_CTL
        reg [6:0] v_addr;
        reg [1:0] v_line;
        
        if (rst) begin
            r_fifo_gfx_we    <= 1'b0;
            r_fifo_gfx_data  <= 16'h0000;
            r_fifo_gfx_waddr <= 8'd0;
            v_line           <= 2'd0;
            v_addr           <= 7'd0;
        end
        else begin
            // FIFO write enable
            r_fifo_gfx_we <= chr_data_vld & ~(v_addr[1] ^ bus_vpos[0]);
            // FIFO data
            r_fifo_gfx_data[15:12] <= chr_data[15:12];
            r_fifo_gfx_data[11: 8] <= chr_data[11: 8];
            r_fifo_gfx_data[ 7: 4] <= chr_data[ 7: 4];
            r_fifo_gfx_data[ 3: 0] <= chr_data[ 3: 0];
            // FIFO address
            r_fifo_gfx_waddr <= { v_line, v_addr[6:2], v_addr[0] };
            // FIFO line counter (0 - 3)
            if (bus_dma_ena) begin
                if (bus_eol) v_line <= v_line + 2'd1;
            end
            else begin
                v_line <= 2'd0;
            end
            // FIFO line address (0 - 127)
            if (chr_data_vld) begin
                v_addr <= v_addr + 7'd1;
            end
        end
    end
    
    assign w_fifo_gfx_data[31:24] = { w_chr_pal_idx, r_fifo_gfx_data[15:12] };
    assign w_fifo_gfx_data[23:16] = { w_chr_pal_idx, r_fifo_gfx_data[11: 8] };
    assign w_fifo_gfx_data[15: 8] = { w_chr_pal_idx, r_fifo_gfx_data[ 7: 4] };
    assign w_fifo_gfx_data[ 7: 0] = { w_chr_pal_idx, r_fifo_gfx_data[ 3: 0] };
    
    // ===========================================
    // Characters FIFO (4 lines of 256 pixels)
    // ===========================================
    
    mem_dc_256x32to8r U_line_fifo
    (
        // Write port
        .wrclock   (clk),
        .wren      (r_fifo_gfx_we),
        .wraddress (r_fifo_gfx_waddr),
        .byteena_a (4'b1111),
        .data      (w_fifo_gfx_data),
        // Read port
        .rdclock   (clk),
        .rden      (1'b1),
        .rdaddress ({ vid_line, r_fifo_gfx_raddr_p0 }),
        .q         (w_fifo_gfx_q_p2)
    );
    
    // ===========================================
    // Characters FIFO read control
    // ===========================================
    
    reg  [7:0] r_fifo_gfx_raddr_p0;
    reg  [1:0] r_fifo_gfx_q_vld_p2;
    wire [7:0] w_fifo_gfx_q_p2;
    
    always @(posedge rst or posedge clk) begin : FIFO_RD_CTL
    
        if (rst) begin
            r_fifo_gfx_raddr_p0 <= 8'd16;
            r_fifo_gfx_q_vld_p2 <= 2'b00;
        end
        else begin
            if (bus_eol) begin
                r_fifo_gfx_raddr_p0 <= 8'd16;
            end
            else if (vid_next) begin
                r_fifo_gfx_raddr_p0 <= r_fifo_gfx_raddr_p0 + 8'd1;
            end
            r_fifo_gfx_q_vld_p2 <= { r_fifo_gfx_q_vld_p2[0], vid_read };
        end
    end
    
    assign vid_data = w_fifo_gfx_q_p2;
    assign vid_vld  = r_fifo_gfx_q_vld_p2[1];
    
endmodule
