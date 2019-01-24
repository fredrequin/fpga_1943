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

module top_1943
(
    // Main bus (72 MHz clock)
    input         bus_rst,
    input         bus_clk,
    
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

    wire        w_main_ena;
    wire        w_main_vbl_int;
    reg         r_main_int_n;
    wire        w_main_m1_n;
    wire        w_main_mreq_n;
    wire        w_main_iorq_n;
    wire        w_main_rd_n;
    wire        w_main_wr_n;
    wire        w_main_rden;
    wire        w_main_wren;
    wire        w_main_dtack;
    wire        w_main_rst_n;

    wire [15:0] w_main_addr;
    wire  [7:0] w_main_rdata;
    wire  [7:0] w_main_wdata;
    
    tv80se
    #(
        .Mode    (0),
        .T2Write (1),
        .IOWait  (1)
    )
    U_main_z80
    (
        .reset_n (w_main_rst_n),
        .clk     (bus_clk),
        .clken   (w_main_ena),
        .wait_n  (w_main_dtack),
        .int_n   (r_main_int_n),
        .nmi_n   (1'b1),
        .busrq_n (1'b1),
        
        .m1_n    (w_main_m1_n),
        .mreq_n  (w_main_mreq_n),
        .iorq_n  (w_main_iorq_n),
        .rd_n    (w_main_rd_n),
        .wr_n    (w_main_wr_n),
        .rfsh_n  (/* open */),
        .halt_n  (/* open */),
        .busak_n (/* open */),
        .A       (w_main_addr),
        .di      (w_main_rdata),
        .dout    (w_main_wdata)
    );
    
    assign w_main_rden = ~(w_main_mreq_n | w_main_rd_n);
    assign w_main_wren = ~(w_main_mreq_n | w_main_wr_n);
    
    always@(posedge bus_rst or posedge bus_clk) begin : VBL_INT
        reg [1:0] v_vbl_dly;
        
        if (bus_rst) begin
            r_main_int_n <= 1'b1;
            v_vbl_dly     = 2'b00;
        end
        else if (w_main_ena) begin
            if (v_vbl_dly == 2'b01)
                r_main_int_n <= 1'b0;
            else if (~w_main_m1_n & ~w_main_iorq_n)
                r_main_int_n <= 1'b1;
            v_vbl_dly     = { v_vbl_dly[0], w_main_vbl_int };
        end
    end

    gpu_top
    #(
        .SDRAM_SIZE      (16),
        .SDRAM_WIDTH     (16)
    )
    U_gpu_top
    (
        .bus_rst         (bus_rst),
        .bus_clk         (bus_clk),
        
        .main_vbl_int    (w_main_vbl_int),
        .main_z80_rden   (w_main_rden),
        .main_z80_wren   (w_main_wren),
        .main_z80_addr   (w_main_addr),
        .main_z80_wdata  (w_main_wdata),
        .main_z80_rdata  (w_main_rdata),
        .main_z80_dtack  (w_main_dtack),
        .main_z80_ena    (w_main_ena),
        .main_z80_rst_n  (w_main_rst_n),
        
        .audio_z80_rden  (1'b0),
        .audio_z80_wren  (1'b0),
        .audio_z80_addr  (16'h0000),
        .audio_z80_wdata (8'h00),
        .audio_z80_rdata (/* open */),
        .audio_z80_dtack (/* open */),
        .audio_z80_ena   (/* open */),
        
        .start_n         (start_n),
        .coin_n          (coin_n),
        .joy1_n          (joy1_n),
        .joy2_n          (joy2_n),
        
        .sdram_cs_n      (sdram_cs_n),
        .sdram_ras_n     (sdram_ras_n),
        .sdram_cas_n     (sdram_cas_n),
        .sdram_we_n      (sdram_we_n),
        
        .sdram_ba        (sdram_ba),
        .sdram_addr      (sdram_addr),
        
        .sdram_dqm_n     (sdram_dqm_n),
        .sdram_dq_oe     (sdram_dq_oe),
        .sdram_dq_o      (sdram_dq_o),
        .sdram_dq_i      (sdram_dq_i),
        
        .dbg_bgn_data    (/* open */),
        .dbg_bgn_vld     (/* open */),
        .dbg_fgn_data    (/* open */),
        .dbg_fgn_vld     (/* open */),
        .dbg_chr_data    (/* open */),
        .dbg_chr_vld     (/* open */),
        
        .vid_rst         (vid_rst),
        .vid_clk         (vid_clk),
        
        .vga_hs          (vga_hs),
        .vga_vs          (vga_vs),
        .vga_de          (vga_de),
        .vga_r           (vga_r),
        .vga_g           (vga_g),
        .vga_b           (vga_b)
    );

endmodule
