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

module gpu_scandoubler
(
    // Clock and reset (bus)
    input         bus_rst,         // Bus reset
    input         bus_clk,         // Bus clock (72 MHz)
    // Scanline effect
    input         scanlines_h,     // Horizontal scan lines effect
    input         scanlines_v,     // Vertical scan lines effect
    // Z80 write access to palette PROM
    input         prom_wr,         // PROM write strobe
    input  [10:0] prom_addr,       // PROM address (2 KB range)
    input   [7:0] prom_wdata,      // PROM write data
    // Clock and reset (video)
    input         bus_eol,         // Bus end-of-line
    input   [8:0] bus_vpos,        // Bus vertical pos
    
    input  [31:0] bus_pix_data,    // Pixel data
    input         bus_pix_vld,     // Pixel data valid
    
    input         vid_rst,         // Video reset
    input         vid_clk,         // Video clock (108 MHz)
    input         vid_clk_ena,     // Video clock enable
    
    input         vid_eol,         // Video end-of-line
    input         vid_dena,        // Display enable
    input  [10:0] vid_vpos,        // Vertical position (0 - 1047)
    
    output  [3:0] vid_r,           // Red gun
    output  [3:0] vid_g,           // Green gun
    output  [3:0] vid_b,           // Blue gun
    output        vid_de           // Display enable
);

    // ========================================================
    // Line FIFO write control
    // ========================================================
    
    reg  [7:0] r_fifo_waddr; // 16 - 240
    
    always @(posedge bus_rst or posedge bus_clk) begin : FIFO_WRITE
    
        if (bus_rst) begin
            r_fifo_waddr <= 8'd16;
        end
        else begin
            if (bus_eol)
                r_fifo_waddr <= 8'd16;
            else if (bus_pix_vld)
                r_fifo_waddr <= r_fifo_waddr + 8'd1;
        end
    end

    // ========================================================
    // 2-line FIFO
    // ========================================================
    
    wire  [8:0] w_fifo_waddr;
    wire [10:0] w_fifo_raddr_p0;
    wire  [7:0] w_fifo_q_p2;
    
    assign w_fifo_waddr[8]   = bus_vpos[0];
    assign w_fifo_waddr[7:0] = r_fifo_waddr;
    
    assign w_fifo_raddr_p0[10]  = vid_vpos[2];
    assign w_fifo_raddr_p0[9:2] = r_fifo_raddr_p0[8:1];
    assign w_fifo_raddr_p0[1]   = vid_vpos[1];
    assign w_fifo_raddr_p0[0]   = r_fifo_raddr_p0[0];
    
    mem_dc_512x32to8r U_line_fifo
    (
        // Write port
        .wrclock   (bus_clk),
        .wren      (bus_pix_vld),
        .wraddress (w_fifo_waddr),
        .data      (bus_pix_data),
        // Read port
        .rdclock   (vid_clk),
        .rden      (1'b1),
        .rdaddress (w_fifo_raddr_p0),
        .q         (w_fifo_q_p2)
    );
    
    // ========================================================
    // Line FIFO read control
    // ========================================================
    
    reg  [4:0] r_read_fsm_p0;
    reg  [8:0] r_fifo_raddr_p0; // 0 - 511
    reg  [1:0] r_pal_sel_p1;
    reg  [1:0] r_pal_sel_p2;
    
    reg  [3:0] r_dena_p4;
    reg  [1:0] r_ctr_p4;
    
    always @(posedge vid_rst or posedge vid_clk) begin : FIFO_READ
        reg v_next;
    
        if (vid_rst) begin
            r_read_fsm_p0   <= 5'b00001;
            r_fifo_raddr_p0 <= 9'd0;
            r_pal_sel_p1    <= 2'b00;
            r_pal_sel_p2    <= 2'b00;
            r_dena_p4       <= 4'b0000;
            r_ctr_p4        <= 2'd0;
        end
        else begin
            if (vid_eol) begin
                r_read_fsm_p0   <= 5'b00001;
                r_fifo_raddr_p0 <= 9'd0;
            end
            else if (vid_dena & vid_clk_ena) begin
                v_next = ((|r_read_fsm_p0[1:0]) && (&r_fifo_raddr_p0[4:0])
                       || ( r_read_fsm_p0[2]  ) && (&r_fifo_raddr_p0[8:0])
                       || (|r_read_fsm_p0[4:3]) && (&r_fifo_raddr_p0[4:0])) ? 1'b1 : 1'b0;
                if (v_next)
                    r_read_fsm_p0 <= { r_read_fsm_p0[3:0], r_read_fsm_p0[4] };
                r_fifo_raddr_p0[4:0] <= r_fifo_raddr_p0[4:0] + 5'd1;
                if (&r_fifo_raddr_p0[4:0] & r_read_fsm_p0[2])
                    r_fifo_raddr_p0[8:5] <= r_fifo_raddr_p0[8:5] + 4'd1;
            end
            
            if (scanlines_v) begin
                // Vertical scanlines :
                // --------------------
                // 0 1 0 1 0 1 0 1 : vid_clk_ena
                // 0 0 1 1 0 0 1 1 : r_fifo_raddr_p0[0]
                // 0 0 0 0 1 1 1 1 : r_fifo_raddr_p0[1]
                //
                // 3 1 1 3 2 0 0 2
                // 2 0 0 2 3 1 1 3
                // 3 1 1 3 2 0 0 2
                // 2 0 0 2 3 1 1 3
                // 3 1 1 3 2 0 0 2
                // 2 0 0 2 3 1 1 3
                // 3 1 1 3 2 0 0 2
                // 2 0 0 2 3 1 1 3
                r_pal_sel_p1[0] <= ~(r_fifo_raddr_p0[1] ^ vid_vpos[0]);
                r_pal_sel_p1[1] <= ~(r_fifo_raddr_p0[0] ^ vid_clk_ena);
            end
            else if (scanlines_h) begin
                // Horizontal scanlines :
                // ----------------------
                // 0 1 0 1 0 1 0 1 : vid_clk_ena
                // 0 0 1 1 0 0 1 1 : r_fifo_raddr_p0[0]
                // 0 0 0 0 1 1 1 1 : r_fifo_raddr_p0[1]
                //
                // 2 3 2 3 2 3 2 3
                // 0 1 0 1 0 1 0 1
                // 0 1 0 1 0 1 0 1
                // 2 3 2 3 2 3 2 3
                // 3 2 3 2 3 2 3 2
                // 1 0 1 0 1 0 1 0
                // 1 0 1 0 1 0 1 0
                // 3 2 3 2 3 2 3 2
                r_pal_sel_p1[0] <=   vid_clk_ena ^ vid_vpos[2];
                r_pal_sel_p1[1] <= ~(vid_vpos[0] ^ vid_vpos[1]);
            end
            else begin
                r_pal_sel_p1[0] <= 1'b1;
                r_pal_sel_p1[1] <= 1'b0;
            end
            r_pal_sel_p2    <= r_pal_sel_p1;
            
            r_dena_p4 <= { r_dena_p4[2:0], vid_dena };
        end
    end
    
    // ========================================================
    // Palette PROM
    // ========================================================
    
    wire [15:0] w_pal_prom_q_p4;
    
    mem_dc_2048x8to16r
    #(
        .INIT_FILE ("pal_prom.mem")
    )
    U_pal_prom
    (
        // Z80 access
        .clock_a   (bus_clk),
        .rden_a    (1'b0),
        .wren_a    (prom_wr),
        .address_a (prom_addr),
        .data_a    (prom_wdata),
        .q_a       (/* open */),
        // GPU access
        .clock_b   (vid_clk),
        .rden_b    (1'b1),
        .wren_b    (1'b0),
        .address_b ({ w_fifo_q_p2, r_pal_sel_p2 }),
        .data_b    (16'h0000),
        .q_b       (w_pal_prom_q_p4)
    );
    
    // ========================================================
    // CRT emulation
    // ========================================================
    
    reg   [3:0] r_vid_r_p5;
    reg   [3:0] r_vid_g_p5;
    reg   [3:0] r_vid_b_p5;
    reg         r_vid_de_p5;
    
    reg   [3:0] r_vid_r_p6;
    reg   [3:0] r_vid_g_p6;
    reg   [3:0] r_vid_b_p6;
    reg         r_vid_de_p6;
    
    always@(posedge vid_clk) begin : SCAN_LINES
        if (r_dena_p4[3]) begin
            r_vid_r_p5 <= w_pal_prom_q_p4[3:0];
            r_vid_g_p5 <= w_pal_prom_q_p4[7:4];
            r_vid_b_p5 <= w_pal_prom_q_p4[11:8];
        end
        else begin
            r_vid_r_p5 <= 4'h0;
            r_vid_g_p5 <= 4'h0;
            r_vid_b_p5 <= 4'h0;
        end
        r_vid_de_p5 <= r_dena_p4[3];
        
        r_vid_r_p6  <= r_vid_r_p5;
        r_vid_g_p6  <= r_vid_g_p5;
        r_vid_b_p6  <= r_vid_b_p5;
        r_vid_de_p6 <= r_vid_de_p5;
    end
    
    assign vid_r  = r_vid_r_p6;
    assign vid_g  = r_vid_g_p6;
    assign vid_b  = r_vid_b_p6;
    assign vid_de = r_vid_de_p6;
    
endmodule
