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

module gpu_top
(
    // Main bus (72 MHz clock)
    input         bus_rst,
    input         bus_clk,
    
    output        main_vbl_int,
    input         main_z80_rden,
    input         main_z80_wren,
    input  [15:0] main_z80_addr,
    input   [7:0] main_z80_wdata,
    output  [7:0] main_z80_rdata,
    output        main_z80_dtack,
    output        main_z80_ena,
    output        main_z80_rst_n,
    
    input         audio_z80_rden,
    input         audio_z80_wren,
    input  [15:0] audio_z80_addr,
    input   [7:0] audio_z80_wdata,
    output  [7:0] audio_z80_rdata,
    output        audio_z80_dtack,
    output        audio_z80_ena,
    
    // Players inputs
    input   [1:0] start_n,
    input   [1:0] coin_n,
    input   [5:0] joy1_n,
    input   [5:0] joy2_n,
    
    // SDRAM interface (72 MHz clock)
    output        sdram_cs_n,
    output        sdram_ras_n,
    output        sdram_cas_n,
    output        sdram_we_n,

    output  [1:0] sdram_ba,
    output [12:0] sdram_addr, 

    output  [3:0] sdram_dqm_n,
    output        sdram_dq_oe,
    output [31:0] sdram_dq_o,
    input  [31:0] sdram_dq_i,
    
    // Layers debug
    output  [3:0] dbg_bgn_data,
    output        dbg_bgn_vld,
    output  [3:0] dbg_fgn_data,
    output        dbg_fgn_vld,
    output  [3:0] dbg_chr_data,
    output        dbg_chr_vld,
    
    // Video output (108 MHz clock)
    input         vid_rst,
    input         vid_clk,
    
    output        vga_hs,
    output        vga_vs,
    output        vga_de,
    output  [3:0] vga_r,
    output  [3:0] vga_g,
    output  [3:0] vga_b
);
    // SDRAM memory size (16 or 32 MB)
    parameter SDRAM_SIZE  = 16;
    // SDRAM memory width (16 or 32 bits)
    parameter SDRAM_WIDTH = 16;

    wire        w_ram_rdy_n;
    wire        w_ram_ref;
    wire  [3:0] w_ram_cyc;
    wire  [3:0] w_ram_ph;
    wire  [8:0] w_ram_ph_ctr;
    
    wire  [8:0] w_bus_vpos;
    wire        w_bus_eol;
    wire        w_bus_eof;
    wire        w_bus_dma_ena;
    wire        w_bus_frd_ena;
    wire        w_bus_dma_fl;
    wire        w_bus_dma_ll;
    
    wire  [1:0] w_map_ena;
    wire  [1:0] w_map_rden;
    wire [14:1] w_map_addr_bg; // 32 KB
    wire [14:1] w_map_addr_fg; // 32 KB
    
    wire  [1:0] w_gfx_ena;
    wire  [1:0] w_gfx_rden;
    wire [18:3] w_gfx_addr_bg; // 512 KB
    wire [18:3] w_gfx_addr_fg; // 512 KB
    
    wire        w_spr_clr;
    wire        w_spr_ena;
    wire        w_spr_rden;
    wire [17:3] w_spr_addr;    // 256 KB
    
    wire        w_chr_ena;
    wire        w_chr_rden;
    wire [15:2] w_chr_addr;    // 64 KB
    
    reg         r_rden_b0;
    reg         r_rden_b1;
    reg         r_rden_b2;
    reg         r_rden_b3;
    
    reg  [22:2] r_addr_b0;
    reg  [22:2] r_addr_b1;
    reg  [22:2] r_addr_b2;
    reg  [22:2] r_addr_b3;
    
    wire [15:0] w_rdata_b0;
    wire [15:0] w_rdata_b1;
    wire [15:0] w_rdata_b2;
    wire [15:0] w_rdata_b3;
    
    wire        w_valid_b0;
    wire        w_valid_b1;
    wire        w_valid_b2;
    wire        w_valid_b3;
    
    wire  [1:0] w_vid_line;
    
    wire        w_bgn_read;
    wire        w_bgn_next;
    wire  [7:0] w_bgn_data;
    wire        w_bgn_vld;
    
    wire        w_fgn_read;
    wire        w_fgn_next;
    wire  [7:0] w_fgn_data;
    wire        w_fgn_vld;
    
    wire        w_spr_read;
    wire        w_spr_next;
    wire        w_spr_layer;
    wire  [7:0] w_spr_data_0;
    wire  [7:0] w_spr_data_1;
    wire  [1:0] w_spr_vld;
    
    wire        w_chr_read;
    wire        w_chr_next;
    wire  [7:0] w_chr_data;
    wire        w_chr_vld;
    
    wire [31:0] w_pix_data;
    wire        w_pix_data_vld;
    
    wire        w_vid_clk_ena;
    wire        w_vid_eol;
    wire        w_vid_dena;
    wire [10:0] w_vid_vpos;
    
    wire  [3:0] w_cfg_prom_wren;
    wire        w_cfg_scale_2x_on;
    wire        w_cfg_scan_line_h;
    wire        w_cfg_scan_line_v;
    
    wire  [7:0] w_main_z80_lo;
    wire [15:0] w_main_z80_hi;
    
    wire        w_main_rd_C000;
    wire        w_main_rd_C001;
    wire        w_main_rd_C002;
    wire        w_main_rd_C003;
    wire        w_main_rd_C004;
    wire        w_main_rd_C007;
    
    wire        w_main_wr_C800;
    wire        w_main_wr_C804;
    wire        w_main_wr_C807;
    wire        w_main_wr_D800;
    wire        w_main_wr_D801;
    wire        w_main_wr_D802;
    wire        w_main_wr_D803;
    wire        w_main_wr_D804;
    wire        w_main_wr_D806;
    wire        w_main_wr_D807;
    
    wire        w_main_rd_D000;
    wire        w_main_wr_D000;
    wire        w_main_rd_E000;
    wire        w_main_wr_E000;
    wire        w_main_rd_F000;
    wire        w_main_wr_F000;
    
    wire        w_prom_bmp_wr;
    wire        w_prom_pal_wr;
    
    wire  [1:0] w_seq_wr;
    wire  [2:0] w_bgn_wr;
    wire  [2:0] w_fgn_wr;
    wire  [5:0] w_reg_rd;
    wire  [1:0] w_reg_wr;
    
    reg   [7:0] r_rom_rdata;
    wire  [7:0] w_ram_rdata;
    wire  [7:0] w_reg_rdata;
    wire  [7:0] w_spr_rdata;
    wire  [7:0] w_chr_rdata;
    
    wire  [2:0] w_main_bank;
    reg         r_main_dtack;
    reg   [7:0] r_main_rdata_0 [0:7]; // Caching of first 32 KB
    reg  [14:3] r_main_raddr_0;
    reg   [7:0] r_main_rdata_1 [0:7]; // Caching of next 16 KB
    reg  [16:3] r_main_raddr_1;
    
    // ======================================================
    // Address decoding
    // ======================================================
    
    // Decoding of range $C000 - $FFFF
    assign w_main_z80_lo[ 0] = (main_z80_addr[ 2: 0] == 3'b000    ) ? 1'b1 : 1'b0; // $XXX0
    assign w_main_z80_lo[ 1] = (main_z80_addr[ 2: 0] == 3'b001    ) ? 1'b1 : 1'b0; // $XXX1
    assign w_main_z80_lo[ 2] = (main_z80_addr[ 2: 0] == 3'b010    ) ? 1'b1 : 1'b0; // $XXX2
    assign w_main_z80_lo[ 3] = (main_z80_addr[ 2: 0] == 3'b011    ) ? 1'b1 : 1'b0; // $XXX3
    assign w_main_z80_lo[ 4] = (main_z80_addr[ 2: 0] == 3'b100    ) ? 1'b1 : 1'b0; // $XXX4
    assign w_main_z80_lo[ 5] = (main_z80_addr[ 2: 0] == 3'b101    ) ? 1'b1 : 1'b0; // $XXX5
    assign w_main_z80_lo[ 6] = (main_z80_addr[ 2: 0] == 3'b110    ) ? 1'b1 : 1'b0; // $XXX6
    assign w_main_z80_lo[ 7] = (main_z80_addr[ 2: 0] == 3'b111    ) ? 1'b1 : 1'b0; // $XXX7
    
    assign w_main_z80_hi[ 0] = (main_z80_addr[15:10] == 6'b1100_00) ? 1'b1 : 1'b0; // $C000
    assign w_main_z80_hi[ 1] = (main_z80_addr[15:10] == 6'b1100_01) ? 1'b1 : 1'b0; // $C400
    assign w_main_z80_hi[ 2] = (main_z80_addr[15:10] == 6'b1100_10) ? 1'b1 : 1'b0; // $C800
    assign w_main_z80_hi[ 3] = (main_z80_addr[15:10] == 6'b1100_11) ? 1'b1 : 1'b0; // $CC00
    assign w_main_z80_hi[ 4] = (main_z80_addr[15:10] == 6'b1101_00) ? 1'b1 : 1'b0; // $D000
    assign w_main_z80_hi[ 5] = (main_z80_addr[15:10] == 6'b1101_01) ? 1'b1 : 1'b0; // $D400
    assign w_main_z80_hi[ 6] = (main_z80_addr[15:10] == 6'b1101_10) ? 1'b1 : 1'b0; // $D800
    assign w_main_z80_hi[ 7] = (main_z80_addr[15:10] == 6'b1101_11) ? 1'b1 : 1'b0; // $DC00
    assign w_main_z80_hi[ 8] = (main_z80_addr[15:10] == 6'b1110_00) ? 1'b1 : 1'b0; // $E000
    assign w_main_z80_hi[ 9] = (main_z80_addr[15:10] == 6'b1110_01) ? 1'b1 : 1'b0; // $E400
    assign w_main_z80_hi[10] = (main_z80_addr[15:10] == 6'b1110_10) ? 1'b1 : 1'b0; // $E800
    assign w_main_z80_hi[11] = (main_z80_addr[15:10] == 6'b1110_11) ? 1'b1 : 1'b0; // $EC00
    assign w_main_z80_hi[12] = (main_z80_addr[15:10] == 6'b1111_00) ? 1'b1 : 1'b0; // $F000
    assign w_main_z80_hi[13] = (main_z80_addr[15:10] == 6'b1111_01) ? 1'b1 : 1'b0; // $F400
    assign w_main_z80_hi[14] = (main_z80_addr[15:10] == 6'b1111_10) ? 1'b1 : 1'b0; // $F800
    assign w_main_z80_hi[15] = (main_z80_addr[15:10] == 6'b1111_11) ? 1'b1 : 1'b0; // $FC00
    
    // Regiters read decoding
    assign w_main_rd_C000 = w_main_z80_hi[0] & w_main_z80_lo[0] & main_z80_rden; // Start/Coin
    assign w_main_rd_C001 = w_main_z80_hi[0] & w_main_z80_lo[1] & main_z80_rden; // Joystick #1
    assign w_main_rd_C002 = w_main_z80_hi[0] & w_main_z80_lo[2] & main_z80_rden; // Joystick #2
    assign w_main_rd_C003 = w_main_z80_hi[0] & w_main_z80_lo[3] & main_z80_rden; // DIP switch A
    assign w_main_rd_C004 = w_main_z80_hi[0] & w_main_z80_lo[4] & main_z80_rden; // DIP switch B
    assign w_main_rd_C007 = w_main_z80_hi[0] & w_main_z80_lo[7] & main_z80_rden; // Security chip
    
    // Registers write decoding
    assign w_main_wr_C800 = w_main_z80_hi[2] & w_main_z80_lo[0] & main_z80_wren;
    assign w_main_wr_C804 = w_main_z80_hi[2] & w_main_z80_lo[4] & main_z80_wren; // Characters, Z80 banks
    assign w_main_wr_C807 = w_main_z80_hi[2] & w_main_z80_lo[7] & main_z80_wren; // Security chip
    assign w_main_wr_D800 = w_main_z80_hi[6] & w_main_z80_lo[0] & main_z80_wren; // Scroll #1 X LSB
    assign w_main_wr_D801 = w_main_z80_hi[6] & w_main_z80_lo[1] & main_z80_wren; // Scroll #1 X MSB
    assign w_main_wr_D802 = w_main_z80_hi[6] & w_main_z80_lo[2] & main_z80_wren; // Scroll #1 Y
    assign w_main_wr_D803 = w_main_z80_hi[6] & w_main_z80_lo[3] & main_z80_wren; // Scroll #2 X LSB
    assign w_main_wr_D804 = w_main_z80_hi[6] & w_main_z80_lo[4] & main_z80_wren; // Scroll #2 X MSB
    assign w_main_wr_D806 = w_main_z80_hi[6] & w_main_z80_lo[6] & main_z80_wren; // Scrolls, Sprites
    assign w_main_wr_D807 = w_main_z80_hi[6] & w_main_z80_lo[7] & main_z80_wren; // Special register
    
    // Memories decoding
    assign w_main_rd_D000 = |w_main_z80_hi[ 5: 4] & main_z80_rden; // Characters
    assign w_main_wr_D000 = |w_main_z80_hi[ 5: 4] & main_z80_wren;
    assign w_main_rd_E000 = |w_main_z80_hi[11: 8] & main_z80_rden; // Main Z80 RAM
    assign w_main_wr_E000 = |w_main_z80_hi[11: 8] & main_z80_wren;
    assign w_main_rd_F000 = |w_main_z80_hi[15:12] & main_z80_rden; // Sprites registers
    assign w_main_wr_F000 = |w_main_z80_hi[15:12] & main_z80_wren;
    
    // PROMs write
    assign w_prom_bmp_wr  =  w_main_z80_hi[7]     & main_z80_wren & ~w_cfg_prom_wren[1]; // Bitmap PROM (2 KB)
    assign w_prom_pal_wr  =  w_main_z80_hi[7]     & main_z80_wren &  w_cfg_prom_wren[1]; // Color PROM (2 KB)
    
    // ======================================================
    // Busses multiplexers
    // ======================================================
    
    always@(posedge bus_clk) begin : ADDRESS_MUX
        r_rden_b3 <= (|w_map_rden) | (|w_gfx_rden) | w_chr_rden;
        r_addr_b3 <= { 8'b00000000, w_map_addr_bg[14:3], 1'b0 } & {21{w_map_rden[0]}}
                   | { 8'b00000001, w_map_addr_fg[14:3], 1'b0 } & {21{w_map_rden[1]}}
                   | { 7'b0000001,  w_chr_addr[15:3],    1'b0 } & {21{w_chr_rden   }}
                   | { 4'b0010,     w_gfx_addr_bg[18:3], 1'b0 } & {21{w_gfx_rden[0]}}
                   | { 4'b0011,     w_gfx_addr_fg[18:3], 1'b0 } & {21{w_gfx_rden[1]}};
    end
    
    assign main_z80_rdata = w_chr_rdata & {8{w_main_rd_D000}}
                          | w_ram_rdata & {8{w_main_rd_E000}}
                          | w_spr_rdata & {8{w_main_rd_F000}}
                          | w_reg_rdata
                          | r_rom_rdata;
    
    // ======================================================
    // Main Z80 ROM cache
    // ======================================================
    
    always@(posedge w_ram_rdy_n or posedge bus_clk) begin : MAIN_CACHE
        reg  [1:0] v_word_ctr;
        reg        v_bank_0_hit;
        reg        v_bank_1_hit;
        reg [15:0] v_addr;
    
        if (w_ram_rdy_n) begin
            r_addr_b0      <= 21'd0;
            r_rden_b0      <= 1'b0;
            r_main_dtack   <= 1'b0;
            r_rom_rdata    <= 8'h00;
            r_main_raddr_0 <= 12'hFFF;
            r_main_raddr_1 <= 14'h3FFF;
            v_word_ctr     <= 2'd0;
            v_bank_0_hit   <= 1'b0;
            v_bank_1_hit   <= 1'b0;
            v_addr         <= 16'h0000;
        end
        else begin
            // SDRAM read enable and SDRAM data valid
            /*
            if (main_z80_rden) begin
                casez (main_z80_addr[15:14])
                    2'b0? : begin // 32 KB ROM
                        r_addr_b0    <= { 8'b00000000, main_z80_addr[14:3], 1'b0 };
                        r_rden_b0    <= ~v_bank_0_hit;
                        r_main_dtack <=  v_bank_0_hit;
                        r_rom_rdata  <= r_main_rdata_0[main_z80_addr[2:0]];
                    end
                    2'b10 : begin // 16 KB banked ROM
                    
                        r_addr_b0    <= { 6'b000001, w_main_bank, main_z80_addr[13:3], 1'b0 };
                        r_rden_b0    <= ~v_bank_1_hit;
                        r_main_dtack <=  v_bank_1_hit;
                        r_rom_rdata  <= r_main_rdata_1[main_z80_addr[2:0]];
                    end
                    2'b11 : begin // RAM and registers
                        r_addr_b0    <= { 6'b000001, w_main_bank, main_z80_addr[13:3], 1'b0 };
                        r_rden_b0    <= 1'b0;
                        r_main_dtack <= 1'b1;
                        r_rom_rdata  <= 8'h00;
                    end
                endcase
            end
            else begin
                r_rden_b0    <= 1'b0;
                r_main_dtack <= (main_z80_addr[15:14] == 2'b11) ? main_z80_wren : 1'b0;
            end
            */
            casez (v_addr[15:14])
                2'b0? : begin // 32 KB ROM
                    r_addr_b0    <= { 8'b00000000, v_addr[14:3], 1'b0 };
                    r_rden_b0    <= ~v_bank_0_hit;
                    r_main_dtack <=  v_bank_0_hit; // & main_z80_rden;
                    r_rom_rdata  <= r_main_rdata_0[v_addr[2:0]];
                end
                2'b10 : begin // 16 KB banked ROM
                
                    r_addr_b0    <= { 6'b000001, w_main_bank, v_addr[13:3], 1'b0 };
                    r_rden_b0    <= ~v_bank_1_hit;
                    r_main_dtack <=  v_bank_1_hit; // & main_z80_rden;
                    r_rom_rdata  <= r_main_rdata_1[v_addr[2:0]];
                end
                2'b11 : begin // RAM and registers
                    r_addr_b0    <= { 6'b000001, w_main_bank, v_addr[13:3], 1'b0 };
                    r_rden_b0    <= 1'b0;
                    r_main_dtack <= 1'b1; //main_z80_rden | main_z80_wren;
                    r_rom_rdata  <= 8'h00;
                end
            endcase
            
            // Cache loading
            if (w_valid_b0) begin
                if (~v_bank_0_hit & ~v_addr[15]) begin
                    // Load cache line #0
                    r_main_rdata_0[0] <= r_main_rdata_0[2];
                    r_main_rdata_0[1] <= r_main_rdata_0[3];
                    r_main_rdata_0[2] <= r_main_rdata_0[4];
                    r_main_rdata_0[3] <= r_main_rdata_0[5];
                    r_main_rdata_0[4] <= r_main_rdata_0[6];
                    r_main_rdata_0[5] <= r_main_rdata_0[7];
                    r_main_rdata_0[6] <= w_rdata_b0[7:0];
                    r_main_rdata_0[7] <= w_rdata_b0[15:8];
                    if (v_word_ctr == 2'd2)
                        r_main_raddr_0 <= v_addr[14:3];
                end
                if (~v_bank_1_hit & v_addr[15] & ~v_addr[14]) begin
                    // Load cache line #1
                    r_main_rdata_1[0] <= r_main_rdata_1[2];
                    r_main_rdata_1[1] <= r_main_rdata_1[3];
                    r_main_rdata_1[2] <= r_main_rdata_1[4];
                    r_main_rdata_1[3] <= r_main_rdata_1[5];
                    r_main_rdata_1[4] <= r_main_rdata_1[6];
                    r_main_rdata_1[5] <= r_main_rdata_1[7];
                    r_main_rdata_1[6] <= w_rdata_b0[7:0];
                    r_main_rdata_1[7] <= w_rdata_b0[15:8];
                    if (v_word_ctr == 2'd2)
                        r_main_raddr_1 <= { w_main_bank, v_addr[13:3] };
                end
                v_word_ctr <= v_word_ctr + 2'd1;
            end
            
            // Cache hit in range 0x0000 - 0x7FFF
            v_bank_0_hit <= (r_main_raddr_0 ==                main_z80_addr[14:3]  ) ? 1'b1 : 1'b0;
            // Cache hit in range 0x8000 - 0xBFFF
            v_bank_1_hit <= (r_main_raddr_1 == { w_main_bank, main_z80_addr[13:3] }) ? 1'b1 : 1'b0;
            // Delayed Z80 address
            v_addr <= main_z80_addr;
        end
    end
    
    assign main_z80_dtack = r_main_dtack;
    assign main_z80_rst_n = ~w_ram_rdy_n;
    
    // ======================================================
    // SDRAM controller
    // ======================================================
    
    sdram_ctrl
    #(
        .SDRAM_SIZE    (SDRAM_SIZE),
        .SDRAM_WIDTH   (SDRAM_WIDTH)
    )
    U_sdram_ctrl
    (
        .rst           (bus_rst),
        .clk           (bus_clk),
        
        .ram_rdy_n     (w_ram_rdy_n),
        .ram_ref       (w_ram_ref),
        .ram_cyc       (w_ram_cyc),
        .ram_ph        (w_ram_ph),
        .ram_ph_ctr    (w_ram_ph_ctr),
        // Bank #0 : Main Z80
        .rden_b0       (r_rden_b0),
        .wren_b0       (1'b0),
        .addr_b0       (r_addr_b0),
        .fetch_b0      (/* open */),
        .valid_b0      (w_valid_b0),
        .rdata_b0      (w_rdata_b0),
        .wdata_b0      (16'h0000),
        .bena_b0       (2'b11),
        // Bank #1 : Sprites
        .rden_b1       (w_spr_rden),
        .wren_b1       (1'b0),
        .addr_b1       ({ 5'd0, w_spr_addr, 1'b0 }),
        .fetch_b1      (/* open */),
        .valid_b1      (w_valid_b1),
        .rdata_b1      (w_rdata_b1),
        .wdata_b1      (16'h0000),
        .bena_b1       (2'b11),
        // Bank #2 : Audio Z80
        .rden_b2       (1'b0),
        .wren_b2       (1'b1),
        .addr_b2       (21'h000000),
        .fetch_b2      (/* open */),
        .valid_b2      (w_valid_b2),
        .rdata_b2      (w_rdata_b2),
        .wdata_b2      (16'h1234),
        .bena_b2       (2'b11),
        // Bank #3 : Tilemaps
        .rden_b3       (r_rden_b3),
        .wren_b3       (1'b0),
        .addr_b3       (r_addr_b3),
        .fetch_b3      (/* open */),
        .valid_b3      (w_valid_b3),
        .rdata_b3      (w_rdata_b3),
        .wdata_b3      (16'h0000),
        .bena_b3       (2'b11),
        // SDRAM chip interface
        .sdram_cs_n    (sdram_cs_n),
        .sdram_ras_n   (sdram_ras_n),
        .sdram_cas_n   (sdram_cas_n),
        .sdram_we_n    (sdram_we_n),
        .sdram_ba      (sdram_ba),
        .sdram_addr    (sdram_addr),
        .sdram_dqm_n   (sdram_dqm_n),
        .sdram_dq_oe   (sdram_dq_oe),
        .sdram_dq_o    (sdram_dq_o),
        .sdram_dq_i    (sdram_dq_i)
    );
    
    // ======================================================
    
    mem_dc_4096x8to8r U_ram_4KB
    (
        .wrclock           (bus_clk),
        .wren              (w_main_wr_E000),
        .wraddress         (main_z80_addr[11:0]),
        .data              (main_z80_wdata),
        .rdclock           (bus_clk),
        .rden              (w_main_rd_E000),
        .rdaddress         (main_z80_addr[11:0]),
        .q                 (w_ram_rdata)
    );
    
    // ======================================================
    
    assign w_reg_rd[0] = w_main_rd_C000;
    assign w_reg_rd[1] = w_main_rd_C001;
    assign w_reg_rd[2] = w_main_rd_C002;
    assign w_reg_rd[3] = w_main_rd_C003;
    assign w_reg_rd[4] = w_main_rd_C004;
    assign w_reg_rd[5] = w_main_rd_C007;
    
    assign w_reg_wr[0] = w_main_wr_C807;
    assign w_reg_wr[1] = w_main_wr_D807;
    
    gpu_gpios U_gpu_gpios
    (
        .bus_rst           (w_ram_rdy_n),
        .bus_clk           (bus_clk),

        .bus_eof           (w_bus_eof),

        .reg_rd            (w_reg_rd),
        .reg_wr            (w_reg_wr),

        .reg_wdata         (main_z80_wdata),
        .reg_rdata         (w_reg_rdata),

        .start_n           (start_n),
        .coin_n            (coin_n),
        .joy1_n            (joy1_n),
        .joy2_n            (joy2_n),
        .dip_sw_A          (8'b11101000),
        .dip_sw_B          (8'b11111111),

        .cfg_prom_wren     (w_cfg_prom_wren),
        .cfg_scale_2x_on   (w_cfg_scale_2x_on),
        .cfg_scan_line_h   (w_cfg_scan_line_h),
        .cfg_scan_line_v   (w_cfg_scan_line_v)
    );
    
    assign main_vbl_int = w_bus_eof;
    
    // ======================================================
    
    gpu_vbeam U_gpu_vbeam
    (
        .bus_rst       (w_ram_rdy_n),
        .bus_clk       (bus_clk),
        
        .ram_ref       (w_ram_ref),
        .ram_cyc       (w_ram_cyc),
        .ram_ph        (w_ram_ph),
        .ram_ph_ctr    (w_ram_ph_ctr),
        
        .bus_eol       (w_bus_eol),
        .bus_eof       (w_bus_eof),
        .bus_vpos      (w_bus_vpos),
        .bus_dma_ena   (w_bus_dma_ena),
        .bus_frd_ena   (w_bus_frd_ena),
        .bus_dma_fline (w_bus_dma_fl),
        .bus_dma_lline (w_bus_dma_ll),
        
        .vid_rst       (vid_rst),
        .vid_clk       (vid_clk),
        .vid_clk_ena   (w_vid_clk_ena),
        
        .vid_eol       (w_vid_eol),
        .vid_hpos      (/* open */),
        .vid_vpos      (w_vid_vpos),
        .vid_hsync     (vga_hs),
        .vid_vsync     (vga_vs),
        .vid_dena      (w_vid_dena) 
    );
    
    assign w_seq_wr[0] = w_main_wr_C804;
    assign w_seq_wr[1] = w_main_wr_D806;
    
    gpu_dmaseq U_gpu_dmaseq
    (
        .rst           (w_ram_rdy_n),
        .clk           (bus_clk),
        
        .reg_wr        (w_seq_wr),
        .reg_wdata     (main_z80_wdata),
        
        .ram_ref       (w_ram_ref),
        .ram_cyc       (w_ram_cyc),
        .ram_ph        (w_ram_ph),
        .ram_ph_ctr    (w_ram_ph_ctr),
        
        .z80_bank      (w_main_bank),
        .z80_cpu       (main_z80_ena),
        .z80_aud       (audio_z80_ena),
        
        .chr_gfx       (w_chr_ena),
        
        .scr_map       (w_map_ena), 
        .scr_gfx       (w_gfx_ena),
        
        .spr_gfx       (w_spr_ena),
        .spr_clr       (w_spr_clr)
    );
    
    // ======================================================
    
    assign w_bgn_wr[0] = w_main_wr_D803;
    assign w_bgn_wr[1] = w_main_wr_D804;
    assign w_bgn_wr[2] = 1'b0;
    
    gpu_tilemap U_gpu_bg_tilemap
    (
        .rst           (w_ram_rdy_n),
        .clk           (bus_clk),
        
        .reg_wr        (w_bgn_wr),
        .reg_wdata     (main_z80_wdata),
        
        .bus_dma_ena   (w_bus_dma_ena),
        .bus_eol       (w_bus_eol),
        
        .ram_cyc       (w_ram_cyc),
        .ram_ph        (w_ram_ph),
        .ram_ph_ctr    (w_ram_ph_ctr),
        
        .map_dma_ena   (w_map_ena[0]),
        .map_dma_addr  (w_map_addr_bg),
        .map_dma_rden  (w_map_rden[0]),
        .map_data_vld  (w_valid_b3 & w_map_rden[0]),
        .map_data      (w_rdata_b3),
        
        .gfx_dma_ena   (w_gfx_ena[0]),
        .gfx_dma_addr  (w_gfx_addr_bg),
        .gfx_dma_rden  (w_gfx_rden[0]),
        .gfx_data_vld  (w_valid_b3 & w_gfx_rden[0]),
        .gfx_data      (w_rdata_b3),
        
        .vid_line      (w_vid_line),
        .vid_read      (w_bgn_read),
        .vid_next      (w_bgn_next),
        .vid_data      (w_bgn_data),
        .vid_vld       (w_bgn_vld)
    );
    
    assign dbg_bgn_data = w_bgn_data[3:0];
    assign dbg_bgn_vld  = w_bgn_vld;

    assign w_fgn_wr[0] = w_main_wr_D800;
    assign w_fgn_wr[1] = w_main_wr_D801;
    assign w_fgn_wr[2] = w_main_wr_D802;
    
    gpu_tilemap U_gpu_fg_tilemap
    (
        .rst           (w_ram_rdy_n),
        .clk           (bus_clk),
        
        .reg_wr        (w_fgn_wr),
        .reg_wdata     (main_z80_wdata),
        
        .bus_dma_ena   (w_bus_dma_ena),
        .bus_eol       (w_bus_eol),
        
        .ram_cyc       (w_ram_cyc),
        .ram_ph        (w_ram_ph),
        .ram_ph_ctr    (w_ram_ph_ctr),
        
        .map_dma_ena   (w_map_ena[1]),
        .map_dma_addr  (w_map_addr_fg),
        .map_dma_rden  (w_map_rden[1]),
        .map_data_vld  (w_valid_b3 & w_map_rden[1]),
        .map_data      (w_rdata_b3),
        
        .gfx_dma_ena   (w_gfx_ena[1]),
        .gfx_dma_addr  (w_gfx_addr_fg),
        .gfx_dma_rden  (w_gfx_rden[1]),
        .gfx_data_vld  (w_valid_b3 & w_gfx_rden[1]),
        .gfx_data      (w_rdata_b3),
        
        .vid_line      (w_vid_line),
        .vid_read      (w_fgn_read),
        .vid_next      (w_fgn_next),
        .vid_data      (w_fgn_data),
        .vid_vld       (w_fgn_vld)
    );
    
    assign dbg_fgn_data = w_fgn_data[3:0];
    assign dbg_fgn_vld  = w_fgn_vld;
    
    gpu_sprites U_gpu_sprites
    (
        .rst           (w_ram_rdy_n),
        .clk           (bus_clk),
        
        .reg_rd        (w_main_rd_F000),
        .reg_wr        (w_main_wr_F000),
        .reg_addr      (main_z80_addr[11:0]),
        .reg_wdata     (main_z80_wdata),
        .reg_rdata     (w_spr_rdata),
        
        .bus_dma_ena   (w_bus_dma_ena),
        .bus_vpos      (w_bus_vpos),
        .bus_eol       (w_bus_eol),
        
        .ram_cyc       (w_ram_cyc),
        .ram_ph        (w_ram_ph),
        .ram_ph_ctr    (w_ram_ph_ctr),
        
        .spr_fifo_clr  (w_spr_clr),
        .spr_dma_ena   (w_spr_ena),
        .spr_dma_addr  (w_spr_addr),
        .spr_dma_rden  (w_spr_rden),
        .spr_data_vld  (w_valid_b1),
        .spr_data      (w_rdata_b1),
        
        .vid_line      (w_vid_line),
        .vid_read      (w_spr_read),
        .vid_next      (w_spr_next),
        .vid_layer     (w_spr_layer),
        .vid_data_0    (w_spr_data_0),
        .vid_data_1    (w_spr_data_1),
        .vid_vld       (w_spr_vld)
    );
    
    gpu_charmap U_gpu_charmap
    (
        .rst           (w_ram_rdy_n),
        .clk           (bus_clk),
        
        .reg_rd        (w_main_rd_D000),
        .reg_wr        (w_main_wr_D000),
        .reg_addr      (main_z80_addr[10:0]),
        .reg_wdata     (main_z80_wdata),
        .reg_rdata     (w_chr_rdata),
        
        .bus_dma_ena   (w_bus_dma_ena),
        .bus_vpos      (w_bus_vpos),
        .bus_eol       (w_bus_eol),
        
        .ram_cyc       (w_ram_cyc),
        .ram_ph        (w_ram_ph),
        .ram_ph_ctr    (w_ram_ph_ctr),
        
        .chr_dma_ena   (w_chr_ena), 
        .chr_dma_addr  (w_chr_addr),
        .chr_dma_rden  (w_chr_rden),
        .chr_data_vld  (w_valid_b3 & w_chr_rden),
        .chr_data      (w_rdata_b3),
        
        .vid_line      (w_vid_line),
        .vid_read      (w_chr_read),
        .vid_next      (w_chr_next),
        .vid_data      (w_chr_data),
        .vid_vld       (w_chr_vld)
    );
    
    assign dbg_chr_data = w_chr_data[3:0];
    assign dbg_chr_vld  = w_chr_vld;
    
    // ======================================================
    
    gpu_colormux U_gpu_colormux
    (
        .rst           (w_ram_rdy_n),
        .clk           (bus_clk),
        
        .s2x_bypass    (~w_cfg_scale_2x_on),
        
        .prom_wr       (w_prom_bmp_wr),
        .prom_addr     ({ w_cfg_prom_wren[0], main_z80_addr[9:0] }),
        .prom_wdata    (main_z80_wdata),
        
        .bus_eol       (w_bus_eol),
        .bus_eof       (w_bus_eof),
        .bus_frd_ena   (w_bus_frd_ena),
        .bus_dma_fline (w_bus_dma_fl),
        .bus_dma_lline (w_bus_dma_ll),
        
        .ram_cyc       (w_ram_cyc),
        
        .vid_line      (w_vid_line),
        
        .bgn_read      (w_bgn_read),
        .bgn_next      (w_bgn_next),
        .bgn_data      (w_bgn_data),
        .bgn_vld       (w_bgn_vld),
        
        .fgn_read      (w_fgn_read),
        .fgn_next      (w_fgn_next),
        .fgn_data      (w_fgn_data),
        .fgn_vld       (w_fgn_vld),
        
        .spr_read      (w_spr_read),
        .spr_next      (w_spr_next),
        .spr_layer     (w_spr_layer),
        .sp0_data      (w_spr_data_0),
        .sp0_vld       (w_spr_vld[0]),
        .sp1_data      (w_spr_data_1),
        .sp1_vld       (w_spr_vld[1]),
        
        .chr_read      (w_chr_read),
        .chr_next      (w_chr_next),
        .chr_data      (w_chr_data),
        .chr_vld       (w_chr_vld),
        
        .pix_data      (w_pix_data),
        .pix_data_vld  (w_pix_data_vld)
    );
    
    // ======================================================
    
    gpu_scandoubler U_gpu_scandoubler
    (
        .bus_rst       (w_ram_rdy_n),
        .bus_clk       (bus_clk),
        
        .scanlines_h   (w_cfg_scan_line_h),
        .scanlines_v   (w_cfg_scan_line_v),
        
        .prom_wr       (w_prom_pal_wr),
        .prom_addr     ({ w_cfg_prom_wren[0], main_z80_addr[9:0] }),
        .prom_wdata    (main_z80_wdata),
        
        .bus_eol       (w_bus_eol),
        .bus_vpos      (w_bus_vpos),
        
        .bus_pix_data  (w_pix_data),
        .bus_pix_vld   (w_pix_data_vld),
        
        .vid_rst       (vid_rst),
        .vid_clk       (vid_clk),
        .vid_clk_ena   (w_vid_clk_ena),
        
        .vid_eol       (w_vid_eol),
        .vid_dena      (w_vid_dena),
        .vid_vpos      (w_vid_vpos),
        
        .vid_r         (vga_r),
        .vid_g         (vga_g),
        .vid_b         (vga_b),
        .vid_de        (vga_de)
    );
    
    // ======================================================
    
endmodule
