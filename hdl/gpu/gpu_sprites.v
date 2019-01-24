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

module gpu_sprites
(
    // Clock and reset
    input         rst,          // Global reset
    input         clk,          // Master clock (72 MHz)
    // Sprites registers (Z80 access)
    input         reg_rd,       // Sprites registers read strobe
    input         reg_wr,       // Sprites registers write strobe
    input  [11:0] reg_addr,     // Sprites registers address (4 KB range)
    input   [7:0] reg_wdata,    // Sprites registers write data
    output  [7:0] reg_rdata,    // Sprites registers read data
    // Signals from video beam generator
    input         bus_dma_ena,  // Bus video DMA enable
    input   [8:0] bus_vpos,     // Bus vertical position
    input         bus_eol,      // Bus end of line
    // Signals from SDRAM controller
    input   [3:0] ram_cyc,      // SDRAM cycles
    input   [3:0] ram_ph,       // SDRAM phases
    input   [8:0] ram_ph_ctr,   // SDRAM phase counter
    // Sprites DMAs
    input         spr_fifo_clr, // Sprite FIFO clear
    input         spr_dma_ena,  // Sprite DMA enable
    output [17:3] spr_dma_addr, // Max : 256 KB (2048 sprites of 16 x 16 x 4 bits)
    output        spr_dma_rden, // DMA read enable
    input         spr_data_vld, // Sprite data valid
    input  [15:0] spr_data,     // Sprite data
    // Video FIFOs access
    input   [1:0] vid_line,     // Video line number
    input         vid_read,     // Video data read
    input         vid_next,     // Next video data
    input         vid_layer,    // Video layer select
    output  [7:0] vid_data_0,   // Video data layer #0
    output  [7:0] vid_data_1,   // Video data layer #1
    output  [1:0] vid_vld       // Video data valid
);

    // ======================================================
    // Sprites registers
    // ======================================================
    
    wire  [9:0] w_spr_regs_addr_p0;
    wire [31:0] w_spr_regs_q_p2;
    
    wire [10:0] w_spr_idx;
    wire  [8:0] w_spr_x_pos;
    wire  [7:0] w_spr_y_pos;
    wire  [3:0] w_spr_pal_idx;
    
    assign w_spr_regs_addr_p0 = { ~ram_ph_ctr[6:0], 3'b000 };
    
    mem_dc_4096x8to32r U_spr_regs
    (
        // Z80 side
        .clock_a   (clk),
        .rden_a    (reg_rd),
        .wren_a    (reg_wr),
        .address_a (reg_addr),
        .data_a    (reg_wdata),
        .q_a       (reg_rdata),
        // GPU side
        .clock_b   (clk),
        .rden_b    (1'b1),
        .wren_b    (1'b0),
        .address_b (w_spr_regs_addr_p0),
        .data_b    (32'h00000000),
        .q_b       (w_spr_regs_q_p2)
    );
    
    assign w_spr_idx     = { w_spr_regs_q_p2[15:13], w_spr_regs_q_p2[7:0] };
    assign w_spr_pal_idx =   w_spr_regs_q_p2[11:8];
    assign w_spr_x_pos   = { w_spr_regs_q_p2[12], w_spr_regs_q_p2[31:24] };
    assign w_spr_y_pos   =   w_spr_regs_q_p2[23:16];

    // ======================================================
    // Sprites addresses
    // ======================================================
    
    reg [17:3] r_spr_addr;
    reg        r_spr_rden;
    reg        r_spr_under;

    always @(posedge rst or posedge clk) begin : SPR_ADDR
        reg [8:0] v_x_cmp;
        
        if (rst) begin
            r_spr_addr  <= 15'd0;
            r_spr_rden  <= 1'b0;
            r_spr_under <= 1'b0;
        end
        else begin
            v_x_cmp = (bus_vpos ^ 9'h0FF) - w_spr_x_pos;
            
            if (spr_dma_ena) begin
                // Sprite index (0 - 2047)
                r_spr_addr[17:7] <= w_spr_idx;
                // Sprite line number (0 - 15)
                r_spr_addr[6:3]  <= ~v_x_cmp[3:0];
            end
            // Sprite read enable
            if (ram_cyc[2] & ram_ph[0]) begin
                r_spr_rden <= (v_x_cmp[8:4] == 5'd0) ? spr_dma_ena & bus_dma_ena : 1'b0;
            end
            // Special flag : sprites under scroll #1 (palettes 10 & 11)
            r_spr_under <= (w_spr_pal_idx[3:1] == 3'b101) ? 1'b1 : 1'b0;
        end
    end
    
    assign spr_dma_addr = r_spr_addr;
    assign spr_dma_rden = r_spr_rden;
    
    // ======================================================
    // Sprite FIFOs write control
    // ======================================================
    
    reg   [1:0] r_fifo_gfx_we;    // Write enable (2 layers)
    reg   [3:0] r_fifo_gfx_be;    // Byte enable (4 pixels)
    reg  [15:0] r_fifo_gfx_data;  // Shifted pixels
    reg   [7:0] r_fifo_gfx_waddr; // Write address
    wire [31:0] w_fifo_gfx_data;  // Shifted color index

    always @(posedge rst or posedge clk) begin : FIFO_WR_CTL
        reg  [1:0] v_line;
        reg  [5:0] v_addr;
        reg [15:0] v_data;
        reg  [2:0] v_ctr;
        reg        v_we_5;
    
        if (rst) begin
            r_fifo_gfx_we    <= 2'b00;
            r_fifo_gfx_be    <= 4'b0000;
            r_fifo_gfx_data  <= 16'h0000;
            r_fifo_gfx_waddr <= 8'd0;
            v_line           <= 2'd0;
            v_addr           <= 6'd0;
            v_data           <= 16'h0000;
            v_ctr            <= 3'd0;
        end
        else begin
            // FIFO write enable
            v_we_5 = v_ctr[2] & (w_spr_y_pos[1] | w_spr_y_pos[0]);
            r_fifo_gfx_we[0] <= (spr_data_vld | v_we_5) &  r_spr_under | spr_fifo_clr;
            r_fifo_gfx_we[1] <= (spr_data_vld | v_we_5) & ~r_spr_under | spr_fifo_clr;
            
            // FIFO data and byte enable (with pixel shifter)
            if (spr_fifo_clr) begin
                // FIFO clear
                r_fifo_gfx_be   <= 4'b1111;
                r_fifo_gfx_data <= 16'h0000;
            end
            else begin
                // Data from SDRAM
                case (w_spr_y_pos[1:0])
                    2'd0 : begin
                        r_fifo_gfx_be[0] <= (|spr_data[ 3: 0]) & spr_data_vld;
                        r_fifo_gfx_be[1] <= (|spr_data[ 7: 4]) & spr_data_vld;
                        r_fifo_gfx_be[2] <= (|spr_data[11: 8]) & spr_data_vld;
                        r_fifo_gfx_be[3] <= (|spr_data[15:12]) & spr_data_vld;
                        r_fifo_gfx_data  <= { spr_data[15: 0]                };
                    end
                    2'd1 : begin
                        r_fifo_gfx_be[0] <=   |v_data[15:12];
                        r_fifo_gfx_be[1] <= (|spr_data[ 3: 0]) & spr_data_vld;
                        r_fifo_gfx_be[2] <= (|spr_data[ 7: 4]) & spr_data_vld;
                        r_fifo_gfx_be[3] <= (|spr_data[11: 8]) & spr_data_vld;
                        r_fifo_gfx_data  <= { spr_data[11: 0], v_data[15:12] };
                    end
                    2'd2 : begin
                        r_fifo_gfx_be[0] <=   |v_data[11: 8];
                        r_fifo_gfx_be[1] <=   |v_data[15:12];
                        r_fifo_gfx_be[2] <= (|spr_data[ 3: 0]) & spr_data_vld;
                        r_fifo_gfx_be[3] <= (|spr_data[ 7: 4]) & spr_data_vld;
                        r_fifo_gfx_data  <= { spr_data[ 7: 0], v_data[15: 8] };
                    end
                    2'd3 : begin
                        r_fifo_gfx_be[0] <=   |v_data[ 7: 4];
                        r_fifo_gfx_be[1] <=   |v_data[11: 8];
                        r_fifo_gfx_be[2] <=   |v_data[15:12];
                        r_fifo_gfx_be[3] <= (|spr_data[ 3: 0]) & spr_data_vld;
                        r_fifo_gfx_data  <= { spr_data[ 3: 0], v_data[15: 4] };
                    end
                endcase
            end
            v_data <= (spr_data_vld) ? spr_data : 16'h0000;
            
            // FIFO address
            r_fifo_gfx_waddr <= { v_line, v_addr };
            
            // FIFO line counter (0 - 3)
            if (bus_dma_ena) begin
                if (bus_eol) v_line <= v_line + 2'd1;
            end
            else begin
                v_line <= 2'd0;
            end
            
            // FIFO line address & transfer count
            if (spr_data_vld | spr_fifo_clr) begin
                // SDRAM transfer
                v_addr <= v_addr + 6'd1;
                v_ctr  <= v_ctr + 3'd1;
            end
            else begin
                // End of SDRAM transfer
                v_addr <= w_spr_y_pos[7:2];
                v_ctr  <= 3'd0;
            end
        end
    end
    
    assign w_fifo_gfx_data[31:24] = { w_spr_pal_idx, r_fifo_gfx_data[15:12] };
    assign w_fifo_gfx_data[23:16] = { w_spr_pal_idx, r_fifo_gfx_data[11: 8] };
    assign w_fifo_gfx_data[15: 8] = { w_spr_pal_idx, r_fifo_gfx_data[ 7: 4] };
    assign w_fifo_gfx_data[ 7: 0] = { w_spr_pal_idx, r_fifo_gfx_data[ 3: 0] };
    
    // ======================================================
    // Sprite FIFO layer #0 (4 lines of 256 pixels)
    // ======================================================
    
    mem_dc_256x32to8r U_line_fifo_0
    (
        // Write port
        .wrclock   (clk),
        .wren      (r_fifo_gfx_we[0]),
        .wraddress (r_fifo_gfx_waddr),
        .byteena_a (r_fifo_gfx_be),
        .data      (w_fifo_gfx_data),
        // Read port
        .rdclock   (clk),
        .rden      (1'b1),
        .rdaddress ({ vid_line, r_fifo_gfx0_raddr_p0 }),
        .q         (w_fifo_gfx0_q_p2)
    );
    
    // ======================================================
    // Sprite FIFO layer #1 (4 lines of 256 pixels)
    // ======================================================
    
    mem_dc_256x32to8r U_line_fifo_1
    (
        // Write port
        .wrclock   (clk),
        .wren      (r_fifo_gfx_we[1]),
        .wraddress (r_fifo_gfx_waddr),
        .byteena_a (r_fifo_gfx_be),
        .data      (w_fifo_gfx_data),
        // Read port
        .rdclock   (clk),
        .rden      (1'b1),
        .rdaddress ({ vid_line, r_fifo_gfx1_raddr_p0 }),
        .q         (w_fifo_gfx1_q_p2)
    );
    
    // ======================================================
    // Sprite FIFOs read control
    // ======================================================
    
    reg  [7:0] r_fifo_gfx0_raddr_p0;
    reg  [7:0] r_fifo_gfx1_raddr_p0;
    reg  [1:0] r_fifo_gfx0_vld_p2;
    reg  [1:0] r_fifo_gfx1_vld_p2;
    wire [7:0] w_fifo_gfx0_q_p2;
    wire [7:0] w_fifo_gfx1_q_p2;
    
    always @(posedge rst or posedge clk) begin : FIFO_RD_CTL
    
        if (rst) begin
            r_fifo_gfx0_raddr_p0 <= 8'd16;
            r_fifo_gfx1_raddr_p0 <= 8'd16;
            r_fifo_gfx0_vld_p2   <= 2'b00;
            r_fifo_gfx1_vld_p2   <= 2'b00;
        end
        else begin
            if (bus_eol) begin
                r_fifo_gfx0_raddr_p0 <= 8'd16;
                r_fifo_gfx1_raddr_p0 <= 8'd16;
            end
            else if (vid_next) begin
                if (vid_layer)
                    r_fifo_gfx1_raddr_p0 <= r_fifo_gfx1_raddr_p0 + 8'd1;
                else
                    r_fifo_gfx0_raddr_p0 <= r_fifo_gfx0_raddr_p0 + 8'd1;
            end
            r_fifo_gfx0_vld_p2 <= { r_fifo_gfx0_vld_p2[0], vid_read & ~vid_layer };
            r_fifo_gfx1_vld_p2 <= { r_fifo_gfx1_vld_p2[0], vid_read &  vid_layer };
        end
    end
    
    assign vid_data_0 = w_fifo_gfx0_q_p2;
    assign vid_data_1 = w_fifo_gfx1_q_p2;
    assign vid_vld[0] = r_fifo_gfx0_vld_p2[1];
    assign vid_vld[1] = r_fifo_gfx1_vld_p2[1];
    
    // ======================================================
    
endmodule
