// Copyright 2013 Frederic Requin
//
// This file is part of the MCC216 project (www.arcaderetrogaming.com)
//
// The VGA output is free software; you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation; either version 3 of the License, or
// (at your option) any later version.
//
// The VGA output is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU General Public License for more details.
//
// You should have received a copy of the GNU General Public License
// along with this program.  If not, see <http://www.gnu.org/licenses/>.
//
// Video output:
// -------------
//  - Allows to translate VGA signals from a simulation into BMP files
//  - It is designed to work with "Verilator" (www.veripool.org)
//  - It uses the EasyBMP class (easybmp.sourceforge.net)
//  - Synchros polarities are configurable
//  - Active and total areas are configurable
//  - HS/VS or DE based scanning
//  - BMP files are saved on VS edge
//  - Support for RGB444, YUV444, YUV422 and YUV420 colorspaces
//

#ifndef _VIDEO_OUT_H_
#define _VIDEO_OUT_H_

#include "verilated.h"
#include "../easy_bmp/EasyBMP.h"

#define HS_POS_POL (1)
#define HS_NEG_POL (0)
#define VS_POS_POL (2)
#define VS_NEG_POL (0)

class VideoOut
{
    public:
        // Constructor and destructor
        VideoOut(vluint8_t debug, vluint8_t depth, vluint8_t polarity, vluint16_t hoffset, vluint16_t hactive, vluint16_t voffset, vluint16_t vactive, const char *file);
        ~VideoOut();
        // Methods
        vluint8_t eval_RGB444_HV(vluint64_t cycle, vluint8_t clk, vluint8_t vs,   vluint8_t hs,   vluint8_t red,  vluint8_t green, vluint8_t blue);
        vluint8_t eval_RGB444_DE(vluint64_t cycle, vluint8_t clk, vluint8_t de,                   vluint8_t red,  vluint8_t green, vluint8_t blue);
        vluint8_t eval_YUV444_HV(vluint64_t cycle, vluint8_t clk, vluint8_t vs,   vluint8_t hs,   vluint8_t luma, vluint8_t cb,    vluint8_t cr);
        vluint8_t eval_YUV444_DE(vluint64_t cycle, vluint8_t clk, vluint8_t de,                   vluint8_t luma, vluint8_t cb,    vluint8_t cr);
        vluint8_t eval_YUV422_HV(vluint64_t cycle, vluint8_t clk, vluint8_t vs,   vluint8_t hs,   vluint8_t luma, vluint8_t chroma);
        vluint8_t eval_YUV422_DE(vluint64_t cycle, vluint8_t clk, vluint8_t de,                   vluint8_t luma, vluint8_t chroma);
        vluint8_t eval_YUV420_DE(vluint64_t cycle, vluint8_t clk, vluint8_t de_y, vluint8_t de_c, vluint8_t luma, vluint8_t chroma);
        vluint16_t get_hcount();
        vluint16_t get_vcount();
    private:
        RGBApixel yuv2rgb(int lum, int cb, int cr);
        // Color depth
        int        bit_shift;
        vluint8_t  bit_mask;
        // Synchros polarities
        vluint8_t  hs_pol;
        vluint8_t  vs_pol;
        // Debug mode
        vluint8_t  dbg_on;
        // Image format
        vluint16_t hor_offs;
        vluint16_t ver_offs;
        vluint16_t hor_size;
        vluint16_t ver_size;
        // YUV to RGB tables
        int        u_to_g[256];
        int        u_to_b[256];
        int        v_to_r[256];
        int        v_to_g[256];
        // YUV422
        int        y0;
        int        u0;
        // YUV420
        int       *y_buf[16];
        int       *c_buf[8];
        // BMP file
        BMP       *bmp;
        // BMP file name
        char       filename[256];
        // Internal variable
        int        idx_yc;
        vluint16_t hcount1;
        vluint16_t hcount2;
        vluint16_t hcount;
        vluint16_t vcount1;
        vluint16_t vcount2;
        vluint16_t vcount;
        vluint8_t  prev_clk;
        vluint8_t  prev_hs;
        vluint8_t  prev_vs;
        vluint8_t  dump_act;
        int        dump_ctr;
};

#endif /* _VIDEO_OUT_H_ */
