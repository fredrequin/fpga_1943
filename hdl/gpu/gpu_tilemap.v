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

module gpu_tilemap
(
    // Clock and reset
    input         rst,          // Global reset
    input         clk,          // Master clock (72 MHz)
    // Scroll registers (Z80 access)
    input   [2:0] reg_wr,       // Scroll register write strobe
    input   [7:0] reg_wdata,    // Scroll register data
    // Signals from video beam generator
    input         bus_dma_ena,  // Bus video DMA enable
    input         bus_eol,      // Bus end of line
    // Signals from SDRAM controller
    input   [3:0] ram_cyc,      // SDRAM cycles
    input   [3:0] ram_ph,       // SDRAM phases
    input   [8:0] ram_ph_ctr,   // SDRAM phase counter
    // Scroll map DMAs
    input         map_dma_ena,  // Map DMA enable
    output [14:1] map_dma_addr, // Max : 32 KB (8 x 2048 words)
    output        map_dma_rden, // DMA read enable
    input         map_data_vld, // Map data valid
    input  [15:0] map_data,     // Map data
    // Scroll tiles DMAs
    input         gfx_dma_ena,  // Tile DMA enable
    output [18:3] gfx_dma_addr, // Max : 512 KB (1024 tiles of 32 x 32 x 4 bits)
    output        gfx_dma_rden, // DMA read enable
    input         gfx_data_vld, // Tile data valid
    input  [15:0] gfx_data,     // Tile data
    // Video FIFO access
    input   [1:0] vid_line,     // Video line number
    input         vid_read,     // Video data read
    input         vid_next,     // Next video data
    output  [7:0] vid_data,     // Video data
    output        vid_vld       // Video data valid
);

    // ======================================================
    // Scroll X and Y
    // ======================================================
    
    reg [15:0] r_scr_x;
    reg  [7:0] r_scr_y;
        
    always @(posedge rst or posedge clk) begin : REG_SCROLL_XY
    
        if (rst) begin
            r_scr_x <= 16'd0;
            r_scr_y <= 8'd0;
        end
        else begin
            // LSB (address = $D800 or $D803)
            if (reg_wr[0]) r_scr_x[7:0] <= reg_wdata;
            // MSB (address = $D801 or $D804)
            if (reg_wr[1]) r_scr_x[15:8] <= reg_wdata;
            // 8-bit (address = $D802)
            if (reg_wr[2]) r_scr_y <= reg_wdata;
        end
    end

    // ======================================================
    // Scroll X counter
    // ======================================================
    
    reg [15:0] r_scr_x_ctr;
    
    always @(posedge rst or posedge clk) begin : SCROLL_X_CTR
    
        if (rst) begin
            r_scr_x_ctr <= 16'd0;
        end
        else begin
            if (bus_dma_ena) begin
                if (bus_eol) r_scr_x_ctr <= r_scr_x_ctr - 16'd1;
            end
            else begin
                r_scr_x_ctr <= r_scr_x + 16'd255; // ??
            end
        end
    end
    
    // ======================================================
    // Scroll map address
    // ======================================================
    
    reg [14:1] r_scr_map_addr;
    reg        r_scr_map_rden;

    always @(posedge rst or posedge clk) begin : MAP_ADDR
        
        if (rst) begin
            r_scr_map_addr <= 14'd0;
            r_scr_map_rden <= 1'b0;
        end
        else begin
            if (map_dma_ena) begin
                // X position
                r_scr_map_addr[14:4] <= r_scr_x_ctr[15:5];
                // Y position
                r_scr_map_addr[3:1]  <= ram_ph_ctr[4:2];
            end
            if (ram_cyc[1] & ram_ph[2]) begin
                r_scr_map_rden <= map_dma_ena & bus_dma_ena;
            end
        end
    end
    
    assign map_dma_addr = r_scr_map_addr;
    assign map_dma_rden = r_scr_map_rden;
    
    // ======================================================
    // Scroll map data
    // ======================================================
    
    reg       r_scr_flip_y;   // Flip Y
    reg       r_scr_flip_x;   // Flip X
    reg [3:0] r_scr_pal_idx;  // Palette index : 0 - 15
    reg [9:0] r_scr_tile_idx; // Tile index : 0 - 1023
    
    always @(posedge rst or posedge clk) begin : MAP_DATA
        reg [1:0] v_ctr;
        
        if (rst) begin
            r_scr_flip_y   <= 1'b0;
            r_scr_flip_x   <= 1'b0;
            r_scr_pal_idx  <= 4'd0;
            r_scr_tile_idx <= 10'd0;
            v_ctr          <= 2'd0;
        end
        else begin
            if (map_data_vld) begin
                if (v_ctr == ram_ph_ctr[3:2]) begin
                    r_scr_flip_y   <= map_data[15];
                    r_scr_flip_x   <= map_data[14];
                    r_scr_pal_idx  <= map_data[13:10];
                    r_scr_tile_idx <= map_data[9:0];
                end
                v_ctr <= v_ctr + 2'd1;
            end
            else
                v_ctr <= 2'd0;
        end
    end
    
    // ======================================================
    // Scroll tile address
    // ======================================================
    
    reg [18:3] r_scr_gfx_addr;
    reg        r_scr_gfx_rden;

    always @(posedge rst or posedge clk) begin : GFX_ADDR
        
        if (rst) begin
            r_scr_gfx_addr <= 16'd0;
            r_scr_gfx_rden <= 1'b0;
        end
        else begin
            if (gfx_dma_ena) begin
                // Tile index (0 - 1023)
                r_scr_gfx_addr[18:9] <= r_scr_tile_idx;
                // Tile line number (with flip X logic)
                r_scr_gfx_addr[8:4]  <= r_scr_x_ctr[4:0] ^ {5{~r_scr_flip_x}};
                // Tile half line select
                r_scr_gfx_addr[3]    <= ram_ph_ctr[1];
            end
            if (ram_cyc[1] & ram_ph[2]) begin
                r_scr_gfx_rden <= gfx_dma_ena & bus_dma_ena;
            end
        end
    end
    
    assign gfx_dma_addr = r_scr_gfx_addr;
    assign gfx_dma_rden = r_scr_gfx_rden;
    
    // ======================================================
    // Scroll FIFO write control
    // ======================================================

    reg         r_fifo_gfx_we;
    reg  [15:0] r_fifo_gfx_data;
    reg   [7:0] r_fifo_gfx_waddr;
    wire [31:0] w_fifo_gfx_data;
    
    always @(posedge rst or posedge clk) begin : FIFO_WR_CTL
        reg [5:0] v_addr;
        reg [1:0] v_line;
        
        if (rst) begin
            r_fifo_gfx_we    <= 1'b0;
            r_fifo_gfx_data  <= 16'h0000;
            r_fifo_gfx_waddr <= 8'd0;
            v_line           <= 2'd0;
            v_addr           <= 6'd0;
        end
        else begin
            // FIFO write enable
            r_fifo_gfx_we <= gfx_data_vld;
            // FIFO data (with flip Y logic)
            if (r_scr_flip_y) begin
                r_fifo_gfx_data[15:12] <= gfx_data[ 3: 0];
                r_fifo_gfx_data[11: 8] <= gfx_data[ 7: 4];
                r_fifo_gfx_data[ 7: 4] <= gfx_data[11: 8];
                r_fifo_gfx_data[ 3: 0] <= gfx_data[15:12];
            end
            else begin
                r_fifo_gfx_data[15:12] <= gfx_data[15:12];
                r_fifo_gfx_data[11: 8] <= gfx_data[11: 8];
                r_fifo_gfx_data[ 7: 4] <= gfx_data[ 7: 4];
                r_fifo_gfx_data[ 3: 0] <= gfx_data[ 3: 0];
            end
            // FIFO address (with flip Y logic)
            r_fifo_gfx_waddr <= { v_line, v_addr }
                              ^ { 5'd0, {3{r_scr_flip_y}} };
            // FIFO line counter (0 - 3)
            if (bus_dma_ena) begin
                if (bus_eol) v_line <= v_line + 2'd1;
            end
            else begin
                v_line <= 2'd0;
            end
            // FIFO line address (0 - 63)
            if (gfx_data_vld) begin
                v_addr <= v_addr + 6'd1;
            end
        end
    end
    
    assign w_fifo_gfx_data[31:24] = { r_scr_pal_idx, r_fifo_gfx_data[15:12] };
    assign w_fifo_gfx_data[23:16] = { r_scr_pal_idx, r_fifo_gfx_data[11: 8] };
    assign w_fifo_gfx_data[15: 8] = { r_scr_pal_idx, r_fifo_gfx_data[ 7: 4] };
    assign w_fifo_gfx_data[ 7: 0] = { r_scr_pal_idx, r_fifo_gfx_data[ 3: 0] };
    
    // ======================================================
    // Scroll FIFO (4 lines of 256 pixels)
    // ======================================================
    
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
    
    // ======================================================
    // Scroll FIFO read control
    // ======================================================
    
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
                r_fifo_gfx_raddr_p0 <= 8'd16 + r_scr_y;
            end
            else if (vid_next) begin
                r_fifo_gfx_raddr_p0 <= r_fifo_gfx_raddr_p0 + 8'd1;
            end
            r_fifo_gfx_q_vld_p2 <= { r_fifo_gfx_q_vld_p2[0], vid_read };
        end
    end
    
    assign vid_data = w_fifo_gfx_q_p2;
    assign vid_vld  = r_fifo_gfx_q_vld_p2[1];
    
    // ======================================================
    
endmodule
