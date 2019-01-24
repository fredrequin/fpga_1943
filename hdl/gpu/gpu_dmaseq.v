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

module gpu_dmaseq
(
    // Clock and reset
    input         rst,             // Global reset
    input         clk,             // Master clock (72 MHz)
    // Registers access
    input   [1:0] reg_wr,          // $C804 and $D806 registers
    input   [7:0] reg_wdata,       // Register data
    // SDRAM sequencing
    input         ram_ref,         // SDRAM refresh active
    input   [3:0] ram_cyc,         // SDRAM cycles
    input   [3:0] ram_ph,          // SDRAM phases
    input   [8:0] ram_ph_ctr,      // SDRAM phase counter
    // Z80 access
    output  [2:0] z80_bank,        // ROM banking of main Z80
    output        z80_cpu,         // Main Z80 access (6 MHz)
    output        z80_aud,         // Audio Z80 access (3 MHz)
    // Character access
    output        chr_gfx,         // Characters graphics
    // Tilemap access
    output  [1:0] scr_map,         // Scrolls #1 & #2 maps
    output  [1:0] scr_gfx,         // Scrolls #1 & #2 tiles
    // Sprite access
    output        spr_gfx,         // Sprites graphics
    output        spr_clr          // Sprites line buffer clear
);
    // Banks #0, 2 :
    // -------------
    // 572 Z80 access / line (100 % load)
    
    // Bank #1 :
    // ---------
    // 128 sprite access / line (45% load)

    // Bank #3 :
    // ---------
    // 2 x 8 map access / line
    // 2 x 16 tile access / line
    // 32 char access / line
    // => 80 access / line (28 % load)

    // ======================================================
    // Layers activations and ROM banking
    // ======================================================
    
    reg       r_chr_ena;  // Characters enable
    reg [1:0] r_scr_ena;  // Scrolls #1 & #2 enable
    reg       r_spr_ena;  // Sprites enable
    reg [2:0] r_z80_bank; // Main Z80 ROM banking
    
    always@(posedge rst or posedge clk) begin : LAYERS_BANKS
        if (rst) begin
            r_z80_bank <= 3'd0;
            r_chr_ena  <= 1'b0;
            r_scr_ena  <= 2'b00;
            r_spr_ena  <= 1'b0;
        end
        else begin
            // $C804 register
            if (reg_wr[0]) begin
                r_z80_bank <= reg_wdata[4:2];
                r_chr_ena  <= reg_wdata[7];
            end
            // $D806 register
            if (reg_wr[1]) begin
                r_scr_ena  <= reg_wdata[5:4];
                r_spr_ena  <= reg_wdata[6];
            end
        end
    end
    
    assign z80_bank = r_z80_bank;
    
    // ======================================================
    // Sprites access to SDRAM (bank #1)
    // ======================================================
    
    reg       r_spr_gfx; // Sprites graphics SDRAM fetch
    reg       r_spr_clr; // Sprites line buffer clear
    
    always@(posedge rst or posedge clk) begin : SPR_DMA
        reg [1:0] v_ctr;
        
        if (rst) begin
            r_spr_gfx <= 1'b0;
            r_spr_clr <= 1'b0;
            v_ctr     <= 2'd0;
        end
        else begin
            // Sprite access on phases 128 - 255
            r_spr_gfx <= ram_cyc[1] & ram_ph[0] & r_spr_ena & ram_ph_ctr[7];
            // Sprite line buffer clear during refresh
            if (ram_ph[3] & ram_cyc[3]) begin
                r_spr_clr <= ram_ref & ~(v_ctr[1] & v_ctr[0]);
                if (r_spr_clr) v_ctr <= v_ctr + 2'd1;
            end
        end
    end
    
    assign spr_gfx = r_spr_gfx;
    assign spr_clr = r_spr_clr;
    
    // ======================================================
    // Tilemaps and characters access to SDRAM (bank #3)
    // ======================================================
    
    reg       r_chr_gfx; // Character graphics SDRAM fetch
    reg [1:0] r_scr_map; // Scroll map SDRAM fetch
    reg [1:0] r_scr_gfx; // Scroll tile SDRAM fetch
    
    always@(posedge rst or posedge clk) begin : SCR_CHR_DMA
        if (rst) begin
            r_chr_gfx <= 1'b0;
            r_scr_map <= 2'b00;
            r_scr_gfx <= 2'b00;
        end
        else begin
            
            if (ram_cyc[0] & ram_ph[2]) begin
            
                // Scroll #1 map on phases 32, 36, 40, 44, 48, 52, 56, 60
                // Scroll #1 tile on odd phases 33 - 63
                if (ram_ph_ctr[8:5] == 4'b0001) begin
                    r_scr_map[0] <= r_scr_ena[0] & ~ram_ph_ctr[1] & ~ram_ph_ctr[0];
                    r_scr_gfx[0] <= r_scr_ena[0] &  ram_ph_ctr[0];
                end
                else begin
                    r_scr_map[0] <= 1'b0;
                    r_scr_gfx[0] <= 1'b0;
                end
                
                // Scroll #2 map on phases 96, 100, 104, 108, 112, 116, 120, 124
                // Scroll #2 tile on odd phases 97 - 127
                if (ram_ph_ctr[8:5] == 4'b0011) begin
                    r_scr_map[1] <= r_scr_ena[1] & ~ram_ph_ctr[1] & ~ram_ph_ctr[0];
                    r_scr_gfx[1] <= r_scr_ena[1] &  ram_ph_ctr[0];
                end
                else begin
                    r_scr_map[1] <= 1'b0;
                    r_scr_gfx[1] <= 1'b0;
                end
            end
            else begin
                r_scr_map <= 2'b00;
                r_scr_gfx <= 2'b00;
            end
            
            if (ram_cyc[1] & ram_ph[2]) begin
            
                // Characters on even phases 128 - 190
                if (ram_ph_ctr[8:6] == 3'b010)
                    r_chr_gfx <= r_chr_ena & ~ram_ph_ctr[0];
                else
                    r_chr_gfx <= 1'b0;
            end
            else begin
                r_chr_gfx <= 1'b0;
            end
        end
    end
    
    assign chr_gfx = r_chr_gfx;
    assign scr_map = r_scr_map;
    assign scr_gfx = r_scr_gfx;
    
    // ======================================================
    // Z80 CPUs access to SDRAM (banks #0 and #2)
    // ======================================================
    
    reg [2:0] r_z80_seq;
    reg       r_z80_cpu;
    reg       r_z80_aud;

    always@(posedge rst or posedge clk) begin : Z80_DMA
        reg [2:0] v_cpu_seq;
        reg [5:0] v_aud_seq;
        
        if (rst) begin
            r_z80_cpu <= 1'b0;
            r_z80_aud <= 1'b0;
            v_cpu_seq  = 3'b001;
            v_aud_seq  = 6'b000010;
        end
        else begin
            // Main CPU : 12 cycles
            r_z80_cpu <= v_cpu_seq[0] & ram_cyc[3];
            // Audio CPU : 24 cycles
            r_z80_aud <= v_aud_seq[0] & ram_cyc[1];
            
            if (ram_cyc[3]) v_cpu_seq = { v_cpu_seq[1:0], v_cpu_seq[2] };
            if (ram_cyc[3]) v_aud_seq = { v_aud_seq[4:0], v_aud_seq[5] };
        end
    end
    
    assign z80_cpu = r_z80_cpu;
    assign z80_aud = r_z80_aud;

    // ======================================================
    
endmodule
