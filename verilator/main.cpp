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

#include "Vtop_1943.h"
#include "verilated.h"
#include "clock_gen/clock_gen.h"
#include "sdr_sdram/sdr_sdram.h"
#include "video_out/video_out.h"

#if VM_TRACE
#include "verilated_vcd_c.h"
#endif

// Period for a 72 MHz clock
#define PERIOD_72MHz_ps    ((vluint64_t)13890)
// Period for a 108 MHz clock
#define PERIOD_108MHz_ps   ((vluint64_t)9260)
// SDRAM size
#define SDRAM_BIT_ROWS     (12)
#define SDRAM_BIT_COLS     (9)
#define SDRAM_SIZE         (2 << (SDRAM_BIT_ROWS + SDRAM_BIT_COLS + SDRAM_BIT_BANKS))

// Clocks generation (global)
ClockGen *clk;

int main(int argc, char **argv, char **env)
{
    // Simulation duration
    time_t beg, end;
    double secs;
    // Trace index
    int trc_idx = 0;
    int min_idx = 0;
    // File name generation
    char file_name[256];
    // Simulation steps
    vluint64_t tb_sstep;
    // Simulation time
    vluint64_t tb_time;
    vluint64_t max_time;
    // Testbench configuration
    const char *arg;
    // BUS_CLK counter
    vluint8_t bus_clk_ctr;
    // VID_CLK counter
    vluint8_t vid_clk_ctr;
    // SDRAM access
    vluint64_t sdram_q;
    vluint8_t sdram_flags;
    // VS trigger
    vluint8_t vs;

    beg = time(0);
    
    // Parse parameters
    Verilated::commandArgs(argc, argv);
    
    // Default : 1 msec
    max_time = (vluint64_t)1000000000;
    
    // Simulation duration : +usec=<num>
    arg = Verilated::commandArgsPlusMatch("usec=");
    if ((arg) && (arg[0]))
    {
        arg += 6;
        max_time = (vluint64_t)atoi(arg) * (vluint64_t)1000000;
    }
    
    // Simulation duration : +msec=<num>
    arg = Verilated::commandArgsPlusMatch("msec=");
    if ((arg) && (arg[0]))
    {
        arg += 6;
        max_time = (vluint64_t)atoi(arg) * (vluint64_t)1000000000;
    }
    
    // Trace start index : +tidx=<num>
    arg = Verilated::commandArgsPlusMatch("tidx=");
    if ((arg) && (arg[0]))
    {
        arg += 6;
        min_idx = atoi(arg);
    }
    else
    {
        min_idx = 0;
    }
    printf("+tidx=%d\n", min_idx);

    // Init top verilog instance
    Vtop_1943* top = new Vtop_1943;
    
    // Init SDRAM C++ model (4096 rows, 512 cols)
    sdram_flags = FLAG_DATA_WIDTH_16; // | FLAG_BANK_INTERLEAVING | FLAG_BIG_ENDIAN;
    SDRAM* sdr  = new SDRAM(SDRAM_BIT_ROWS, SDRAM_BIT_COLS, sdram_flags, NULL);
    // Load main program (32 kB + 128 KB)
    sdr->load("1943.01",  0x08000, 0x000000);
    sdr->load("1943.02",  0x10000, 0x020000);
    sdr->load("1943.03",  0x10000, 0x030000);
    // Load sprite graphics (256 KB)
    sdr->load("1943.spr", 0x40000, 0x400000);
    // Load background tiles (32 KB)
    sdr->load("1943.23",  0x08000, 0xC00000);
    // Load foreground tiles (32 KB)
    sdr->load("1943.14",  0x08000, 0xC08000);
    // Load characters (64 KB)
    sdr->load("1943.chr", 0x10000, 0xC10000);
    // Load background graphics (64 KB)
    sdr->load("1943.bgn", 0x10000, 0xD00000);
    // Load foreground graphics (256 KB)
    sdr->load("1943.fgn", 0x40000, 0xD80000);
    // Init VGA output C++ model
    VideoOut* vga = new VideoOut(0, 4, 0, 0, 1280, 0, 1024, "snapshot");
    
    // Initialize clock generator    
    clk = new ClockGen(2, max_time);
    // 72 MHz clock
    clk->NewClock(0, PERIOD_72MHz_ps, 0);
    clk->StartClock(0);
    // 108 MHz clock
    clk->NewClock(1, PERIOD_108MHz_ps, 0);
    clk->StartClock(1);
  
#if VM_TRACE
    // Init VCD trace dump
    Verilated::traceEverOn(true);
    VerilatedVcdC* tfp = new VerilatedVcdC;
    top->trace (tfp, 99);
    tfp->spTrace()->set_time_resolution ("1 ps");
    if (trc_idx == min_idx)
    {
        sprintf(file_name, "gpu_%04d.vcd", trc_idx);
        tfp->open (file_name);
    }
#endif /* VM_TRACE */
  
    // Initialize simulation inputs
    top->bus_rst = 1;
    top->bus_clk = 0;
    top->vid_rst = 1;
    top->vid_clk = 0;
    
    top->start_n = 0x03;
    top->coin_n  = 0x03;
    top->joy1_n  = 0x3F;
    top->joy2_n  = 0x3F;
  
    tb_sstep     = (vluint64_t)0;
    tb_time      = (vluint64_t)0;
    
    // Reset ON during 8 bus cycles / 12 video cycles
    for (int i = 0; i < 32; i ++)
    {
        // Toggle clock
        clk->AdvanceClocks();
        top->bus_clk = clk->GetClockStateDiv1(0, 0);
        top->vid_clk = clk->GetClockStateDiv1(1, 0);
        // Evaluate verilated model
        top->eval ();
#if VM_TRACE
        // Dump signals into VCD file
        if (tfp)
        {
            if (trc_idx >= min_idx)
            {
                tfp->dump (tb_time);
            }
        }
#endif /* VM_TRACE */
    }
    top->bus_rst = 0;
    top->vid_rst = 0;
  
    // Simulation loop
    while (!clk->EndOfSimulation())
    {
        // Toggle clock
        clk->AdvanceClocks();
        top->bus_clk = clk->GetClockStateDiv1(0, 0);
        top->vid_clk = clk->GetClockStateDiv1(1, 0);
        // Evaluate verilated model
        top->eval ();
        
        // Evaluate SDRAM C++ model
        sdr->eval (tb_sstep / 6,
                   top->bus_clk ^ 1, 1,
                   top->sdram_cs_n,  top->sdram_ras_n, top->sdram_cas_n, top->sdram_we_n,
                   top->sdram_ba,    top->sdram_addr,
                   top->sdram_dqm_n, (vluint64_t)top->sdram_dq_o,  sdram_q);
        // "Read" from SDRAM
        top->sdram_dq_i = (top->sdram_dq_oe) ? top->sdram_dq_o : (vluint16_t)sdram_q;
        
        // Dump VGA output
        vs = vga->eval_RGB444_DE (tb_sstep / 4,
                                  top->vid_clk,
                                  top->vga_de,
                                  top->vga_r,  top->vga_g,  top->vga_b);
                                
#if VM_TRACE
        // Dump signals into VCD file
        if (tfp)
        {
            if (vs)
            {
                // New VCD file
                if (trc_idx >= min_idx) tfp->close();
				trc_idx++;
				if (trc_idx >= min_idx)
				{
                    sprintf(file_name, "gpu_%04d.vcd", trc_idx);
                    tfp->open (file_name);
				}
            }
            if (trc_idx >= min_idx)
            {
                tfp->dump (tb_time);
            }
        }
#endif /* VM_TRACE */
        
        if (Verilated::gotFinish()) break;
    }

#if VM_TRACE
    if (tfp && trc_idx >= min_idx) tfp->close();
#endif /* VM_TRACE */
    
    top->final();
    
    delete top;
    
    delete sdr;
    
    delete vga;
    
    delete clk;
    
    // Calculate running time
    end = time(0);
    secs = difftime(end, beg);
    printf("\nSeconds elapsed : %f\n", secs);
    
    exit(0);
}
