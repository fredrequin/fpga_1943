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

module gpu_scale2x
(
    input         rst,      // Global reset
    input         clk,      // Master clock (72 MHz)
    
    input         bypass,   // Scale2X bypass
    
    input   [1:0] opix_sel, // Pixel out select (0 - 3)
    
    input   [8:0] ipix_B,   // Pixel in position "B"
    input   [8:0] ipix_D,   // Pixel in position "D"
    input   [8:0] ipix_E,   // Pixel in position "E"
    input   [8:0] ipix_F,   // Pixel in position "F"
    input   [8:0] ipix_H,   // Pixel in position "H"
    input         ipix_en,  // Pixel in data enable
    
    output  [8:0] opix_Ex,  // Pixel out position "E0 - E3"
    output        opix_en   // Pixel out data enable
);
    /*
       +---+---+---+
       |   | B |   |
       +---+---+---+
       | D | E | F |
       +---+---+---+
       |   | H |   |
       +---+---+---+
       
           |
           V
    
       +---+---+
       |E0 |E1 | even line
       +---+---+
       |E2 |E3 | odd line
       +---+---+
       
    if (B != H && D != F)
    {
        // Even line
        E0 = (B == D) ? D : E;
        E1 = (B == F) ? F : E;
        // Odd line
        E2 = (H == D) ? D : E;
        E3 = (H == F) ? F : E;
    }
    else
    {
        // Even line
        E0 = E;
        E1 = E;
        // Odd line
        E2 = E;
        E3 = E;
    }
    */
    
    reg  [1:0] r_pix_en_p2;
    reg  [8:0] r_pix_Ex_p2;
    
    always @(posedge rst or posedge clk) begin : SCALE_2X
        reg  [8:0] v_pix_DF_p1;  // Left "D" or right "F" pixel
        reg  [8:0] v_pix_E_p1;   // Middle "E" pixel
        reg        v_B_equ_D_p1; // B == D
        reg        v_B_equ_F_p1; // B == F
        reg        v_H_equ_D_p1; // H == D
        reg        v_H_equ_F_p1; // H == F
        reg        v_B_equ_H_p1; // B == H
        reg        v_D_equ_F_p1; // D == F
        
        if (rst) begin
            r_pix_en_p2  <= 2'b00;
            r_pix_Ex_p2  <= 9'h000;
            v_pix_DF_p1  <= 9'h000;
            v_pix_E_p1   <= 9'h000;
            v_B_equ_D_p1 <= 1'b0;
            v_B_equ_F_p1 <= 1'b0;
            v_H_equ_D_p1 <= 1'b0;
            v_H_equ_F_p1 <= 1'b0;
            v_B_equ_H_p1 <= 1'b0;
            v_D_equ_F_p1 <= 1'b0;
        end
        else begin
            // Pixel data enable
            r_pix_en_p2 <= { r_pix_en_p2[0], ipix_en };
            
            // Scale2X algorithm
            if (v_B_equ_H_p1 | v_D_equ_F_p1 | bypass) begin
                r_pix_Ex_p2 <= v_pix_E_p1;
            end
            else begin
                if (v_B_equ_D_p1 | v_H_equ_D_p1 | v_B_equ_F_p1 | v_H_equ_F_p1)
                    r_pix_Ex_p2 <= v_pix_DF_p1;
                else
                    r_pix_Ex_p2 <= v_pix_E_p1;
            end
            
            // Pixels pipeline
            v_pix_DF_p1  <= (opix_sel[0]) ? ipix_F : ipix_D;
            v_pix_E_p1   <= ipix_E;
            
            // Pixels comparators
            v_B_equ_D_p1 <= ((ipix_B == ipix_D) && (opix_sel == 2'd0)) ? 1'b1 : 1'b0;
            v_B_equ_F_p1 <= ((ipix_B == ipix_F) && (opix_sel == 2'd1)) ? 1'b1 : 1'b0;
            v_H_equ_D_p1 <= ((ipix_H == ipix_D) && (opix_sel == 2'd2)) ? 1'b1 : 1'b0;
            v_H_equ_F_p1 <= ((ipix_H == ipix_F) && (opix_sel == 2'd3)) ? 1'b1 : 1'b0;
            v_B_equ_H_p1 <=  (ipix_B == ipix_H)                        ? 1'b1 : 1'b0;
            v_D_equ_F_p1 <=  (ipix_D == ipix_F)                        ? 1'b1 : 1'b0;
        end
    end
    
    assign opix_Ex = r_pix_Ex_p2;
    assign opix_en = r_pix_en_p2[1];
    
endmodule
