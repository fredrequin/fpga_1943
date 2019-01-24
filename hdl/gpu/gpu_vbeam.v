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

module gpu_vbeam
(
    input         bus_rst,         // Bus reset
    input         bus_clk,         // Bus clock (72 MHz)
    
    input         ram_ref,         // SDRAM refresh active
    input   [3:0] ram_cyc,         // SDRAM cycles
    input   [3:0] ram_ph,          // SDRAM phases
    input   [8:0] ram_ph_ctr,      // SDRAM phase counter
    
    output        bus_eol,         // Bus end-of-line
    output        bus_eof,         // Bus end-of-frame
    output  [8:0] bus_vpos,        // Bus vertical pos
    output        bus_dma_ena,     // Bus DMAs enable
    output        bus_frd_ena,     // Bus FIFOs read enable
    output        bus_dma_fline,   // Bus DMA first line
    output        bus_dma_lline,   // Bus DMA last line
    
    input         vid_rst,         // Video reset
    input         vid_clk,         // Video clock (108 MHz)
    output        vid_clk_ena,     // Video clock enable
    
    output        vid_eol,         // Video end-of-line
    output  [9:0] vid_hpos,        // Horizontal position (0 - 857)
    output [10:0] vid_vpos,        // Vertical position (0 - 1047)
    output        vid_hsync,       // Horizontal synchro
    output        vid_vsync,       // Vertical synchro
    output        vid_dena         // Display enable
);

    // Bus timing :
    // ------------
    // 72 MHz bus clock (3 x 24)
    // 286 phases / line (line rate : 15734 Hz)
    // 4 bank access / phase
    // 4 clocks / bank access
    // 4576 clocks / line
    // 263 lines / frame
    
    // 128 sprites / line
    // 572 Z80 access / line
    // 2 x 4 map access / line
    // 2 x 16 tile access / line
    // 32 char access / line
    
    // Video timing :
    // --------------
    // 108 MHz pixel clock (4.5 x 24)
    // 1716 clocks / line (line rate : 62937 Hz)
    // 1052 lines / frame
    // 59.826 Hz frame rate

    // =============================================
    // Vertical position : 0 - 262 (bus clock)
    // =============================================
    
    reg [8:0] r_bus_vpos; // Vertical position
    reg       r_bus_eof;  // End of frame
    reg       r_bus_eol;  // End of line
    reg       r_bus_frd;  // FIFO read enable
    reg       r_bus_fl;   // First line
    reg       r_bus_ll;   // Last line
    
    always@(posedge bus_rst or posedge bus_clk) begin : BUS_VPOS
        reg       v_ref_dly;
        reg [2:0] v_dma_dly;
    
        if (bus_rst) begin
            r_bus_vpos <= 9'd256;
            r_bus_eof  <= 1'b0;
            r_bus_eol  <= 1'b0;
            r_bus_frd  <= 1'b0;
            r_bus_fl   <= 1'b0;
            r_bus_ll   <= 1'b0;
            v_ref_dly  <= 1'b0;
            v_dma_dly  <= 3'b000;
        end
        else begin
            // Vertical position
            if (r_bus_eol) begin
                r_bus_vpos <= (r_bus_vpos == 9'd262) ? 9'd0 : r_bus_vpos + 9'd1;
            end
            // End of frame
            if (r_bus_eol) begin
                r_bus_eof  <= (r_bus_vpos[2:0] == 3'b001) ? r_bus_vpos[8] : 1'b0;
            end
            // End of line
            if (ram_ph[3] & ram_cyc[2]) begin
                r_bus_eol <= ram_ref & ~v_ref_dly;
                v_ref_dly <= ram_ref;
            end
            else begin
                r_bus_eol <= 1'b0;
            end
            // FIFOs read enable
            if (ram_ph[3] & ram_cyc[3]) begin
                if (ram_ph_ctr == 9'd3)
                    r_bus_frd <= v_dma_dly[1];
                else if (ram_ph_ctr == 9'd283)
                    r_bus_frd <= 1'b0;

                    // First line read
                r_bus_fl <= v_dma_dly[1] & ~v_dma_dly[2];
                // Last line read
                r_bus_ll <= v_dma_dly[1] & ~v_dma_dly[0];
            end
            if (r_bus_eol)
                v_dma_dly <= { v_dma_dly[1:0], ~r_bus_vpos[8] };
        end
    end
    
    assign bus_eol       = r_bus_eol;
    assign bus_eof       = r_bus_eof;
    assign bus_vpos      = r_bus_vpos;
    assign bus_dma_ena   = ~r_bus_vpos[8];
    assign bus_frd_ena   = r_bus_frd;
    assign bus_dma_fline = r_bus_fl;
    assign bus_dma_lline = r_bus_ll;

    // =============================================
    // Vertical position   : 0 - 1051 (video clock)
    // Horizontal position : 0 -  857 (video clock)
    // =============================================
    
    reg [10:0] r_vid_vpos;    // Vertical position
    reg  [9:0] r_vid_hpos;    // Horizontal position
    reg        r_vid_eol;     // End of line
    reg        r_vid_lock;    // Video locked
    reg        r_vid_clk_ena; // Clock enable
    
    always@(posedge vid_rst or posedge vid_clk) begin : VID_HVPOS
        reg [1:0] v_ref_cc;
        reg [1:0] v_ref_dly;
        reg [1:0] v_eof_cc;
        reg [1:0] v_eof_dly;
    
        if (vid_rst) begin
            r_vid_vpos    <= 11'd1024;
            r_vid_hpos    <= 10'd0;
            r_vid_eol     <= 1'b0;
            r_vid_lock    <= 1'b0;
            r_vid_clk_ena <= 1'b0;
            v_ref_cc      <= 2'b00;
            v_ref_dly     <= 2'b00;
            v_eof_cc      <= 2'b00;
            v_eof_dly     <= 2'b00;
        end
        else begin
            if (r_vid_clk_ena) begin
                if (r_vid_lock) begin
                    // Vertical position
                    if (r_vid_eol) begin
                        r_vid_vpos <= (r_vid_vpos == 11'd1051) ? 11'd0 : r_vid_vpos + 11'd1;
                    end
                    // Horizontal position
                    if (r_vid_eol)
                        r_vid_hpos <= 10'd0;
                    else
                        r_vid_hpos <= r_vid_hpos + 10'd1;
                    r_vid_eol  <= (r_vid_hpos == 10'd856) ? 1'b1 : 1'b0;
                end
                // Lock signal on end of frame
                if ((v_ref_dly == 2'b01) && (v_eof_dly == 2'b11)) begin
                    r_vid_lock <= 1'b1;
                end
                // Delayed signal
                v_ref_dly <= { v_ref_dly[0], v_ref_cc[1] };
                v_eof_dly <= { v_eof_dly[0], v_eof_cc[1] };
            end
            r_vid_clk_ena <= ~r_vid_clk_ena;
            // Clock domain crossing (72 MHz -> 54 MHz)
            v_ref_cc <= { v_ref_cc[0], ram_ref };
            v_eof_cc <= { v_eof_cc[0], r_bus_eof };
        end
    end
    
    assign vid_eol     = r_vid_eol;
    assign vid_hpos    = r_vid_hpos;
    assign vid_vpos    = r_vid_vpos;
    assign vid_clk_ena = r_vid_clk_ena;
    
    // =============================================
    // Vertical synchro   : 7 lines
    // Horizontal synchro : 68 cycles
    // Display enable     : 640 cycles
    // =============================================
    
    reg        r_vid_vsync;  // Vertical synchro
    reg        r_vid_hsync;  // Horizontal synchro
    reg        r_vid_dena;   // Display enable
    
    always@(posedge vid_rst or posedge vid_clk) begin : VID_HVSYNC
        reg        v_vsstrt;
        reg        v_vsstop;
        reg        v_hsstop;
        reg        v_destrt;
        reg        v_destop;
        
        if (vid_rst) begin
          r_vid_vsync <= 1'b0;
          r_vid_hsync <= 1'b0;
          r_vid_dena  <= 1'b0;
          v_vsstrt    <= 1'b0;
          v_vsstop    <= 1'b0;
          v_hsstop    <= 1'b0;
          v_destrt    <= 1'b0;
          v_destop    <= 1'b0;
        end
        else begin
            if (r_vid_clk_ena) begin
                // Vertical synchro (line 1027 - 1033)
                if (r_vid_eol) begin
                    if (v_vsstrt)
                       r_vid_vsync <= 1'b1;
                    else if (v_vsstop)
                       r_vid_vsync <= 1'b0;
                end
                v_vsstrt <= (r_vid_vpos == 11'd1026) ? 1'b1 : 1'b0;
                v_vsstop <= (r_vid_vpos == 11'd1033) ? 1'b1 : 1'b0;
                
                // Horizontal synchro (cycles 0 - 67)
                if (r_vid_eol)
                    r_vid_hsync <= 1'b1;
                else if (v_hsstop)
                    r_vid_hsync <= 1'b0;
                v_hsstop <= (r_vid_hpos == 10'd66) ? 1'b1 : 1'b0;
                
                // Display enable (cycles 171 - 810 & lines 0 - 1023)
                // -6 cycles to compensate for the 6-cycle latency in the scandoubler
                if (v_destrt)
                    r_vid_dena  <= ~r_vid_vpos[10];
                else if (v_destop)
                    r_vid_dena  <= 1'b0;
                v_destrt <= (r_vid_hpos == 10'd169) ? 1'b1 : 1'b0;
                v_destop <= (r_vid_hpos == 10'd809) ? 1'b1 : 1'b0;
            end
        end
    end
    
    assign vid_dena  =  r_vid_dena;
    assign vid_hsync = ~r_vid_hsync;
    assign vid_vsync =  r_vid_vsync;

endmodule
