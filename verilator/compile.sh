# Copyright 2008-2019 Frederic Requin
#
# This file is part of the 1943 FPGA core
#
# The 1943 FPGA core is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 3 of the License, or
# (at your option) any later version.
#
# The 1943 FPGA core is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.
#
#! /bin/sh

#Options for GCC compiler
COMPILE_OPT="-cc -O3 -CFLAGS -O3 -CFLAGS -Wno-attributes"

#Comment this line to disable VCD generation
TRACE_OPT="-trace"

#Clock signals
CLOCK_OPT=\
"-clk v.bus_clk\
 -clk v.vid_clk"
 
#Verilog top module
TOP_FILE=top_1943

#C++ support files
CPP_FILES=\
"main.cpp\
 ./clock_gen/clock_gen.cpp\
 ./easy_bmp/EasyBMP.cpp\
 ./sdr_sdram/sdr_sdram.cpp\
 ./video_out/video_out.cpp\
 verilated_dpi.cpp"

verilator tb_top.v $COMPILE_OPT $TRACE_OPT $CLOCK_OPT -top-module $TOP_FILE -exe $CPP_FILES
cd ./obj_dir
make -j -f V$TOP_FILE.mk V$TOP_FILE
cd ..
