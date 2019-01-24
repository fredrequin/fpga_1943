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

#include "verilated.h"
#include "video_out.h"
#include "../easy_bmp/EasyBMP.h"
#include <stdlib.h>
#include <stdio.h>
#include <time.h>

// Constructor
VideoOut::VideoOut(vluint8_t debug, vluint8_t depth, vluint8_t polarity, vluint16_t hoffset, vluint16_t hactive, vluint16_t voffset, vluint16_t vactive, const char *file)
{
    // color depth
    if (depth <= 8)
    {
        bit_mask  = (1 << depth) - 1;
        bit_shift = (int)(8 - depth);
    }
    else
    {
        bit_mask  = (vluint8_t)0xFF;
        bit_shift = (int)0;
    }
    // synchros polarities
    hs_pol      = (polarity & HS_POS_POL) ? (vluint8_t)1 : (vluint8_t)0;
    vs_pol      = (polarity & VS_POS_POL) ? (vluint8_t)1 : (vluint8_t)0;
    // screen format initialized
    hor_offs    = hoffset;
    hor_size    = hactive;
    ver_offs    = voffset;
    ver_size    = vactive;
    // debug mode
    dbg_on      = debug;
    // create a BMP with EasyBMP class
    bmp         = new BMP;
    bmp->SetBitDepth(24);
    bmp->SetSize((int)hactive, (int)vactive);
    // copy the filename
    strncpy(filename, file, 255);
    // internal variables cleared
    idx_yc      = (int)0;
    hcount      = (vluint16_t)0;
    hcount1     = (vluint16_t)0;
    hcount2     = (vluint16_t)0;
    vcount      = (vluint16_t)0;
    vcount1     = (vluint16_t)0;
    vcount2     = (vluint16_t)0;
    prev_clk    = (vluint8_t)0;
    prev_hs     = (vluint8_t)0;
    prev_vs     = (vluint8_t)0;
    dump_act    = (vluint8_t)0;
    dump_ctr    = (int)0;
    // initialize YUV to RGB tables
    for (int i = 0; i < 256; i++)
    {
        u_to_g[i] = (vluint16_t)(i * 44);
        u_to_b[i] = (vluint16_t)(i * 226);
        v_to_r[i] = (vluint16_t)(i * 180);
        v_to_g[i] = (vluint16_t)(i * 91);
    }
    // allocate YUV buffer
    for (int i = 0; i < 8; i++)
    {
        y_buf[i]   = new int[hactive];
        y_buf[i+8] = new int[hactive];
        c_buf[i]   = new int[hactive];
    }
}

// Destructor
VideoOut::~VideoOut()
{
    delete    bmp;
    for (int i = 0; i < 8; i++)
    {
        delete [] y_buf[i];
        delete [] y_buf[i+8];
        delete [] c_buf[i];
    }
}

// Cycle evaluate : RGB444 with synchros
vluint8_t VideoOut::eval_RGB444_HV
(
    vluint64_t cycle,
    // Clock
    vluint8_t  clk,
    // Synchros
    vluint8_t  vs,
    vluint8_t  hs,
    // RGB colors
    vluint8_t  red,
    vluint8_t  green,
    vluint8_t  blue
)
{
    vluint8_t ret = (vluint8_t)0;
    
    // Rising edge on clock
    if (clk && !prev_clk)
    {
        // Grab active area
        if ((vcount >= ver_offs) && (vcount < (ver_offs + ver_size)))
        {
            if ((hcount >= hor_offs) && (hcount < (hor_offs + hor_size)))
            {
                RGBApixel pixel;
                
                pixel.Red   = (red   & bit_mask) << bit_shift;
                pixel.Green = (green & bit_mask) << bit_shift;
                pixel.Blue  = (blue  & bit_mask) << bit_shift;
                
                bmp->SetPixel((int)(hcount - hor_offs), (int)(vcount - ver_offs), pixel);
            }
        }
        
        // Rising edge on VS
        if ((vs == vs_pol) && (prev_vs != vs_pol))
        {
            ret = dump_act;
            if (dbg_on) printf(" Rising edge on VS @ cycle #%llu\n", cycle);
            hcount = (vluint16_t)0;
            vcount = (vluint16_t)0;
            
            if (dump_act)
            {
                char tmp[264];
                
                sprintf(tmp, "%s_%04d.bmp", filename, dump_ctr);
                printf(" Save snapshot in file \"%s\"\n", tmp);
                bmp->WriteToFile(tmp);
                dump_ctr++;
            }
            if (filename[0]) dump_act = 1;
        }
        
        // Rising edge on HS
        if ((hs == hs_pol) && (prev_hs != hs_pol))
        {
            if (dbg_on) printf(" Rising edge on HS @ cycle #%llu (vcount = %d)\n", cycle, vcount);
            if (hcount > 4) vcount++;
            hcount = (vluint16_t)0;
        }
        else
        {
            hcount++;
        }
        
        prev_vs = vs;
        prev_hs = hs;
    }
    prev_clk = clk;
    
    return ret;
}

// Cycle evaluate : RGB444 with data enable
vluint8_t VideoOut::eval_RGB444_DE
(
    vluint64_t cycle,
    // Clock
    vluint8_t  clk,
    // Data enable
    vluint8_t  de,
    // RGB colors
    vluint8_t  red,
    vluint8_t  green,
    vluint8_t  blue
)
{
    vluint8_t ret = (vluint8_t)0;
    
    // Rising edge on clock
    if (clk && !prev_clk)
    {
        // Grab active area
        if (de)
        {
            RGBApixel pixel;
                
            pixel.Red   = (red   & bit_mask) << bit_shift;
            pixel.Green = (green & bit_mask) << bit_shift;
            pixel.Blue  = (blue  & bit_mask) << bit_shift;
            
            bmp->SetPixel((int)hcount, (int)vcount, pixel);
            
            hcount++;
            if (hcount == hor_size)
            {
                if (dbg_on) printf(" Rising edge on HS @ cycle #%llu (vcount = %d)\n", cycle, vcount);
                hcount = (vluint16_t)0;
                
                vcount++;
                if (vcount == ver_size)
                {
                    if (filename[0]) dump_act = 1;
                    
                    ret = dump_act;
                    if (dbg_on) printf(" Rising edge on VS @ cycle #%llu\n", cycle);
                    vcount = (vluint16_t)0;
                    
                    if (dump_act)
                    {
                        char tmp[264];
                        
                        sprintf(tmp, "%s_%04d.bmp", filename, dump_ctr);
                        printf(" Save snapshot in file \"%s\"\n", tmp);
                        bmp->WriteToFile(tmp);
                        dump_ctr++;
                    }
                }
            }
        }
    }
    prev_clk = clk;
    
    return ret;
}

// Cycle evaluate : YUV444 with synchros
vluint8_t VideoOut::eval_YUV444_HV
(
    vluint64_t cycle,
    // Clock
    vluint8_t  clk,
    // Synchros
    vluint8_t  vs,
    vluint8_t  hs,
    // YUV colors
    vluint8_t  luma,
    vluint8_t  cb,
    vluint8_t  cr
)
{
    vluint8_t ret = (vluint8_t)0;
    
    // Rising edge on clock
    if (clk && !prev_clk)
    {
        // Grab active area
        if ((vcount >= ver_offs) && (vcount < (ver_offs + ver_size)))
        {
            if ((hcount >= hor_offs) && (hcount < (hor_offs + hor_size)))
            {
                int y, u, v;
                
                y = (int)luma;
                u = (int)cb;
                v = (int)cr;
                
                bmp->SetPixel((int)(hcount - hor_offs), (int)(vcount - ver_offs), yuv2rgb(y,u,v));
            }
        }
        
        // Rising edge on VS
        if ((vs == vs_pol) && (prev_vs != vs_pol))
        {
            ret = dump_act;
            if (dbg_on) printf(" Rising edge on VS @ cycle #%llu\n", cycle);
            hcount = (vluint16_t)0;
            vcount = (vluint16_t)0;
            
            if (dump_act)
            {
                char tmp[264];
                
                sprintf(tmp, "%s_%04d.bmp", filename, dump_ctr);
                printf(" Save snapshot in file \"%s\"\n", tmp);
                bmp->WriteToFile(tmp);
                dump_ctr++;
            }
            if (filename[0]) dump_act = 1;
        }
        
        // Rising edge on HS
        if ((hs == hs_pol) && (prev_hs != hs_pol))
        {
            if (dbg_on) printf(" Rising edge on HS @ cycle #%llu (vcount = %d)\n", cycle, vcount);
            if (hcount > 4) vcount++;
            hcount = (vluint16_t)0;
        }
        else
        {
            hcount++;
        }
        
        prev_vs = vs;
        prev_hs = hs;
    }
    prev_clk = clk;
    
    return ret;
}

// Cycle evaluate : YUV444 with data enable
vluint8_t VideoOut::eval_YUV444_DE
(
    vluint64_t cycle,
    // Clock
    vluint8_t  clk,
    // Data enable
    vluint8_t  de,
    // YUV colors
    vluint8_t  luma,
    vluint8_t  cb,
    vluint8_t  cr
)
{
    vluint8_t ret = (vluint8_t)0;
    
    // Rising edge on clock
    if (clk && !prev_clk)
    {
        // Grab active area
        if (de)
        {
            int y, u, v;
            
            y = (int)luma;
            u = (int)cb;
            v = (int)cr;
                
            bmp->SetPixel((int)hcount, (int)vcount, yuv2rgb(y,u,v));
            
            hcount++;
            if (hcount == hor_size)
            {
                if (dbg_on) printf(" Rising edge on HS @ cycle #%llu (vcount = %d)\n", cycle, vcount);
                hcount = (vluint16_t)0;
                
                vcount++;
                if (vcount == ver_size)
                {
                    if (filename[0]) dump_act = 1;
                    
                    ret = dump_act;
                    if (dbg_on) printf(" Rising edge on VS @ cycle #%llu\n", cycle);
                    vcount = (vluint16_t)0;
                    
                    if (dump_act)
                    {
                        char tmp[264];
                        
                        sprintf(tmp, "%s_%04d.bmp", filename, dump_ctr);
                        printf(" Save snapshot in file \"%s\"\n", tmp);
                        bmp->WriteToFile(tmp);
                        dump_ctr++;
                    }
                }
            }
        }
    }
    prev_clk = clk;
    
    return ret;
}

// Cycle evaluate : YUV422 with synchros
vluint8_t VideoOut::eval_YUV422_HV
(
    vluint64_t cycle,
    // Clock
    vluint8_t  clk,
    // Synchros
    vluint8_t  vs,
    vluint8_t  hs,
    // YUV colors
    vluint8_t  luma,
    vluint8_t  chroma
)
{
    vluint8_t ret = (vluint8_t)0;
    
    // Rising edge on clock
    if (clk && !prev_clk)
    {
        // Grab active area
        if ((vcount >= ver_offs) && (vcount < (ver_offs + ver_size)))
        {
            if ((hcount >= hor_offs) && (hcount < (hor_offs + hor_size)))
            {
                if ((hcount - hor_offs) & 1)
                {
                    // Odd pixel
                    int y, v;
                    
                    y = (int)luma;
                    v = (int)chroma;
                    
                    bmp->SetPixel((int)(hcount - hor_offs - 1), (int)(vcount - ver_offs), yuv2rgb(y0,u0,v));
                    
                    bmp->SetPixel((int)(hcount - hor_offs), (int)(vcount - ver_offs), yuv2rgb(y,u0,v));
                }
                else
                {
                    // Even pixel
                    y0 = (int)luma;
                    u0 = (int)chroma;
                }
            }
        }
        
        // Rising edge on VS
        if ((vs == vs_pol) && (prev_vs != vs_pol))
        {
            ret = dump_act;
            if (dbg_on) printf(" Rising edge on VS @ cycle #%llu\n", cycle);
            hcount = (vluint16_t)0;
            vcount = (vluint16_t)0;
            
            if (dump_act)
            {
                char tmp[264];
                
                sprintf(tmp, "%s_%04d.bmp", filename, dump_ctr);
                printf(" Save snapshot in file \"%s\"\n", tmp);
                bmp->WriteToFile(tmp);
                dump_ctr++;
            }
            if (filename[0]) dump_act = 1;
        }
        
        // Rising edge on HS
        if ((hs == hs_pol) && (prev_hs != hs_pol))
        {
            if (dbg_on) printf(" Rising edge on HS @ cycle #%llu (vcount = %d)\n", cycle, vcount);
            if (hcount > 4) vcount++;
            hcount = (vluint16_t)0;
        }
        else
        {
            hcount++;
        }
        
        prev_vs = vs;
        prev_hs = hs;
    }
    prev_clk = clk;
    
    return ret;
}

// Cycle evaluate : YUV422 with data enable
vluint8_t VideoOut::eval_YUV422_DE
(
    vluint64_t cycle,
    // Clock
    vluint8_t  clk,
    // Data enable
    vluint8_t  de,
    // YUV colors
    vluint8_t  luma,
    vluint8_t  chroma
)
{
    vluint8_t ret = (vluint8_t)0;
    
    // Rising edge on clock
    if (clk && !prev_clk)
    {
        // Grab active area
        if (de)
        {
            if (hcount & 1)
            {
                // Odd pixel
                int y, v;
                
                y = (int)luma;
                v = (int)chroma;
                
                bmp->SetPixel((int)(hcount - 1), (int)vcount, yuv2rgb(y0,u0,v));
                
                bmp->SetPixel((int)hcount, (int)vcount, yuv2rgb(y,u0,v));
            }
            else
            {
                // Even pixel
                y0 = (int)luma;
                u0 = (int)chroma;
            }
            
            hcount++;
            if (hcount == hor_size)
            {
                if (dbg_on) printf(" Rising edge on HS @ cycle #%llu (vcount = %d)\n", cycle, vcount);
                hcount = (vluint16_t)0;
                
                vcount++;
                if (vcount == ver_size)
                {
                    if (filename[0]) dump_act = 1;
                    
                    ret = dump_act;
                    if (dbg_on) printf(" Rising edge on VS @ cycle #%llu\n", cycle);
                    vcount = (vluint16_t)0;
                    
                    if (dump_act)
                    {
                        char tmp[264];
                        
                        sprintf(tmp, "%s_%04d.bmp", filename, dump_ctr);
                        printf(" Save snapshot in file \"%s\"\n", tmp);
                        bmp->WriteToFile(tmp);
                        dump_ctr++;
                    }
                }
            }
        }
    }
    prev_clk = clk;
    
    return ret;
}

// Cycle evaluate : YUV420 with data enables
vluint8_t VideoOut::eval_YUV420_DE
(
    vluint64_t cycle,
    // Clock
    vluint8_t  clk,
    // Data enables
    vluint8_t  de_y,
    vluint8_t  de_c,
    // YUV colors
    vluint8_t  luma,
    vluint8_t  chroma
)
{
    vluint8_t ret = (vluint8_t)0;
    
    // Rising edge on clock
    if (clk && !prev_clk)
    {
        // Grab active area
        if (de_y)
        {
            y_buf[vcount1 & 3][hcount1] = (int)luma;
            hcount1 ++;
            if (hcount1 == hor_size)
            {
                hcount1 = (vluint16_t)0;
                vcount1 ++;
            }
        }
        if (de_c)
        {
            c_buf[vcount2 & 1][hcount2] = (int)chroma;
            hcount2 ++;
            if (hcount2 == hor_size)
            {
                hcount2 = (vluint16_t)0;
                vcount2 ++;
            }
        }
        
        // 2 lines of pixel are ready
        if (((vcount1 - vcount) >= 2) && ((vcount2 * 2 - vcount) >= 2))
        {
            int y, u, v;
            
            // YUV420 to RGB444 conversion
            for (int i = 0; i < hor_size; i = i + 2)
            {
                u = c_buf[(vcount2 & 1) ^ 1][i];
                v = c_buf[(vcount2 & 1) ^ 1][i+1];
                
                y = y_buf[(vcount1 & 2) ^ 2][i];
                bmp->SetPixel(i,   (int)vcount,   yuv2rgb(y,u,v));
                
                y = y_buf[(vcount1 & 2) ^ 2][i+1];
                bmp->SetPixel(i+1, (int)vcount,   yuv2rgb(y,u,v));
                
                y = y_buf[(vcount1 & 2) ^ 3][i];
                bmp->SetPixel(i,   (int)vcount+1, yuv2rgb(y,u,v));
                
                y = y_buf[(vcount1 & 2) ^ 3][i+1];
                bmp->SetPixel(i+1, (int)vcount+1, yuv2rgb(y,u,v));
            }
            
            if (dbg_on) printf(" Rising edge on HS @ cycle #%llu (vcount = %d)\n", cycle, vcount);
            
            vcount += 2;
            
            if (vcount == ver_size)
            {
                vcount   = (vluint16_t)0;
                vcount1 -= ver_size;
                vcount2 -= ver_size / 2;
                
                if (filename[0]) dump_act = 1;
                
                ret = dump_act;
                if (dbg_on) printf(" Rising edge on VS @ cycle #%llu\n", cycle);
                
                if (dump_act)
                {
                    char tmp[264];
                    
                    sprintf(tmp, "%s_%04d.bmp", filename, dump_ctr);
                    printf(" Save snapshot in file \"%s\"\n", tmp);
                    bmp->WriteToFile(tmp);
                    dump_ctr++;
                }
            }
        }
    }
    prev_clk = clk;
    
    return ret;
}

vluint16_t VideoOut::get_hcount()
{
    return hcount;
}

vluint16_t VideoOut::get_vcount()
{
    return vcount;
}

RGBApixel VideoOut::yuv2rgb
(
    int lum,
    int cb,
    int cr
)
{
    int y, u, v;
    int r, g, b;
    RGBApixel pixel;
    
    y = (lum & bit_mask) << (bit_shift + 7);
    u = (cb  & bit_mask) << bit_shift;
    v = (cr  & bit_mask) << bit_shift;
    
    r = (y + v_to_r[v] - 22906) >> 7;
    g = (y - u_to_g[u] - v_to_g[v] + 17264) >> 7;
    b = (y + u_to_b[u] - 28928) >> 7;
    
    pixel.Red   = (r < 0) ? 0 : (r > 255) ? 255 : r;
    pixel.Green = (g < 0) ? 0 : (g > 255) ? 255 : g;
    pixel.Blue  = (b < 0) ? 0 : (b > 255) ? 255 : b;
    
    return pixel;
}
