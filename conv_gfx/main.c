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

#include <stdio.h>
#include <stdlib.h>

#define MAX_GFX_PLANES (4)
#define MAX_GFX_SIZE   (32)

typedef          char  BYTE;
typedef unsigned char  UBYTE;
typedef          short WORD;
typedef unsigned short UWORD;
typedef          long  LONG;
typedef unsigned long  ULONG;

typedef struct _gfx_layout
{
    UWORD        width;                       /* pixel width of each element */
    UWORD        height;                      /* pixel height of each element */
    ULONG        total;                       /* total number of elements, or RGN_FRAC() */
    UWORD        planes;                      /* number of bitplanes */
    ULONG        planeoffset[MAX_GFX_PLANES]; /* bit offset of each bitplane */
    ULONG        xoffset[MAX_GFX_SIZE];       /* bit offset of each horizontal pixel */
    ULONG        yoffset[MAX_GFX_SIZE];       /* bit offset of each vertical pixel */
    ULONG        charincrement;               /* distance between two consecutive elements (in bits) */
    const ULONG *extxoffs;                    /* extended X offset array for really big layouts */
    const ULONG *extyoffs;                    /* extended Y offset array for really big layouts */
} gfx_layout;

// 32 KB in:
// ---------
//  1943.04  1943kai.04
const gfx_layout chrlayout_1943 =
{
	8,8,	/* 8*8 characters */
	2048,	/* 2048 characters */
	2,	/* 2 bits per pixel */
	{ 4, 0 },
	{ 0, 1, 2, 3, 8+0, 8+1, 8+2, 8+3 },
	{ 0*16, 1*16, 2*16, 3*16, 4*16, 5*16, 6*16, 7*16 },
	16*8	/* every char takes 16 consecutive bytes */
};

// 16 KB in:
// ---------
//  11f_gs01.bin
const gfx_layout chrlayout_gs =
{
	8,8,	/* 8*8 characters */
	1024,	/* 1024 characters */
	2,	/* 2 bits per pixel */
	{ 4, 0 },
	{ 0, 1, 2, 3, 8+0, 8+1, 8+2, 8+3 },
	{ 0*16, 1*16, 2*16, 3*16, 4*16, 5*16, 6*16, 7*16 },
	16*8	/* every char takes 16 consecutive bytes */
};

// 256 KB in:
// ----------
//  1943.15
//  1943.16
//  1943.17
//  1943.18
//  1943.19
//  1943.20
//  1943.21
//  1943.22
const gfx_layout fgnlayout =
{
	32,32,  /* 32*32 tiles */
	512,    /* 512 tiles */
	4,      /* 4 bits per pixel */
	{ 512*256*8+4, 512*256*8+0, 4, 0 },
	{ 0, 1, 2, 3, 8+0, 8+1, 8+2, 8+3,
			64*8+0, 64*8+1, 64*8+2, 64*8+3, 65*8+0, 65*8+1, 65*8+2, 65*8+3,
			128*8+0, 128*8+1, 128*8+2, 128*8+3, 129*8+0, 129*8+1, 129*8+2, 129*8+3,
			192*8+0, 192*8+1, 192*8+2, 192*8+3, 193*8+0, 193*8+1, 193*8+2, 193*8+3 },
	{ 0*16, 1*16, 2*16, 3*16, 4*16, 5*16, 6*16, 7*16,
			8*16, 9*16, 10*16, 11*16, 12*16, 13*16, 14*16, 15*16,
			16*16, 17*16, 18*16, 19*16, 20*16, 21*16, 22*16, 23*16,
			24*16, 25*16, 26*16, 27*16, 28*16, 29*16, 30*16, 31*16 },
	256*8	/* every tile takes 256 consecutive bytes */
};

// 64 KB in:
// ---------
//  1943.24
//  1943.25
const gfx_layout bgnlayout =
{
	32,32,  /* 32*32 tiles */
	128,    /* 128 tiles */
	4,      /* 4 bits per pixel */
	{ 128*256*8+4, 128*256*8+0, 4, 0 },
	{ 0, 1, 2, 3, 8+0, 8+1, 8+2, 8+3,
			64*8+0, 64*8+1, 64*8+2, 64*8+3, 65*8+0, 65*8+1, 65*8+2, 65*8+3,
			128*8+0, 128*8+1, 128*8+2, 128*8+3, 129*8+0, 129*8+1, 129*8+2, 129*8+3,
			192*8+0, 192*8+1, 192*8+2, 192*8+3, 193*8+0, 193*8+1, 193*8+2, 193*8+3 },
	{ 0*16, 1*16, 2*16, 3*16, 4*16, 5*16, 6*16, 7*16,
			8*16, 9*16, 10*16, 11*16, 12*16, 13*16, 14*16, 15*16,
			16*16, 17*16, 18*16, 19*16, 20*16, 21*16, 22*16, 23*16,
			24*16, 25*16, 26*16, 27*16, 28*16, 29*16, 30*16, 31*16 },
	256*8	/* every tile takes 256 consecutive bytes */
};

// 256 KB in:
// ----------
//  1943.06  1943kai.06
//  1943.07  1943kai.07
//  1943.08  1943kai.08
//  1943.09  1943kai.09
//  1943.10  1943kai.10
//  1943.11  1943kai.11
//  1943.12  1943kai.12
//  1943.13  1943kai.13
const gfx_layout sprlayout_1943 =
{
	16,16,	/* 16*16 sprites */
	2048,	/* 2048 sprites */
	4,      /* 4 bits per pixel */
	{ 2048*64*8+4, 2048*64*8+0, 4, 0 },
	{ 0, 1, 2, 3, 8+0, 8+1, 8+2, 8+3,
			32*8+0, 32*8+1, 32*8+2, 32*8+3, 33*8+0, 33*8+1, 33*8+2, 33*8+3 },
	{ 0*16, 1*16, 2*16, 3*16, 4*16, 5*16, 6*16, 7*16,
			8*16, 9*16, 10*16, 11*16, 12*16, 13*16, 14*16, 15*16 },
	64*8	/* every sprite takes 64 consecutive bytes */
};

static void gfx_convert_CCW(const gfx_layout *lay, UBYTE *src, UWORD *dst)
{
    ULONG *xoffs;
    ULONG *yoffs;
    ULONG *poffs;
    ULONG bit;
    
    int   x, y, p, t;
    int   xmax, ymax, pmax, tmax;
    UWORD word;
    
    xoffs = lay->xoffset;
    yoffs = lay->yoffset;
    poffs = lay->planeoffset;
    
    xmax  = (int)lay->width - 1;
    ymax  = (int)lay->height - 1;
    pmax  = (int)lay->planes;
    tmax  = (int)lay->total;
    
    word = 0;
    for (t = 0; t < tmax; t++)
    {
        for (x = xmax; x >= 0; x--)
        {
            for (y = 0; y <= ymax; y++)
            {
                word = word >> 4;
                
                for (p = 0; p < pmax; p++)
                {
                    bit = poffs[p] + xoffs[x] + yoffs[y];
                    if (src[bit >> 3] & (0x80 >> (bit & 7)))
                        word |= (0x8000 >> p);
                }
                if ((y & 3) == 3)
                {
                    *dst = word;
                    dst++;
                }
            }
        }
        src += (lay->charincrement >> 3);
    }
}

static void read_rom(const char *name, UBYTE *ptr, int num)
{
    FILE *fh;
    
    fh = fopen(name, "rb");
    if (fh)
    {
        fread(ptr, sizeof(UBYTE), (size_t)num, fh);
        fclose(fh);
    }
}

static void write_rom(const char *name, UBYTE *ptr, int num)
{
    FILE *fh;
    
    fh = fopen(name, "wb");
    if (fh)
    {
        fwrite(ptr, sizeof(UBYTE), (size_t)num, fh);
        fclose(fh);
    }
}

int main(int argc, char *argv[])
{
    UBYTE *src;
    UWORD *dst;
    
    src = (UBYTE *)malloc(512 * 1024);
    dst = (UWORD *)malloc(512 * 1024);
    if ((src) && (dst))
    {
        // characters
        read_rom("1943\\1943.04", src, 0x8000);
        gfx_convert_CCW(&chrlayout_1943, src, dst);
        write_rom("1943\\1943.chr", (UBYTE *)dst, 0x10000);
        
        read_rom("1943_kai\\1943kai.04", src, 0x8000);
        gfx_convert_CCW(&chrlayout_1943, src, dst);
        write_rom("1943_kai\\1943kai.chr", (UBYTE *)dst, 0x10000);
        
        read_rom("gun_smoke\\11f_gs01.bin", src, 0x4000);
        gfx_convert_CCW(&chrlayout_gs, src, dst);
        write_rom("gun_smoke\\gunsmoke.chr", (UBYTE *)dst, 0x08000);
        // sprites
        read_rom("1943\\1943.06", src + 0x00000, 0x8000);
        read_rom("1943\\1943.07", src + 0x08000, 0x8000);
        read_rom("1943\\1943.08", src + 0x10000, 0x8000);
        read_rom("1943\\1943.09", src + 0x18000, 0x8000);
        read_rom("1943\\1943.10", src + 0x20000, 0x8000);
        read_rom("1943\\1943.11", src + 0x28000, 0x8000);
        read_rom("1943\\1943.12", src + 0x30000, 0x8000);
        read_rom("1943\\1943.13", src + 0x38000, 0x8000);
        gfx_convert_CCW(&sprlayout_1943, src, dst);
        write_rom("1943\\1943.spr", (UBYTE *)dst, 0x40000);
        
        read_rom("1943_kai\\1943kai.06", src + 0x00000, 0x8000);
        read_rom("1943_kai\\1943kai.07", src + 0x08000, 0x8000);
        read_rom("1943_kai\\1943kai.08", src + 0x10000, 0x8000);
        read_rom("1943_kai\\1943kai.09", src + 0x18000, 0x8000);
        read_rom("1943_kai\\1943kai.10", src + 0x20000, 0x8000);
        read_rom("1943_kai\\1943kai.11", src + 0x28000, 0x8000);
        read_rom("1943_kai\\1943kai.12", src + 0x30000, 0x8000);
        read_rom("1943_kai\\1943kai.13", src + 0x38000, 0x8000);
        gfx_convert_CCW(&sprlayout_1943, src, dst);
        write_rom("1943_kai\\1943kai.spr", (UBYTE *)dst, 0x40000);
        // foreground
        read_rom("1943\\1943.15", src + 0x00000, 0x8000);
        read_rom("1943\\1943.16", src + 0x08000, 0x8000);
        read_rom("1943\\1943.17", src + 0x10000, 0x8000);
        read_rom("1943\\1943.18", src + 0x18000, 0x8000);
        read_rom("1943\\1943.19", src + 0x20000, 0x8000);
        read_rom("1943\\1943.20", src + 0x28000, 0x8000);
        read_rom("1943\\1943.21", src + 0x30000, 0x8000);
        read_rom("1943\\1943.22", src + 0x38000, 0x8000);
        gfx_convert_CCW(&fgnlayout, src, dst);
        write_rom("1943\\1943.fgn", (UBYTE *)dst, 0x40000);
        
        read_rom("1943_kai\\1943kai.15", src + 0x00000, 0x8000);
        read_rom("1943_kai\\1943kai.16", src + 0x08000, 0x8000);
        read_rom("1943_kai\\1943kai.17", src + 0x10000, 0x8000);
        read_rom("1943_kai\\1943kai.18", src + 0x18000, 0x8000);
        read_rom("1943_kai\\1943kai.19", src + 0x20000, 0x8000);
        read_rom("1943_kai\\1943kai.20", src + 0x28000, 0x8000);
        read_rom("1943_kai\\1943kai.21", src + 0x30000, 0x8000);
        read_rom("1943_kai\\1943kai.22", src + 0x38000, 0x8000);
        gfx_convert_CCW(&fgnlayout, src, dst);
        write_rom("1943_kai\\1943kai.fgn", (UBYTE *)dst, 0x40000);
        // background
        read_rom("1943\\1943.24", src + 0x00000, 0x8000);
        read_rom("1943\\1943.25", src + 0x08000, 0x8000);
        gfx_convert_CCW(&bgnlayout, src, dst);
        write_rom("1943\\1943.bgn", (UBYTE *)dst, 0x10000);
        
        read_rom("1943_kai\\1943kai.24", src + 0x00000, 0x8000);
        read_rom("1943_kai\\1943kai.25", src + 0x08000, 0x8000);
        gfx_convert_CCW(&bgnlayout, src, dst);
        write_rom("1943_kai\\1943kai.bgn", (UBYTE *)dst, 0x10000);
    }
    if (src) free(src);
    if (dst) free(dst);
    
    return 0;
}
