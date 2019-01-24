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

module gpu_gpios
(
    input         bus_rst,
    input         bus_clk,
    
    input         bus_eof,
    
    input   [5:0] reg_rd,
    input   [1:0] reg_wr,
    
    input   [7:0] reg_wdata,
    output  [7:0] reg_rdata,
    
    input   [1:0] start_n,
    input   [1:0] coin_n,
    input   [5:0] joy1_n,
    input   [5:0] joy2_n,
    input   [7:0] dip_sw_A,
    input   [7:0] dip_sw_B,
    
    output        cfg_scale_2x_on,
    output        cfg_scan_line_h,
    output        cfg_scan_line_v,
    output  [3:0] cfg_prom_wren
);
    // ======================================================
    // Register $C000 (Start, Coin, VBL)
    // ======================================================
    
    reg [7:0] r_reg_C000;

    always@(posedge bus_rst or posedge bus_clk) begin : REG_C000
        if (bus_rst) begin
            r_reg_C000 <= 8'b11110111;
        end
        else begin
            r_reg_C000[0] <= start_n[0]; // Start #1
            r_reg_C000[1] <= start_n[1]; // Start #2
            r_reg_C000[2] <= 1'b1;
            r_reg_C000[3] <= bus_eof;    // VBL interrupt
            r_reg_C000[4] <= 1'b1;
            r_reg_C000[5] <= 1'b1;
            r_reg_C000[6] <= coin_n[0];  // Coin #1
            r_reg_C000[7] <= coin_n[1];  // Coin #2
        end
    end

    // ======================================================
    // Register $C001 (Joystick #1)
    // ======================================================
    
    reg [7:0] r_reg_C001;

    always@(posedge bus_rst or posedge bus_clk) begin : REG_C001
        if (bus_rst) begin
            r_reg_C001 <= 8'b11111111;
        end
        else begin
            r_reg_C001[0] <= joy1_n[0]; // Right
            r_reg_C001[1] <= joy1_n[1]; // Left
            r_reg_C001[2] <= joy1_n[2]; // Down
            r_reg_C001[3] <= joy1_n[3]; // Up
            r_reg_C001[4] <= joy1_n[4]; // Button #1
            r_reg_C001[5] <= joy1_n[5]; // Button #2
            r_reg_C001[6] <= 1'b1;
            r_reg_C001[7] <= 1'b1;
        end
    end
    
    // ======================================================
    // Register $C002 (Joystick #2)
    // ======================================================
    
    reg [7:0] r_reg_C002;

    always@(posedge bus_rst or posedge bus_clk) begin : REG_C002
        if (bus_rst) begin
            r_reg_C002 <= 8'b11111111;
        end
        else begin
            r_reg_C002[0] <= joy2_n[0]; // Right
            r_reg_C002[1] <= joy2_n[1]; // Left
            r_reg_C002[2] <= joy2_n[2]; // Down
            r_reg_C002[3] <= joy2_n[3]; // Up
            r_reg_C002[4] <= joy2_n[4]; // Button #1
            r_reg_C002[5] <= joy2_n[5]; // Button #2
            r_reg_C002[6] <= 1'b1;
            r_reg_C002[7] <= 1'b1;
        end
    end
    
    // ======================================================
    // Registers $C003 & $C004 (DIP switches)
    // ======================================================
    
    reg [7:0] r_reg_C003;
    reg [7:0] r_reg_C004;
    
    always@(posedge bus_clk) begin : REG_C003_C004
        r_reg_C003 <= dip_sw_A;
        r_reg_C004 <= dip_sw_B;
    end
    
    // ======================================================
    // Registers $C007 & $C807 (Security chip)
    // ======================================================
    
    reg [7:0] r_reg_C007;
    reg [7:0] r_reg_C807;
    
    always@(posedge bus_rst or posedge bus_clk) begin : REG_C007_C807
        if (bus_rst) begin
            r_reg_C007 <= 8'b00000000;
            r_reg_C807 <= 8'b00000000;
        end
        else begin
            // "Security" chip
            r_reg_C007[7] <=  r_reg_C807[6] &  r_reg_C807[1] & ~r_reg_C807[0]
                           |  r_reg_C807[6] &  r_reg_C807[5] &  r_reg_C807[2] &  r_reg_C807[0]
                           | ~r_reg_C807[4] &  r_reg_C807[2] &  r_reg_C807[1] &  r_reg_C807[0]
                           | ~r_reg_C807[5] &  r_reg_C807[3] & ~r_reg_C807[2] &  r_reg_C807[1]
                           | ~r_reg_C807[4] & ~r_reg_C807[3] & ~r_reg_C807[2] & ~r_reg_C807[1];
            r_reg_C007[6] <=  r_reg_C807[6] &  r_reg_C807[3] &  r_reg_C807[2]
                           |  r_reg_C807[4] & ~r_reg_C807[3] &  r_reg_C807[2]
                           |  r_reg_C807[4] & ~r_reg_C807[3] & ~r_reg_C807[1]
                           |  r_reg_C807[4] & ~r_reg_C807[3] & ~r_reg_C807[0]
                           |  r_reg_C807[6] & ~r_reg_C807[4] & ~r_reg_C807[2]
                           | ~r_reg_C807[7] &  r_reg_C807[5] &  r_reg_C807[3] & ~r_reg_C807[2];
            r_reg_C007[5] <=  r_reg_C807[7] &  r_reg_C807[4]
                           |  r_reg_C807[5] &  r_reg_C807[2] &  r_reg_C807[1]
                           | ~r_reg_C807[3] &  r_reg_C807[2] &  r_reg_C807[1]
                           | ~r_reg_C807[5] & ~r_reg_C807[2] & ~r_reg_C807[0]
                           |  r_reg_C807[5] & ~r_reg_C807[3] &  r_reg_C807[1] &  r_reg_C807[0]
                           | ~r_reg_C807[6] &  r_reg_C807[4] &  r_reg_C807[2] &  r_reg_C807[0]
                           | ~r_reg_C807[6] & ~r_reg_C807[4] & ~r_reg_C807[3] & ~r_reg_C807[2]
                           | ~r_reg_C807[4] & ~r_reg_C807[3] & ~r_reg_C807[2] & ~r_reg_C807[1];
            r_reg_C007[4] <= ~r_reg_C807[4] & ~r_reg_C807[0]
                           | ~r_reg_C807[7] &  r_reg_C807[6] &  r_reg_C807[0]
                           |  r_reg_C807[5] & ~r_reg_C807[2] &  r_reg_C807[1]
                           |  r_reg_C807[3] &  r_reg_C807[2] & ~r_reg_C807[0]
                           | ~r_reg_C807[7] &  r_reg_C807[3] & ~r_reg_C807[1];
            r_reg_C007[3] <= ~r_reg_C807[6] &  r_reg_C807[2] &  r_reg_C807[1]
                           | ~r_reg_C807[7] &  r_reg_C807[3] & ~r_reg_C807[0]
                           | ~r_reg_C807[7] & ~r_reg_C807[6] &  r_reg_C807[4] &  r_reg_C807[3]
                           | ~r_reg_C807[7] & ~r_reg_C807[6] & ~r_reg_C807[1] & ~r_reg_C807[0]
                           | ~r_reg_C807[6] & ~r_reg_C807[4] & ~r_reg_C807[3] & ~r_reg_C807[2];
            r_reg_C007[2] <=  r_reg_C807[6] &  r_reg_C807[4] &  r_reg_C807[3]
                           |  r_reg_C807[5] & ~r_reg_C807[3] &  r_reg_C807[0]
                           | ~r_reg_C807[4] & ~r_reg_C807[3] & ~r_reg_C807[2]
                           | ~r_reg_C807[7] &  r_reg_C807[5] &  r_reg_C807[4] &  r_reg_C807[2]
                           | ~r_reg_C807[7] & ~r_reg_C807[6] & ~r_reg_C807[4] & ~r_reg_C807[1];
            r_reg_C007[1] <=  r_reg_C807[2] &  r_reg_C807[1] &  r_reg_C807[0]
                           |  r_reg_C807[3] &  r_reg_C807[1] &  r_reg_C807[0]
                           | ~r_reg_C807[6] & ~r_reg_C807[5] &  r_reg_C807[2]
                           | ~r_reg_C807[6] &  r_reg_C807[3] & ~r_reg_C807[1]
                           |  r_reg_C807[6] & ~r_reg_C807[3] & ~r_reg_C807[0]
                           |  r_reg_C807[5] & ~r_reg_C807[4] & ~r_reg_C807[3] & ~r_reg_C807[2]
                           |  r_reg_C807[5] & ~r_reg_C807[2] & ~r_reg_C807[1] & ~r_reg_C807[0];
            r_reg_C007[0] <=  r_reg_C807[3] &  r_reg_C807[2] & ~r_reg_C807[1]
                           | ~r_reg_C807[6] &  r_reg_C807[4] &  r_reg_C807[2]
                           | ~r_reg_C807[6] &  r_reg_C807[2] & ~r_reg_C807[0]
                           | ~r_reg_C807[4] &  r_reg_C807[3] & ~r_reg_C807[1]
                           |  r_reg_C807[5] &  r_reg_C807[4] & ~r_reg_C807[3] &  r_reg_C807[1]
                           |  r_reg_C807[5] & ~r_reg_C807[4] & ~r_reg_C807[2] & ~r_reg_C807[1];
            
            if (reg_wr[0])
               r_reg_C807 <= reg_wdata;
        end
    end
    
    // ======================================================
    // Read multiplexer
    // ======================================================
    
    reg [7:0] r_reg_rdata;
    
    always@(posedge bus_clk) begin : READ_MUX
        r_reg_rdata <= r_reg_C000 & {8{reg_rd[0]}}
                     | r_reg_C001 & {8{reg_rd[1]}}
                     | r_reg_C002 & {8{reg_rd[2]}}
                     | r_reg_C003 & {8{reg_rd[3]}}
                     | r_reg_C004 & {8{reg_rd[4]}}
                     | r_reg_C007 & {8{reg_rd[5]}};
    end
    
    assign reg_rdata = r_reg_rdata;
    
    // ======================================================
    // Special register
    // ======================================================
    
    reg [1:0] r_cfg_fsm;
    reg [3:0] r_cfg_reg;
    reg [3:0] r_cfg_wren;
    
    always@(posedge bus_rst or posedge bus_clk) begin : REG_SPECIAL
        if (bus_rst) begin
            r_cfg_fsm  <= 2'd0;
            r_cfg_reg  <= 4'b0100;
            r_cfg_wren <= 4'd0;
        end
        else begin
            if (reg_wr[1]) begin
                case (r_cfg_fsm)
                    2'd0 : if (reg_wdata == 8'h19) r_cfg_fsm <= 2'd1;
                    2'd1 : if (reg_wdata == 8'h43) r_cfg_fsm <= 2'd2;
                    2'd2 : if (reg_wdata == 8'hFD) r_cfg_fsm <= 2'd3;
                    2'd3 : begin
                        if (reg_wdata[7])
                            r_cfg_reg[reg_wdata[1:0]] <= reg_wdata[6];
                        else
                            r_cfg_wren <= reg_wdata[3:0];
                        r_cfg_fsm <= 2'd0;
                    end
                endcase
            end
        end
    end
    
    assign cfg_scale_2x_on = r_cfg_reg[0];
    assign cfg_scan_line_h = r_cfg_reg[1];
    assign cfg_scan_line_v = r_cfg_reg[2];
    
    assign cfg_prom_wren   = r_cfg_wren;
    
    // ======================================================
    
endmodule
