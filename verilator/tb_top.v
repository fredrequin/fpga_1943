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

// Trace configuration
// -------------------
`verilator_config

tracing_off -file "mem_dc_1024x9to9r.v"
tracing_off -file "mem_dc_2048x8to16r.v"
tracing_off -file "mem_dc_256x32to8r.v"
tracing_off -file "mem_dc_4096x8to32r.v"
tracing_off -file "mem_dc_4096x8to8r.v"
tracing_off -file "mem_dc_512x32to8r.v"

tracing_on -file "sdram_ctrl.v"

tracing_off -file "gpu_gpios.v"
tracing_on -file "gpu_vbeam.v"
tracing_on -file "gpu_dmaseq.v"
tracing_off -file "gpu_charmap.v"
tracing_off -file "gpu_tilemap.v"
tracing_on -file "gpu_sprites.v"
tracing_on -file "gpu_colormux.v"
tracing_on -file "gpu_scandoubler.v"
tracing_on -file "gpu_top.v"

tracing_off -file "tv80_alu.v"
tracing_off -file "tv80_core.v"
tracing_off -file "tv80_mcode.v"
tracing_off -file "tv80_reg.v"
tracing_off -file "tv80se.v"

tracing_on -file "top_1943.v"

`verilog
// Memory blocks
`include "../hdl/bram/mem_dc_1024x9to9r.v"  // gpu_colormux.v
`include "../hdl/bram/mem_dc_2048x8to16r.v" // gpu_scandoubler.v, gpu_charmap.v
`include "../hdl/bram/mem_dc_256x32to8r.v"  // gpu_charmap.v, gpu_sprites.v, gpu_tilemap.v
`include "../hdl/bram/mem_dc_4096x8to32r.v" // gpu_sprites.v
`include "../hdl/bram/mem_dc_4096x8to8r.v"  // gpu_top.v
`include "../hdl/bram/mem_dc_512x32to8r.v"  // gpu_scandoubler.v
// 1943 GPU
`include "../hdl/gpu/gpu_gpios.v"
`include "../hdl/gpu/gpu_vbeam.v"
`include "../hdl/gpu/gpu_dmaseq.v"
`include "../hdl/gpu/gpu_charmap.v"
`include "../hdl/gpu/gpu_tilemap.v"
`include "../hdl/gpu/gpu_sprites.v"
`include "../hdl/gpu/gpu_colormux.v"
`include "../hdl/gpu/gpu_scale2x.v"
`include "../hdl/gpu/gpu_scandoubler.v"
`include "../hdl/gpu/gpu_top.v"
// Z80 CPU
`include "../hdl/tv80/tv80_alu.v"
`include "../hdl/tv80/tv80_core.v"
`include "../hdl/tv80/tv80_mcode.v"
`include "../hdl/tv80/tv80_reg.v"
`include "../hdl/tv80/tv80se.v"
// SDRAM controller
`include "../hdl/sdram_ctrl.v"
// Top level
`include "../hdl/top_1943.v"
