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

module gpu_colormux
(
    // Clock and reset
    input         rst,           // Global reset
    input         clk,           // Master clock (72 MHz)
    // Scale2X bypass
    input         s2x_bypass,    // Turn off Scale2X filter
    // Z80 write access to BM PROM
    input         prom_wr,       // PROM write strobe
    input  [10:0] prom_addr,     // PROM address (2 KB range)
    input   [7:0] prom_wdata,    // PROM write data
    // Signals from video beam generator
    input         bus_eol,       // Bus end-of-line
    input         bus_eof,       // Bus end-of-frame
    input         bus_frd_ena,   // FIFO read enable
    input         bus_dma_fline, // Bus DMA first line
    input         bus_dma_lline, // Bus DMA last line
    // Signals from SDRAM controller
    input   [3:0] ram_cyc,       // SDRAM cycles
    // Video FIFOs control
    output  [1:0] vid_line,

    output        bgn_read,
    output        bgn_next,
    input   [7:0] bgn_data,
    input         bgn_vld,

    output        fgn_read,
    output        fgn_next,
    input   [7:0] fgn_data,
    input         fgn_vld,

    output        spr_read,
    output        spr_next,
    output        spr_layer,
    input   [7:0] sp0_data,
    input         sp0_vld,
    input   [7:0] sp1_data,
    input         sp1_vld,

    output        chr_read,
    output        chr_next,
    input   [7:0] chr_data,
    input         chr_vld,
    
    // Color muxer output
    output [31:0] pix_data,
    output        pix_data_vld
);

    // ========================================================
    // Video FIFOs read control
    // ========================================================
    
    reg [4:0] r_layer_sel;
    reg [1:0] r_vid_line;
    reg       r_bgn_read;
    reg       r_bgn_next;
    reg       r_spr_read;
    reg       r_spr_next;
    reg       r_spr_layer;
    reg       r_fgn_read;
    reg       r_fgn_next;
    reg       r_chr_read;
    reg       r_chr_next;
    
    always @(posedge rst or posedge clk) begin : VID_READ_CTRL
        reg [1:0] v_line_top;
        reg [1:0] v_line_mid;
        reg [1:0] v_line_bot;
        
        if (rst) begin
            r_layer_sel <= 5'b00001;
            r_vid_line  <= 2'd0;
            r_bgn_read  <= 1'b0;
            r_bgn_next  <= 1'b0;
            r_spr_read  <= 1'b0;
            r_spr_next  <= 1'b0;
            r_spr_layer <= 1'b0;
            r_fgn_read  <= 1'b0;
            r_fgn_next  <= 1'b0;
            r_chr_read  <= 1'b0;
            r_chr_next  <= 1'b0;
            v_line_top  <= 2'd0;
            v_line_mid  <= 2'd0;
            v_line_bot  <= 2'd0;
        end
        else begin
            // Layer select shift register
            if (bus_frd_ena & ram_cyc[3])
                r_layer_sel <= { r_layer_sel[3:0], r_layer_sel[4] };
            
            // Buffer line select
            r_vid_line  <= v_line_top & {2{ram_cyc[0]}}
                         | v_line_bot & {2{ram_cyc[1]}}
                         | v_line_mid & {2{|ram_cyc[3:2]}};
            
            // Background read
            r_bgn_read  <= bus_frd_ena & r_layer_sel[0];
            r_bgn_next  <= bus_frd_ena & r_layer_sel[0] & ram_cyc[2];
            
            // Sprites read
            r_spr_read  <= bus_frd_ena & (r_layer_sel[1] | r_layer_sel[3]);
            r_spr_next  <= bus_frd_ena & (r_layer_sel[1] | r_layer_sel[3]) & ram_cyc[2];
            r_spr_layer <= r_layer_sel[3];
            
            // Foreground read
            r_fgn_read  <= bus_frd_ena & r_layer_sel[2];
            r_fgn_next  <= bus_frd_ena & r_layer_sel[2] & ram_cyc[2];
            
            // Characters read
            r_chr_read  <= bus_frd_ena & r_layer_sel[4];
            r_chr_next  <= bus_frd_ena & r_layer_sel[4] & ram_cyc[2];
            
            // Top, bottom & middle lines
            if (bus_dma_fline)
                v_line_top <= v_line_mid; // Special case : first line
            else
                v_line_top <= v_line_mid - 2'd1;
                
            if (bus_dma_lline)
                v_line_bot <= v_line_mid; // Special case : last line
            else
                v_line_bot <= v_line_mid + 2'd1;
                
            if (bus_eol) begin
                if (bus_eof)
                    v_line_mid <= 2'd2;
                else
                    v_line_mid <= v_line_mid + 2'd1;
            end
        end
    end
    
    assign vid_line  = r_vid_line;
    assign bgn_read  = r_bgn_read;
    assign bgn_next  = r_bgn_next;
    assign spr_read  = r_spr_read;
    assign spr_next  = r_spr_next;
    assign spr_layer = r_spr_layer;
    assign fgn_read  = r_fgn_read;
    assign fgn_next  = r_fgn_next;
    assign chr_read  = r_chr_read;
    assign chr_next  = r_chr_next;

    // ========================================================
    // Video data multiplexer
    // ========================================================
    
    reg  [9:0] r_data_p0;
    reg  [4:0] r_vld_p0;
    reg        r_chr_p0;
    reg  [4:0] r_vld_p1;
    reg        r_chr_p1;
    reg        r_vld_p2;
    reg        r_chr_p2;
    reg  [4:0] r_end_p2;
    
    always @(posedge rst or posedge clk) begin : VID_DATA_MUX
        
        if (rst) begin
            r_data_p0 <= 10'd0;
            r_vld_p0  <= 5'b00000;
            r_chr_p0  <= 1'b0;
            r_vld_p1  <= 5'b00000;
            r_chr_p1  <= 1'b0;
            r_vld_p2  <= 1'b0;
            r_chr_p2  <= 1'b0;
            r_end_p2  <= 5'b00000;
        end
        else begin
            // 000 - 0FF : Background
            // 100 - 1FF : Foreground
            // 200 - 2FF : Sprites
            // 300 - 3FF : Characters
            r_data_p0[9]   <= sp0_vld | sp1_vld | chr_vld;
            r_data_p0[8]   <= fgn_vld | chr_vld;
            r_data_p0[7:0] <= bgn_data & {8{bgn_vld}}  // Background
                            | sp0_data & {8{sp0_vld}}  // Sprite layer #0
                            | fgn_data & {8{fgn_vld}}  // Foreground
                            | sp1_data & {8{sp1_vld}}  // Sprite layer #1
                            | chr_data & {8{chr_vld}}; // Characters
                            
            if (ram_cyc[3]) r_chr_p0 <= r_layer_sel[4];
            r_vld_p0  <= { chr_vld, sp1_vld, fgn_vld, sp0_vld, bgn_vld };
            
            r_chr_p1  <= r_chr_p0;
            r_vld_p1  <= r_vld_p0;
            
            r_chr_p2  <= r_chr_p1;
            r_vld_p2  <=   ~ram_cyc[0]   & |r_vld_p1;
            r_end_p2  <= {5{ram_cyc[0]}} &  r_vld_p1;
        end
    end
    
    // ========================================================
    // Color index to palette index lookup table
    // ========================================================
    
    wire [8:0] w_pal_idx_p2;
    
    mem_dc_1024x9to9r
    #(
        .INIT_FILE ("bm_prom.mem")
    )
    U_bm_prom
    (
        // Z80 access
        .wrclock   (clk),
        .wren      (prom_wr),
        .wraddress (prom_addr[9:0]),
        .data      ({prom_addr[10], prom_wdata}),
        // GPU access
        .rdclock   (clk),
        .rden      (1'b1),
        .rdaddress (r_data_p0),
        .q         (w_pal_idx_p2)
    );
    
    // ========================================================
    // Video data buffers (for Scale2X block)
    // ========================================================
    
    reg [8:0] r_pix_B_p3;   // "top" pixel
    reg [8:0] r_pix_D_p3;   // "middle left" pixel
    reg [8:0] r_pix_E_p3;   // "middle" pixel
    reg [8:0] r_pix_F_p3;   // "middle right" pixel
    reg [8:0] r_pix_H_p3;   // "bottom" pixel
    reg [2:0] r_pix_ctr_p3; // Pixels counter
    reg       r_chr_p3;     // Last layer (characters)
    
    always @(posedge rst or posedge clk) begin : VID_DATA_BUF
        reg [8:0] v_pal_idx_bgn;
        reg [8:0] v_pal_idx_sp0;
        reg [8:0] v_pal_idx_fgn;
        reg [8:0] v_pal_idx_sp1;
        reg [8:0] v_pal_idx_chr;
        reg [8:0] v_pal_idx_top;
        reg [8:0] v_pal_idx_mid;
        reg [8:0] v_pal_idx_bot;
        reg [8:0] v_pal_idx_prev;
        
        if (rst) begin
            r_pix_B_p3    <= 9'h000;
            r_pix_D_p3    <= 9'h000;
            r_pix_E_p3    <= 9'h000;
            r_pix_F_p3    <= 9'h000;
            r_pix_H_p3    <= 9'h000;
            r_pix_ctr_p3  <= 3'd0;
            r_chr_p3      <= 1'b0;
            v_pal_idx_bgn <= 9'h000;
            v_pal_idx_sp0 <= 9'h000;
            v_pal_idx_fgn <= 9'h000;
            v_pal_idx_sp1 <= 9'h000;
            v_pal_idx_chr <= 9'h000;
            v_pal_idx_top <= 9'h000;
            v_pal_idx_mid <= 9'h000;
            v_pal_idx_bot <= 9'h000;
        end
        else begin
            // Keep pixels for the next computation
            if (r_end_p2[0]) v_pal_idx_bgn <= v_pal_idx_mid;
            if (r_end_p2[1]) v_pal_idx_sp0 <= v_pal_idx_mid;
            if (r_end_p2[2]) v_pal_idx_fgn <= v_pal_idx_mid;
            if (r_end_p2[3]) v_pal_idx_sp1 <= v_pal_idx_mid;
            if (r_end_p2[4]) v_pal_idx_chr <= v_pal_idx_mid;
            // Previous pixels multiplexing
            v_pal_idx_prev = v_pal_idx_bgn & {9{r_end_p2[0]}}
                           | v_pal_idx_sp0 & {9{r_end_p2[1]}}
                           | v_pal_idx_fgn & {9{r_end_p2[2]}}
                           | v_pal_idx_sp1 & {9{r_end_p2[3]}}
                           | v_pal_idx_chr & {9{r_end_p2[4]}};
            // Latch 5 pixels
            if (r_end_p2 != 5'b00000) begin
                r_pix_B_p3 <= v_pal_idx_top;
                r_pix_D_p3 <= v_pal_idx_prev;
                r_pix_E_p3 <= v_pal_idx_mid;
                r_pix_F_p3 <= w_pal_idx_p2;
                r_pix_H_p3 <= v_pal_idx_bot;
            end
            // Shift 3 pixels in
            if (r_vld_p2) begin
                v_pal_idx_mid <= w_pal_idx_p2;
                v_pal_idx_bot <= v_pal_idx_mid;
                v_pal_idx_top <= v_pal_idx_bot;
            end
            // Pixel counter
            if (r_end_p2 != 5'b00000)
                r_pix_ctr_p3 <= 3'd4;
            else if (r_pix_ctr_p3[2])
                r_pix_ctr_p3 <= r_pix_ctr_p3 + 3'd1;
            // Last layer : characters
            if (ram_cyc[1]) r_chr_p3 <= r_chr_p2;
        end
    end
    
    // ========================================================
    // Scale2X block
    // ========================================================
    
    wire [8:0] w_pix_Ex_p5;
    wire       w_pix_en_p5;
    reg        r_chr_p5;
    reg  [3:0] r_sel_p5;
    
    gpu_scale2x U_gpu_scale2x
    (
        .rst      (rst),
        .clk      (clk),
        
        .bypass   (s2x_bypass),
        
        .opix_sel (r_pix_ctr_p3[1:0]),
        
        .ipix_B   (r_pix_B_p3), 
        .ipix_D   (r_pix_D_p3), 
        .ipix_E   (r_pix_E_p3), 
        .ipix_F   (r_pix_F_p3), 
        .ipix_H   (r_pix_H_p3), 
        .ipix_en  (r_pix_ctr_p3[2]),
        
        .opix_Ex  (w_pix_Ex_p5),
        .opix_en  (w_pix_en_p5)
    );
    
    always @(posedge clk) begin
        if (ram_cyc[3])
            r_chr_p5 <= r_chr_p3;
        if (w_pix_en_p5)
            r_sel_p5 <= { r_sel_p5[2:0], r_sel_p5[3] };
        else
            r_sel_p5 <= 4'b0001;
    end
    
    // ========================================================
    // Layers priorities
    // ========================================================
    
    reg [31:0] r_pix_Ex_p6;
    reg        r_pix_en_p6;
    
    always @(posedge rst or posedge clk) begin : LAYER_PRIO
    
        if (rst) begin
            r_pix_Ex_p6 <= 32'h00000000;
            r_pix_en_p6 <= 1'b0;
        end
        else begin
            if (w_pix_en_p5 & w_pix_Ex_p5[8]) begin
                if (r_sel_p5[3]) r_pix_Ex_p6[31:24] <= w_pix_Ex_p5[7:0];
                if (r_sel_p5[2]) r_pix_Ex_p6[23:16] <= w_pix_Ex_p5[7:0];
                if (r_sel_p5[1]) r_pix_Ex_p6[15: 8] <= w_pix_Ex_p5[7:0];
                if (r_sel_p5[0]) r_pix_Ex_p6[ 7: 0] <= w_pix_Ex_p5[7:0];
            end
            r_pix_en_p6 <= r_chr_p5 & r_sel_p5[3];
        end
    end
    
    assign pix_data     = r_pix_Ex_p6;
    assign pix_data_vld = r_pix_en_p6;
    
endmodule
