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

`timescale 1 ns / 1 ps

module sdram_ctrl
(
    //-----------------------------
    // Clock and reset
    //-----------------------------
    input         rst,             // Global reset
    input         clk,             // Master clock (72 MHz)
    
    output        ram_rdy_n,       // SDRAM ready
    output        ram_ref,         // SDRAM refresh
    output  [3:0] ram_cyc,         // SDRAM cycles
    output  [3:0] ram_ph,          // SDRAM phases
    output  [8:0] ram_ph_ctr,      // Phase counter
    
    //-----------------------------
    // Access bank #0
    //-----------------------------
    input         rden_b0,         // Read enable
    input         wren_b0,         // Write enable
    input  [22:2] addr_b0,         // Address (up to 8 MB)
    output        valid_b0,        // Read data valid
    output        fetch_b0,        // Write data fetch
    output [15:0] rdata_b0,        // Read data
    input  [15:0] wdata_b0,        // Write data
    input   [1:0] bena_b0,         // Byte enable
    
    //-----------------------------
    // Access bank #1
    //-----------------------------
    input         rden_b1,         // Read enable
    input         wren_b1,         // Write enable
    input  [22:2] addr_b1,         // Address (up to 8 MB)
    output        valid_b1,        // Read data valid
    output        fetch_b1,        // Write data fetch
    output [15:0] rdata_b1,        // Read data
    input  [15:0] wdata_b1,        // Write data
    input   [1:0] bena_b1,         // Byte enable
    
    //-----------------------------
    // Access bank #2
    //-----------------------------
    input         rden_b2,         // Read enable
    input         wren_b2,         // Write enable
    input  [22:2] addr_b2,         // Address (up to 8 MB)
    output        valid_b2,        // Read data valid
    output        fetch_b2,        // Write data fetch
    output [15:0] rdata_b2,        // Read data
    input  [15:0] wdata_b2,        // Write data
    input   [1:0] bena_b2,         // Byte enable
    
    //-----------------------------
    // Access bank #3
    //-----------------------------
    input         rden_b3,         // Read enable
    input         wren_b3,         // Write enable
    input  [22:2] addr_b3,         // Address (up to 8 MB)
    output        valid_b3,        // Read data valid
    output        fetch_b3,        // Write data fetch
    output [15:0] rdata_b3,        // Read data
    input  [15:0] wdata_b3,        // Write data
    input   [1:0] bena_b3,         // Byte enable
    
    //-----------------------------
    // SDRAM memory signals
    //-----------------------------
    output            sdram_cs_n,  // SDRAM chip select
    output reg        sdram_ras_n, // SDRAM row address strobe
    output reg        sdram_cas_n, // SDRAM column address strobe
    output reg        sdram_we_n,  // SDRAM write enable
    //
    output reg  [1:0] sdram_ba,    // SDRAM bank address
    output reg [12:0] sdram_addr,  // SDRAM address
    //
    output reg  [3:0] sdram_dqm_n, // SDRAM DQ masks
    output reg        sdram_dq_oe, // SDRAM data output enable
    output reg [31:0] sdram_dq_o,  // SDRAM data output
    input      [31:0] sdram_dq_i   // SDRAM data input
);
    // SDRAM memory size (16 or 32 MB)
    parameter SDRAM_SIZE  = 16;
    // SDRAM memory width (16 or 32 bits)
    parameter SDRAM_WIDTH = 16;
    // Clock-to-output delay (for simulation)
    parameter Tco_dly = 4.5;
    // SDRAM commands
    localparam [2:0]
        CMD_LMR = 3'b000,
        CMD_REF = 3'b001,
        CMD_PRE = 3'b010,
        CMD_ACT = 3'b011,
        CMD_WR  = 3'b100,
        CMD_RD  = 3'b101,
        CMD_BST = 3'b110,
        CMD_NOP = 3'b111;
        
    // ======================================================
    // SDRAM sequencer control
    // ======================================================
    
    reg [3:0] r_ram_cyc;
    reg [3:0] r_ram_ph;
    reg [1:0] r_ba0_ctr;
    reg [1:0] r_ba1_ctr;
    reg [8:0] r_ph_ctr;
    reg [2:0] r_ini_ctr;
    reg       r_ref_ena;
    wire      w_bus_eol;
    
    assign w_bus_eol = r_ph_ctr[8] & r_ph_ctr[5] & r_ram_ph[3]; // 288
    
    always@(posedge rst or posedge clk) begin : SEQUENCER_CTRL
        
        if (rst) begin
            r_ram_cyc <= 4'b0001;
            r_ram_ph  <= 4'b0001;
            r_ba0_ctr <= 2'd0;
            r_ba1_ctr <= 2'd3;
            r_ph_ctr  <= 9'd3;
            r_ini_ctr <= 3'd0;
            r_ref_ena <= 1'b0;
        end
        else begin
            r_ram_cyc <= { r_ram_cyc[2:0], r_ram_cyc[3] };
            if (r_ram_cyc[3]) begin
                r_ram_ph  <= { r_ram_ph[2:0], r_ram_ph[3] };
                r_ba0_ctr <= r_ba0_ctr + 2'd1;
                r_ba1_ctr <= r_ba1_ctr + 2'd1;
                // Phase counter : 3 - 288
                if (r_ram_ph[3]) begin
                    r_ph_ctr <= (w_bus_eol) ? 9'd3 : r_ph_ctr + 9'd1;
                end
                // Initialization done after 4 scanlines
                if (w_bus_eol & r_ram_ph[3] & ~r_ini_ctr[2])
                    r_ini_ctr <= r_ini_ctr + 3'd1;
                // Refreshes are enabled during phase 284 - 288
                r_ref_ena <= r_ph_ctr[8] & (r_ph_ctr[5] | &r_ph_ctr[4:2]);
            end
        end
    end
    
    assign ram_ref    = r_ref_ena;
    assign ram_cyc    = r_ram_cyc;
    assign ram_ph     = r_ram_ph;
    assign ram_ph_ctr = r_ph_ctr;
    assign ram_rdy_n  = ~r_ini_ctr[2];
    
    // ======================================================
    // SDRAM phase generation
    // ======================================================
    
    reg [3:0] r_rd_act;
    reg [3:0] r_wr_act;
    
    reg       r_act_ph; // Activate phase
    reg       r_rd_ph;  // Burst read phase
    reg       r_wr_ph;  // Burst write phase
    reg       r_ref_ph; // Auto-refresh phase
    reg [3:0] r_ini_ph; // Initialization phases
    reg       r_pre_ph; // Precharge phase
    reg       r_lmr_ph; // Load mode register phase
    
    always@(posedge rst or posedge clk) begin : PHASE_GEN
    
        if (rst) begin
            r_rd_act <= 4'b0000;
            r_wr_act <= 4'b0000;
            
            r_act_ph <= 1'b0;
            r_rd_ph  <= 1'b0;
            r_wr_ph  <= 1'b0;
            r_ref_ph <= 1'b0;
            r_ini_ph <= 4'b0000;
            r_pre_ph <= 1'b0;
            r_lmr_ph <= 1'b0;
        end
        else begin
            if (r_ram_cyc[0]) begin
                // Access port #0 read/write
                if (r_ram_ph[0]) begin
                    r_rd_act[0] <= rden_b0 & ~r_ref_ena;
                    r_wr_act[0] <= wren_b0 & ~r_ref_ena & ~rden_b0;
                end
                else if (r_ram_ph[2]) begin
                    r_rd_act[0] <= 1'b0;
                    r_wr_act[0] <= 1'b0;
                end
                // Access port #1 read/write
                if (r_ram_ph[1]) begin
                    r_rd_act[1] <= rden_b1 & ~r_ref_ena;
                    r_wr_act[1] <= wren_b1 & ~r_ref_ena & ~rden_b1;
                end
                else if (r_ram_ph[3]) begin
                    r_rd_act[1] <= 1'b0;
                    r_wr_act[1] <= 1'b0;
                end
                // Access port #2 read/write
                if (r_ram_ph[2]) begin
                    r_rd_act[2] <= rden_b2 & ~r_ref_ena;
                    r_wr_act[2] <= wren_b2 & ~r_ref_ena & ~rden_b2;
                end
                else if (r_ram_ph[0]) begin
                    r_rd_act[2] <= 1'b0;
                    r_wr_act[2] <= 1'b0;
                end
                // Access port #3 read/write
                if (r_ram_ph[3]) begin
                    r_rd_act[3] <= rden_b3 & ~r_ref_ena;
                    r_wr_act[3] <= wren_b3 & ~r_ref_ena & ~rden_b3;
                end
                else if (r_ram_ph[1]) begin
                    r_rd_act[3] <= 1'b0;
                    r_wr_act[3] <= 1'b0;
                end
            end
            
            if (r_ram_cyc[0] & r_ini_ctr[2]) begin
                // Activate phase
                r_act_ph <= (r_ram_ph[0] & (rden_b0 | wren_b0) & ~r_ref_ena)
                          | (r_ram_ph[1] & (rden_b1 | wren_b1) & ~r_ref_ena)
                          | (r_ram_ph[2] & (rden_b2 | wren_b2) & ~r_ref_ena)
                          | (r_ram_ph[3] & (rden_b3 | wren_b3) & ~r_ref_ena);
            end
            
            if (r_ram_cyc[3] & r_ini_ctr[2]) begin
                // Read phase
                r_rd_ph  <= (r_ram_ph[0] & r_rd_act[0])
                          | (r_ram_ph[1] & r_rd_act[1])
                          | (r_ram_ph[2] & r_rd_act[2])
                          | (r_ram_ph[3] & r_rd_act[3]);
                // Write phase
                r_wr_ph  <= (r_ram_ph[0] & r_wr_act[0])
                          | (r_ram_ph[1] & r_wr_act[1])
                          | (r_ram_ph[2] & r_wr_act[2])
                          | (r_ram_ph[3] & r_wr_act[3]);
            end

            // Initialization phases (0:PRE, 1:REF, 2:REF, 3:LMR)
            if (r_ram_cyc[3] & r_ram_ph[2]) begin
                if (r_ref_ena & r_ini_ctr[0] & r_ini_ctr[1]) begin
                    r_ini_ph <= { r_ini_ph[2:0], ~|r_ini_ph };
                end
                else begin
                    r_ini_ph <= 4'b0000;
                end
            end
            
            // Precharge phase
            r_pre_ph <= r_ini_ph[0] & r_ram_ph[0];
            
            // Refresh phase
            r_ref_ph <= r_ref_ena & r_ini_ctr[2] & (r_ram_ph[0] | r_ram_ph[2]) & r_ph_ctr[8] // Normal
                      | (r_ini_ph[1] | r_ini_ph[2]) & r_ram_ph[0];                           // Init
            
            // Load mode register phase
            r_lmr_ph <= r_ini_ph[3] & r_ram_ph[0];
            
        end
    end
    
    // ======================================================
    // SDRAM address generation
    // ======================================================
    
    reg  [22:2] r_addr_mux;
    reg  [10:2] r_addr_col;
    reg  [12:0] r_addr_sdr;
    reg   [1:0] r_ba_sdr;

    always@(posedge rst or posedge clk) begin : ADDRESS_GEN
    
        if (rst) begin
            r_addr_mux <= 21'd0;
            r_addr_col <= 9'd0;
            r_addr_sdr <= 13'd0;
            r_ba_sdr   <= 2'b00;
        end
        else begin
            // Port address multiplexer
            if (r_ram_cyc[0]) begin
                r_addr_mux <= addr_b0 & {21{r_ram_ph[0] & (rden_b0 | wren_b0) }}
                            | addr_b1 & {21{r_ram_ph[1] & (rden_b1 | wren_b1) }}
                            | addr_b2 & {21{r_ram_ph[2] & (rden_b2 | wren_b2) }}
                            | addr_b3 & {21{r_ram_ph[3] & (rden_b3 | wren_b3) }};
            end

            // Column address (for read/write op.)
            if (r_ram_cyc[3]) begin
                r_addr_col <= r_addr_mux[10:2];
            end
            
            // Memories layouts :
            // ------------------
            // SDRAM  4M x 32b (128 Mb) : 4 banks x 4096 rows x 256 cols x 32 bits
            // SDRAM  8M x 32b (256 Mb) : 4 banks x 4096 rows x 512 cols x 32 bits
            // SDRAM  8M x 16b (128 Mb) : 4 banks x 4096 rows x 512 cols x 16 bits
            // SDRAM 16M x 16b (256 Mb) : 4 banks x 8192 rows x 512 cols x 16 bits
    
            // Row / col address
            if (SDRAM_WIDTH == 32) begin
                // 32-bit bus
                if (SDRAM_SIZE == 32) begin
                    // 32 MB
                    r_addr_sdr <= { 4'b0000,  r_addr_col[10: 3], 1'b0 } & {13{r_rd_ph  & r_ram_cyc[0]}}  //  512 cols
                                | { 1'b0,     r_addr_mux[22:11]       } & {13{r_act_ph & r_ram_cyc[1]}}  // 4096 rows
                                | { 4'b0010,  r_addr_col[10: 3], 1'b1 } & {13{r_rd_ph  & r_ram_cyc[2]}}  //  512 cols
                                | { 4'b0010,  r_addr_col[10: 2]       } & {13{r_wr_ph  & r_ram_cyc[3]}}  //  512 cols
                                | { 3'b001,             10'b000000000 } & {13{r_ini_ph[0]            }}  // Init : precharge all
                                | { 3'b000,        10'b1_00_010_0_000 } & {13{r_ini_ph[3]            }}; // Init : load mode register (BL=1, CAS=2)
                end
                else begin
                    // 16 MB
                    r_addr_sdr <= { 5'b00000, r_addr_col[ 9: 3], 1'b0 } & {13{r_rd_ph  & r_ram_cyc[0]}}  //  256 cols
                                | { 1'b0,     r_addr_mux[21:10]       } & {13{r_act_ph & r_ram_cyc[1]}}  // 4096 rows
                                | { 5'b00100, r_addr_col[ 9: 3], 1'b1 } & {13{r_rd_ph  & r_ram_cyc[2]}}  //  256 cols
                                | { 5'b00100, r_addr_col[ 9: 2]       } & {13{r_wr_ph  & r_ram_cyc[3]}}  //  256 cols
                                | { 3'b001,             10'b000000000 } & {13{r_ini_ph[0]            }}  // Init : precharge all
                                | { 3'b000,        10'b1_00_010_0_000 } & {13{r_ini_ph[3]            }}; // Init : load mode register (BL=1, CAS=2)
                end
            end
            else begin
                // 16-bit bus
                if (SDRAM_SIZE == 32) begin
                    // 32 MB
                    r_addr_sdr <= { 4'b0000, r_addr_col[9:3], 2'b00 } & {13{r_rd_ph  & r_ram_cyc[0]}}  //  512 cols
                                |            r_addr_mux[22:10]        & {13{r_act_ph & r_ram_cyc[1]}}  // 8192 rows
                                | { 4'b0010, r_addr_col[9:3], 2'b10 } & {13{r_rd_ph  & r_ram_cyc[2]}}  //  512 cols
                                | { 4'b0010, r_addr_col[9:2],  1'b0 } & {13{r_wr_ph  & r_ram_cyc[3]}}  //  512 cols
                                | { 3'b001,           10'b000000000 } & {13{r_ini_ph[0]            }}  // Init : precharge all
                                | { 3'b000,      10'b1_00_010_0_001 } & {13{r_ini_ph[3]            }}; // Init : load mode register (BL=2, CAS=2)
                end
                else begin
                    // 16 MB
                    r_addr_sdr <= { 4'b0000, r_addr_col[9:3], 2'b00 } & {13{r_rd_ph  & r_ram_cyc[0]}}  //  512 cols
                                | { 1'b0,    r_addr_mux[21:10]      } & {13{r_act_ph & r_ram_cyc[1]}}  // 4096 rows
                                | { 4'b0010, r_addr_col[9:3], 2'b10 } & {13{r_rd_ph  & r_ram_cyc[2]}}  //  512 cols
                                | { 4'b0010, r_addr_col[9:2],  1'b0 } & {13{r_wr_ph  & r_ram_cyc[3]}}  //  512 cols
                                | { 3'b001,           10'b000000000 } & {13{r_ini_ph[0]            }}  // Init : precharge all
                                | { 3'b000,      10'b1_00_010_0_001 } & {13{r_ini_ph[3]            }}; // Init : load mode register (BL=2, CAS=2)
                end
            end
            
            // Bank address
            r_ba_sdr   <= r_ba1_ctr & {2{r_rd_ph  & r_ram_cyc[0]}}  // 32-bit read
                        | r_ba0_ctr & {2{r_act_ph & r_ram_cyc[1]}}  // Activate
                        | r_ba1_ctr & {2{r_rd_ph  & r_ram_cyc[2]}}  // 32-bit read with auto-precharge
                        | r_ba1_ctr & {2{r_wr_ph  & r_ram_cyc[3]}}; // 32-bit write with auto-precharge
        end
    end
    
    // ======================================================
    // SDRAM command generation
    // ======================================================
    
    reg  [2:0] r_cmd_sdr;
        
    always@(posedge rst or posedge clk) begin : COMMAND_GEN
        reg [2:0] v_cmd_0;
        reg [2:0] v_cmd_1;
        reg [2:0] v_cmd_2;
        reg [2:0] v_cmd_3;
        reg [2:0] v_cmd_4;
        reg [2:0] v_cmd_5;
        reg [2:0] v_cmd_6;
    
        if (rst) begin
            r_cmd_sdr <= CMD_NOP;
        end
        else begin
            v_cmd_0 = CMD_RD  | {3{~r_rd_ph }};
            v_cmd_1 = CMD_ACT | {3{~r_act_ph}};
            v_cmd_2 = CMD_RD  | {3{~r_rd_ph }};
            v_cmd_3 = CMD_WR  | {3{~r_wr_ph }};
            v_cmd_4 = CMD_PRE | {3{~r_pre_ph}};
            v_cmd_5 = CMD_REF | {3{~r_ref_ph}};
            v_cmd_6 = CMD_LMR | {3{~r_lmr_ph}};
            
            r_cmd_sdr <= (v_cmd_0 | {3{~r_ram_cyc[0]}})
                       & (v_cmd_1 | {3{~r_ram_cyc[1]}})
                       & (v_cmd_2 | {3{~r_ram_cyc[2]}})
                       & (v_cmd_3 | {3{~r_ram_cyc[3]}})
                       & (v_cmd_4 | {3{~r_ram_cyc[3]}})
                       & (v_cmd_5 | {3{~r_ram_cyc[3]}})
                       & (v_cmd_6 | {3{~r_ram_cyc[3]}});
        end
    end
    
    assign sdram_cs_n  = 1'b0;
    
    // Command and address
    /* verilator lint_off STMTDLY */
    always@(*) sdram_ras_n = #Tco_dly r_cmd_sdr[2];
    always@(*) sdram_cas_n = #Tco_dly r_cmd_sdr[1];
    always@(*) sdram_we_n  = #Tco_dly r_cmd_sdr[0];
    always@(*) sdram_ba    = #Tco_dly r_ba_sdr;
    always@(*) sdram_addr  = #Tco_dly r_addr_sdr;
    /* verilator lint_on STMTDLY */
    
    // ======================================================
    // Data being read
    // ======================================================
    
    reg   [3:0] r_data_vld;
    reg         r_data_sel;
    
    reg  [15:0] r_lrdata_p0;
    reg  [15:0] r_hrdata_p0;
    reg  [15:0] r_hrdata_p1;
    wire [15:0] w_rdata_p0;
    
    always@(posedge rst or posedge clk) begin : DATA_READ
        if (rst) begin
            r_data_vld  <= 4'b0000;
            r_data_sel  <= 1'b0;
            r_lrdata_p0 <= 16'h0000;
            r_hrdata_p0 <= 16'h0000;
            r_hrdata_p1 <= 16'h0000;
        end
        else begin
            if (r_ram_cyc[3]) begin
                r_data_vld[0] <= r_rd_act[0] & r_ram_ph[1];
                r_data_vld[1] <= r_rd_act[1] & r_ram_ph[2];
                r_data_vld[2] <= r_rd_act[2] & r_ram_ph[3];
                r_data_vld[3] <= r_rd_act[3] & r_ram_ph[0];
            end
            r_data_sel  <= r_ram_cyc[1] | r_ram_cyc[3];
            r_lrdata_p0 <= sdram_dq_i[15:0];
            r_hrdata_p0 <= sdram_dq_i[31:16];
            r_hrdata_p1 <= r_hrdata_p0;
        end
    end
    
    // 32-bit to 16-bit multiplexer
    assign w_rdata_p0 = (r_data_sel) ? r_hrdata_p1 : r_lrdata_p0;
    
    // Access Port #0
    assign rdata_b0 = (SDRAM_WIDTH == 32) ? w_rdata_p0 : r_lrdata_p0;
    assign valid_b0 = r_data_vld[0];
    
    // Access Port #1
    assign rdata_b1 = (SDRAM_WIDTH == 32) ? w_rdata_p0 : r_lrdata_p0;
    assign valid_b1 = r_data_vld[1];
    
    // Access Port #2
    assign rdata_b2 = (SDRAM_WIDTH == 32) ? w_rdata_p0 : r_lrdata_p0;
    assign valid_b2 = r_data_vld[2];
    
    // Access Port #3
    assign rdata_b3 = (SDRAM_WIDTH == 32) ? w_rdata_p0 : r_lrdata_p0;
    assign valid_b3 = r_data_vld[3];
    
    // ======================================================
    // Data being written
    // ======================================================
    
    reg   [3:0] r_data_fe_p0;
    reg   [3:0] r_data_fe_p1;
    reg         r_data_oe;
    
    reg  [15:0] r_wdata_p2a;
    reg  [15:0] r_wdata_p2b;
    reg  [31:0] r_wdata_p3;
    
    reg   [1:0] r_bena_p2a;
    reg   [1:0] r_bena_p2b;
    reg   [3:0] r_bena_p3;
    
    always@(posedge rst or posedge clk) begin : DATA_WRITE
        if (rst) begin
            r_data_fe_p0 <= 4'b0000;
            r_data_fe_p1 <= 4'b0000;
            r_data_oe    <= 1'b0;
            r_wdata_p2a  <= 16'h0000;
            r_wdata_p2b  <= 16'h0000;
            r_wdata_p3   <= 32'h0000_0000;
            r_bena_p2a   <= 2'b00;
            r_bena_p2b   <= 2'b00;
            r_bena_p3    <= 4'b00_00;
        end
        else begin
            if (r_ram_cyc[3]) begin
                r_data_fe_p0 <= r_wr_act & r_ram_ph;
                r_data_oe    <= r_wr_ph;
            end
            else if (r_ram_cyc[1]) begin
                r_data_fe_p0 <= 4'b0000;
                r_data_oe    <= 1'b0;
            end
            r_data_fe_p1 <= r_data_fe_p0;
            
            if (SDRAM_WIDTH == 32) begin
                // 16-bit -> 32-bit bus
                if (r_data_sel) begin
                    r_wdata_p2b <= wdata_b0 & {16{r_data_fe_p1[0]}}
                                 | wdata_b1 & {16{r_data_fe_p1[1]}}
                                 | wdata_b2 & {16{r_data_fe_p1[2]}}
                                 | wdata_b3 & {16{r_data_fe_p1[3]}};
                    r_bena_p2b  <= bena_b0 & {2{r_data_fe_p1[0]}}
                                 | bena_b1 & {2{r_data_fe_p1[1]}}
                                 | bena_b2 & {2{r_data_fe_p1[2]}}
                                 | bena_b3 & {2{r_data_fe_p1[3]}}
                                 | {2{~|r_data_fe_p1}};
                end
                else begin
                    r_wdata_p2a <= wdata_b0 & {16{r_data_fe_p1[0]}}
                                 | wdata_b1 & {16{r_data_fe_p1[1]}}
                                 | wdata_b2 & {16{r_data_fe_p1[2]}}
                                 | wdata_b3 & {16{r_data_fe_p1[3]}};
                    r_bena_p2a  <= bena_b0 & {2{r_data_fe_p1[0]}}
                                 | bena_b1 & {2{r_data_fe_p1[1]}}
                                 | bena_b2 & {2{r_data_fe_p1[2]}}
                                 | bena_b3 & {2{r_data_fe_p1[3]}}
                                 | {2{~|r_data_fe_p1}};
                end
                r_wdata_p3  <= { r_wdata_p2b, r_wdata_p2a };
                r_bena_p3   <= { r_bena_p2b, r_bena_p2a };
            end
            else begin
                // 16-bit bus
                r_wdata_p2a <= wdata_b0 & {16{r_data_fe_p1[0]}}
                             | wdata_b1 & {16{r_data_fe_p1[1]}}
                             | wdata_b2 & {16{r_data_fe_p1[2]}}
                             | wdata_b3 & {16{r_data_fe_p1[3]}};
                r_wdata_p2b <= r_wdata_p2a;
                r_wdata_p3  <= { 16'h0000, r_wdata_p2b };
                
                r_bena_p2a  <= bena_b0 & {2{r_data_fe_p1[0]}}
                             | bena_b1 & {2{r_data_fe_p1[1]}}
                             | bena_b2 & {2{r_data_fe_p1[2]}}
                             | bena_b3 & {2{r_data_fe_p1[3]}}
                             | {2{~|r_data_fe_p1}};
                r_bena_p2b  <= r_bena_p2a;
                r_bena_p3   <= { 2'b00, r_bena_p2b };
            end
        end
    end
    
    // Output mask, data & enable
    /* verilator lint_off STMTDLY */
    always@(*) sdram_dqm_n = #Tco_dly ~r_bena_p3;
    always@(*) sdram_dq_o  = #Tco_dly r_wdata_p3;
    always@(*) sdram_dq_oe = #Tco_dly r_data_oe;
    /* verilator lint_on STMTDLY */
    
    // Access Port #0
    assign fetch_b0 = r_data_fe_p0[0];
    
    // Access Port #1
    assign fetch_b1 = r_data_fe_p0[1];
    
    // Access Port #2
    assign fetch_b2 = r_data_fe_p0[2];
    
    // Access Port #3
    assign fetch_b3 = r_data_fe_p0[3];
    
endmodule
