/*------------------------------------------------------------------------
 *
 * Derivative of the OpenVG 1.0.1 Reference Implementation
 * -------------------------------------
 *
 * Copyright (c) 2007 The Khronos Group Inc.
 *
 * Permission is hereby granted, free of charge, to any person obtaining a
 * copy of this software and /or associated documentation files
 * (the "Materials "), to deal in the Materials without restriction,
 * including without limitation the rights to use, copy, modify, merge,
 * publish, distribute, sublicense, and/or sell copies of the Materials,
 * and to permit persons to whom the Materials are furnished to do so,
 * subject to the following conditions: 
 *
 * The above copyright notice and this permission notice shall be included 
 * in all copies or substantial portions of the Materials. 
 *
 * THE MATERIALS ARE PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
 * EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
 * MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.
 * IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM,
 * DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR
 * OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE MATERIALS OR
 * THE USE OR OTHER DEALINGS IN THE MATERIALS.
 *
 *//**
 * \file
 * \brief	Implementation of VGColor and KGSurface functions.
 * \note	
 *//*-------------------------------------------------------------------*/

// http://lists.apple.com/archives/Quartz-dev/2006/Feb/msg00031.html

#import "KGSurface.h"

@implementation KGSurface

#define RI_MAX_GAUSSIAN_STD_DEVIATION	128.0f

BOOL KGSurfaceIsValidFormat(int f)
{
	if(f < VG_sRGBX_8888 || f > VG_lABGR_8888_PRE)
		return NO;
	return YES;
}

/*-------------------------------------------------------------------*//*!
* \brief	Converts from numBits into a shifted mask
* \param	
* \return	
* \note
*//*-------------------------------------------------------------------*/
	
static unsigned int bitsToMask(unsigned int bits, unsigned int shift)
{
	return ((1<<bits)-1) << shift;
}

/*-------------------------------------------------------------------*//*!
* \brief	Converts from color (RIfloat) to an int with 1.0f mapped to the
*			given maximum with round-to-nearest semantics.
* \param	
* \return	
* \note		
*//*-------------------------------------------------------------------*/
	
static unsigned int colorToInt(RIfloat c, int maxc)
{
	return RI_INT_MIN(RI_INT_MAX(RI_FLOOR_TO_INT(c * (RIfloat)maxc + 0.5f), 0), maxc);
}

/*-------------------------------------------------------------------*//*!
* \brief	Converts from int to color (RIfloat) with the given maximum
*			mapped to 1.0f.
* \param	
* \return	
* \note		
*//*-------------------------------------------------------------------*/

static inline RIfloat intToColor(unsigned int i, unsigned int maxi)
{
	return (RIfloat)(i & maxi) / (RIfloat)maxi;
}

/*-------------------------------------------------------------------*//*!
* \brief	Converts from packed integer in a given format to a VGColor.
* \param	
* \return	
* \note		
*//*-------------------------------------------------------------------*/


VGColor VGColorUnpack(unsigned int inputData,KGSurface *img){
   KGRGBA rgba=KGRGBAUnpack(inputData,img);
  
   VGColor result;
   
   result.r=rgba.r;
   result.g=rgba.g;
   result.b=rgba.b;
   result.a=rgba.a;
   result.m_format = img->_colorFormat;
// we don't need to do this for luminance but whatever 
   if(result.m_format & VGColorPREMULTIPLIED){	//clamp premultiplied color to alpha to enforce consistency
    result.r = RI_MIN(result.r, result.a);
    result.g = RI_MIN(result.g, result.a);
    result.b = RI_MIN(result.b, result.a);
   }

    return result;
}


/*-------------------------------------------------------------------*//*!
* \brief	Converts from VGColor to a packed integer in a given format.
* \param	
* \return	
* \note		
*//*-------------------------------------------------------------------*/

unsigned int KGRGBAPack(KGRGBA rgba,KGSurface *img) {{
	RI_ASSERT(rgba.r >= 0.0f && rgba.r <= 1.0f);
	RI_ASSERT(rgba.g >= 0.0f && rgba.g <= 1.0f);
	RI_ASSERT(rgba.b >= 0.0f && rgba.b <= 1.0f);
	RI_ASSERT(rgba.a >= 0.0f && rgba.a <= 1.0f);

	int rb = img->m_desc.redBits;
	int gb = img->m_desc.greenBits;
	int bb = img->m_desc.blueBits;
	int ab = img->m_desc.alphaBits;
	int lb = img->m_desc.luminanceBits;
	int rs = img->m_desc.redShift;
	int gs = img->m_desc.greenShift;
	int bs = img->m_desc.blueShift;
	int as = img->m_desc.alphaShift;
	int ls = img->m_desc.luminanceShift;

	if(lb)
	{	//luminance
		return colorToInt(rgba.r, (1<<lb)-1) << ls;
	}
	else
	{	//rgb
		unsigned int cr = rb ? colorToInt(rgba.r, (1<<rb)-1) : 0;
		unsigned int cg = gb ? colorToInt(rgba.g, (1<<gb)-1) : 0;
		unsigned int cb = bb ? colorToInt(rgba.b, (1<<bb)-1) : 0;
		unsigned int ca = ab ? colorToInt(rgba.a, (1<<ab)-1) : 0;
		return (cr << rs) | (cg << gs) | (cb << bs) | (ca << as);
	}
}}

unsigned int VGColorPack(VGColor color,KGSurface *img) {
	RI_ASSERT(color.r >= 0.0f && color.r <= 1.0f);
	RI_ASSERT(color.g >= 0.0f && color.g <= 1.0f);
	RI_ASSERT(color.b >= 0.0f && color.b <= 1.0f);
	RI_ASSERT(color.a >= 0.0f && color.a <= 1.0f);

	RI_ASSERT(!(color.m_format & VGColorPREMULTIPLIED) || (color.r <= color.a && color.g <= color.a && color.b <= color.a));	//premultiplied colors must have color channels less than or equal to alpha
	RI_ASSERT((color.m_format & VGColorLUMINANCE && color.r == color.g && color.r == color.b) || !(color.m_format & VGColorLUMINANCE));	//if luminance, r=g=b

	int rb = img->m_desc.redBits;
	int gb = img->m_desc.greenBits;
	int bb = img->m_desc.blueBits;
	int ab = img->m_desc.alphaBits;
	int lb = img->m_desc.luminanceBits;
	int rs = img->m_desc.redShift;
	int gs = img->m_desc.greenShift;
	int bs = img->m_desc.blueShift;
	int as = img->m_desc.alphaShift;
	int ls = img->m_desc.luminanceShift;

	if(lb)
	{	//luminance
		RI_ASSERT(color.m_format & VGColorLUMINANCE);
		return colorToInt(color.r, (1<<lb)-1) << ls;
	}
	else
	{	//rgb
		RI_ASSERT(!(color.m_format & VGColorLUMINANCE));
		unsigned int cr = rb ? colorToInt(color.r, (1<<rb)-1) : 0;
		unsigned int cg = gb ? colorToInt(color.g, (1<<gb)-1) : 0;
		unsigned int cb = bb ? colorToInt(color.b, (1<<bb)-1) : 0;
		unsigned int ca = ab ? colorToInt(color.a, (1<<ab)-1) : 0;
		return (cr << rs) | (cg << gs) | (cb << bs) | (ca << as);
	}
}

/*-------------------------------------------------------------------*//*!
* \brief	Converts from the current internal format to another.
* \param	
* \return	
* \note		
*//*-------------------------------------------------------------------*/

// Can't use 'gamma' ?
static RIfloat dogamma(RIfloat c)
{    
	if( c <= 0.00304f )
		c *= 12.92f;
	else
		c = 1.0556f * (RIfloat)pow(c, 1.0f/2.4f) - 0.0556f;
	return c;
}

static RIfloat invgamma(RIfloat c)
{
	if( c <= 0.03928f )
		c /= 12.92f;
	else
		c = (RIfloat)pow((c + 0.0556f)/1.0556f, 2.4f);
	return c;
}

static RIfloat lRGBtoL(RIfloat r, RIfloat g, RIfloat b)
{
	return 0.2126f*r + 0.7152f*g + 0.0722f*b;
}

VGColor VGColorConvert(VGColor result,VGColorInternalFormat outputFormat){
	RI_ASSERT(result.r >= 0.0f && result.r <= 1.0f);
	RI_ASSERT(result.g >= 0.0f && result.g <= 1.0f);
	RI_ASSERT(result.b >= 0.0f && result.b <= 1.0f);
	RI_ASSERT(result.a >= 0.0f && result.a <= 1.0f);
	RI_ASSERT((result.m_format & VGColorLUMINANCE && result.r == result.g && result.r == result.b) || !(result.m_format & VGColorLUMINANCE));	//if luminance, r=g=b

	if( result.m_format == outputFormat )
		return result;

	if(result.m_format & VGColorPREMULTIPLIED)
	{	//unpremultiply
		RI_ASSERT(result.r <= result.a);
		RI_ASSERT(result.g <= result.a);
		RI_ASSERT(result.b <= result.a);
		RIfloat ooa = (result.a != 0.0f) ? 1.0f / result.a : (RIfloat)0.0f;
		result.r *= ooa;
		result.g *= ooa;
		result.b *= ooa;
	}

	//From Section 3.4.2 of OpenVG 1.0.1 spec
	//1: sRGB = gamma(lRGB)
	//2: lRGB = invgamma(sRGB)
	//3: lL = 0.2126 lR + 0.7152 lG + 0.0722 lB
	//4: lRGB = lL
	//5: sL = gamma(lL)
	//6: lL = invgamma(sL)
	//7: sRGB = sL

	//Source/Dest lRGB sRGB   lL   sL 
	//lRGB          —    1    3    3,5 
	//sRGB          2    —    2,3  2,3,5 
	//lL            4    4,1  —    5 
	//sL            7,2  7    6    — 

	const unsigned int shift = 3;
	unsigned int conversion = (result.m_format & (VGColorNONLINEAR | VGColorLUMINANCE)) | ((outputFormat & (VGColorNONLINEAR | VGColorLUMINANCE)) << shift);

	switch(conversion)
	{
	case VGColor_lRGBA | (VGColor_sRGBA << shift): result.r = dogamma(result.r); result.g = dogamma(result.g); result.b = dogamma(result.b); break;							//1
	case VGColor_lRGBA | (VGColor_lLA << shift)  : result.r = result.g = result.b = lRGBtoL(result.r, result.g, result.b); break;										//3
	case VGColor_lRGBA | (VGColor_sLA << shift)  : result.r = result.g = result.b = dogamma(lRGBtoL(result.r, result.g, result.b)); break;								//3,5
	case VGColor_sRGBA | (VGColor_lRGBA << shift): result.r = invgamma(result.r); result.g = invgamma(result.g); result.b = invgamma(result.b); break;				//2
	case VGColor_sRGBA | (VGColor_lLA << shift)  : result.r = result.g = result.b = lRGBtoL(invgamma(result.r), invgamma(result.g), invgamma(result.b)); break;		//2,3
	case VGColor_sRGBA | (VGColor_sLA << shift)  : result.r = result.g = result.b = dogamma(lRGBtoL(invgamma(result.r), invgamma(result.g), invgamma(result.b))); break;//2,3,5
	case VGColor_lLA   | (VGColor_lRGBA << shift): break;																	//4
	case VGColor_lLA   | (VGColor_sRGBA << shift): result.r = result.g = result.b = dogamma(result.r); break;												//4,1
	case VGColor_lLA   | (VGColor_sLA << shift)  : result.r = result.g = result.b = dogamma(result.r); break;												//5
	case VGColor_sLA   | (VGColor_lRGBA << shift): result.r = result.g = result.b = invgamma(result.r); break;											//7,2
	case VGColor_sLA   | (VGColor_sRGBA << shift): break;																	//7
	case VGColor_sLA   | (VGColor_lLA << shift)  : result.r = result.g = result.b = invgamma(result.r); break;											//6
	default: RI_ASSERT((result.m_format & (VGColorLUMINANCE | VGColorNONLINEAR)) == (outputFormat & (VGColorLUMINANCE | VGColorNONLINEAR))); break;	//nop
	}

	if(outputFormat & VGColorPREMULTIPLIED)
	{	//premultiply
		result.r *= result.a;
		result.g *= result.a;
		result.b *= result.a;
		RI_ASSERT(result.r <= result.a);
		RI_ASSERT(result.g <= result.a);
		RI_ASSERT(result.b <= result.a);
	}
	result.m_format = outputFormat;
    return result;
}

/*-------------------------------------------------------------------*//*!
* \brief	Creates a pixel format descriptor out of KGSurfaceFormat
* \param	
* \return	
* \note		
*//*-------------------------------------------------------------------*/

VGPixelDecode KGSurfaceParametersToPixelLayout(KGSurfaceFormat format,size_t *bitsPerPixel,VGColorInternalFormat	*colorFormat){
	VGPixelDecode desc;
	memset(&desc, 0, sizeof(VGPixelDecode));
	RI_ASSERT(KGSurfaceIsValidFormat(format));

	int baseFormat = (int)format & 15;
	RI_ASSERT(baseFormat >= 0 && baseFormat <= 12);
	int swizzleBits = ((int)format >> 6) & 3;

	/* base formats
	VG_sRGBX_8888                               =  0,
	VG_sRGBA_8888                               =  1,
	VG_sRGBA_8888_PRE                           =  2,
	VG_sRGB_565                                 =  3,
	VG_sRGBA_5551                               =  4,
	VG_sRGBA_4444                               =  5,
	VG_sL_8                                     =  6,
	VG_lRGBX_8888                               =  7,
	VG_lRGBA_8888                               =  8,
	VG_lRGBA_8888_PRE                           =  9,
	VG_lL_8                                     = 10,
	VG_A_8                                      = 11,
	VG_BW_1                                     = 12,
	*/

	static const int redBits[13] =       {8, 8, 8, 5, 5, 4, 0, 8, 8, 8, 0, 0, 0};
	static const int greenBits[13] =     {8, 8, 8, 6, 5, 4, 0, 8, 8, 8, 0, 0, 0};
	static const int blueBits[13] =      {8, 8, 8, 5, 5, 4, 0, 8, 8, 8, 0, 0, 0};
	static const int alphaBits[13] =     {0, 8, 8, 0, 1, 4, 0, 0, 8, 8, 0, 8, 0};
	static const int luminanceBits[13] = {0, 0, 0, 0, 0, 0, 8, 0, 0, 0, 8, 0, 1};

	static const int redShifts[4*13] =   {24, 24, 24, 11, 11, 12, 0, 24, 24, 24, 0, 0, 0,	//RGBA
                                          16, 16, 16, 11, 10, 8,  0, 16, 16, 16, 0, 0, 0,	//ARGB
                                          8,  8,  8,  0,  1,  4,  0, 8,  8,  8,  0, 0, 0,	//BGRA
                                          0,  0,  0,  0,  0,  0,  0, 0,  0,  0,  0, 0, 0};	//ABGR

	static const int greenShifts[4*13] = {16, 16, 16, 5,  6,  8,  0, 16, 16, 16, 0, 0, 0,	//RGBA
                                          8,  8,  8,  5,  5,  4,  0, 8,  8,  8,  0, 0, 0,	//ARGB
                                          16, 16, 16, 5,  6,  8,  0, 16, 16, 16, 0, 0, 0,	//BGRA
                                          8,  8,  8,  5,  5,  4,  0, 8,  8,  8,  0, 0, 0};	//ABGR

	static const int blueShifts[4*13] =  {8,  8,  8,  0,  1,  4,  0, 8,  8,  8,  0, 0, 0,	//RGBA
                                          0,  0,  0,  0,  0,  0,  0, 0,  0,  0,  0, 0, 0,	//ARGB
                                          24, 24, 24, 11, 11, 12, 0, 24, 24, 24, 0, 0, 0,	//BGRA
                                          16, 16, 16, 11, 10, 8,  0, 16, 16, 16, 0, 0, 0};	//ABGR

	static const int alphaShifts[4*13] = {0,  0,  0,  0,  0,  0,  0, 0,  0,  0,  0, 0, 0,	//RGBA
                                          0,  24, 24, 0,  15, 12, 0, 0,  24, 24, 0, 0, 0,	//ARGB
                                          0,  0,  0,  0,  0,  0,  0, 0,  0,  0,  0, 0, 0,	//BGRA
                                          0,  24, 24, 0,  15, 12, 0, 0,  24, 24, 0, 0, 0};	//ABGR

	static const int bpps[13] = {32, 32, 32, 16, 16, 16, 8, 32, 32, 32, 8, 8, 1};

	static const VGColorInternalFormat internalFormats[13] = {VGColor_sRGBA, VGColor_sRGBA, VGColor_sRGBA_PRE, VGColor_sRGBA, VGColor_sRGBA, VGColor_sRGBA, VGColor_sLA, VGColor_lRGBA, VGColor_lRGBA, VGColor_lRGBA_PRE, VGColor_lLA, VGColor_lRGBA, VGColor_lLA};

	desc.redBits = redBits[baseFormat];
	desc.greenBits = greenBits[baseFormat];
	desc.blueBits = blueBits[baseFormat];
	desc.alphaBits = alphaBits[baseFormat];
	desc.luminanceBits = luminanceBits[baseFormat];

	desc.redShift = redShifts[swizzleBits * 13 + baseFormat];
	desc.greenShift = greenShifts[swizzleBits * 13 + baseFormat];
	desc.blueShift = blueShifts[swizzleBits * 13 + baseFormat];
	desc.alphaShift = alphaShifts[swizzleBits * 13 + baseFormat];
	desc.luminanceShift = 0;	//always zero

	*bitsPerPixel = bpps[baseFormat];
	*colorFormat = internalFormats[baseFormat];

	return desc;
}



BOOL KGSurfaceParametersAreValid(VGPixelDecode desc,KGSurfaceFormat imageFormat,size_t bitsPerPixel,VGColorInternalFormat colorFormat){
	//A valid descriptor has 1, 8, 16, or 32 bits per pixel, and either luminance or rgba channels, but not both.
	//Any of the rgba channels can be missing, and not all bits need to be used. Maximum channel bit depth is 8.
	int rb = desc.redBits;
	int gb = desc.greenBits;
	int bb = desc.blueBits;
	int ab = desc.alphaBits;
	int lb = desc.luminanceBits;
	int rs = desc.redShift;
	int gs = desc.greenShift;
	int bs = desc.blueShift;
	int as = desc.alphaShift;
	int ls = desc.luminanceShift;
	int bpp = bitsPerPixel;

	int rgbaBits = rb + gb + bb + ab;
	if(rb < 0 || rb > 8 || rs < 0 || rs + rb > bpp || !(rb || !rs))
		return NO;	//invalid channel description
	if(gb < 0 || gb > 8 || gs < 0 || gs + gb > bpp || !(gb || !gs))
		return NO;	//invalid channel description
	if(bb < 0 || bb > 8 || bs < 0 || bs + bb > bpp || !(bb || !bs))
		return NO;	//invalid channel description
	if(ab < 0 || ab > 8 || as < 0 || as + ab > bpp || !(ab || !as))
		return NO;	//invalid channel description
	if(lb < 0 || lb > 8 || ls < 0 || ls + lb > bpp || !(lb || !ls))
		return NO;	//invalid channel description

	if(rgbaBits && lb)
		return NO;	//can't have both rgba and luminance
	if(!rgbaBits && !lb)
		return NO;	//must have either rgba or luminance
	if(rgbaBits)
	{	//rgba
		if(rb+gb+bb == 0)
		{	//alpha only
			if(rs || gs || bs || as || ls)
				return NO;	//wrong shifts (even alpha shift must be zero)
			if(ab != 8 || bpp != ab)
				return NO;	//alpha size must be 8, bpp must match
		}
		else
		{	//rgba
			if(rgbaBits > bpp)
				return NO;	//bpp must be greater than or equal to the sum of rgba bits
			if(!(bpp == 32 || bpp == 16 || bpp == 8))
				return NO;	//only 1, 2, and 4 byte formats are supported for rgba
			
			unsigned int rm = bitsToMask((unsigned int)rb, (unsigned int)rs);
			unsigned int gm = bitsToMask((unsigned int)gb, (unsigned int)gs);
			unsigned int bm = bitsToMask((unsigned int)bb, (unsigned int)bs);
			unsigned int am = bitsToMask((unsigned int)ab, (unsigned int)as);
			if((rm & gm) || (rm & bm) || (rm & am) || (gm & bm) || (gm & am) || (bm & am))
				return NO;	//channels overlap
		}
	}
	else
	{	//luminance
		if(rs || gs || bs || as || ls)
			return NO;	//wrong shifts (even luminance shift must be zero)
		if(!(lb == 1 || lb == 8) || bpp != lb)
			return NO;	//luminance size must be either 1 or 8, bpp must match
	}

	if(imageFormat != -1)
	{
		if(!KGSurfaceIsValidFormat(imageFormat))
			return NO;	//invalid image format

        size_t checkBpp;
        VGColorInternalFormat checkFormat;
		VGPixelDecode d = KGSurfaceParametersToPixelLayout(imageFormat,&checkBpp,&checkFormat);
		if(d.redBits != rb || d.greenBits != gb || d.blueBits != bb || d.alphaBits != ab || d.luminanceBits != lb ||
		   d.redShift != rs || d.greenShift != gs || d.blueShift != bs || d.alphaShift != as || d.luminanceShift != ls ||
		   checkBpp != bpp)
		   return NO;	//if the descriptor has a KGSurfaceFormat, it must match the bits, shifts, and bpp
	}

	if((unsigned int)colorFormat & ~(VGColorPREMULTIPLIED | VGColorNONLINEAR | VGColorLUMINANCE))
		return NO;	//invalid internal format

	return YES;
}


static unsigned char colorToByte(RIfloat c){
	return RI_INT_MIN(RI_INT_MAX(RI_FLOOR_TO_INT(c * (RIfloat)0xFF + 0.5f), 0), 0xFF);
}

static void KGSurfaceWritePixelSpan_RGBA_8888(KGSurface *self,int x,int y,KGRGBA *span,int length){
   RIuint8* scanline = self->_bytes + y * self->_bytesPerRow;
   int i;
   
   scanline+=x*4;
   for(i=0;i<length;i++){
    KGRGBA rgba=*span++;
    unsigned char cr = colorToByte(rgba.r);
    unsigned char cg = colorToByte(rgba.g);
    unsigned char cb = colorToByte(rgba.b);
    unsigned char ca = colorToByte(rgba.a);

#if 0
    *scanline++=cr;
    *scanline++=cg;
    *scanline++=cb;
    *scanline++=ca;
#else
    *scanline++=ca;
    *scanline++=cb;
    *scanline++=cg;
    *scanline++=cr;
#endif
   }
}

static void KGSurfaceWritePixelSpan_32(KGSurface *self,int x,int y,KGRGBA *span,int length){
   RIuint8* scanline = self->_bytes + y * self->_bytesPerRow;
   int i;
   
   for(i=0;i<length;i++,x++){
    unsigned int p=KGRGBAPack(span[i],self);
    
		RIuint32* s = ((RIuint32*)scanline) + x;
		*s = (RIuint32)p;
   }
}

static void KGSurfaceWritePixelSpan_16(KGSurface *self,int x,int y,KGRGBA *span,int length){
   RIuint8* scanline = self->_bytes + y * self->_bytesPerRow;
   int i;
   
   for(i=0;i<length;i++,x++){
    unsigned int p=KGRGBAPack(span[i],self);
    
		RIuint16* s = ((RIuint16*)scanline) + x;
		*s = (RIuint16)p;
    
   }
}

static void KGSurfaceWritePixelSpan_08(KGSurface *self,int x,int y,KGRGBA *span,int length){
   RIuint8* scanline = self->_bytes + y * self->_bytesPerRow;
   int i;
   
   for(i=0;i<length;i++,x++){
    unsigned int p=KGRGBAPack(span[i],self);
		RIuint8* s = ((RIuint8*)scanline) + x;
		*s = (RIuint8)p;
   }
}

static void KGSurfaceWritePixelSpan_01(KGSurface *self,int x,int y,KGRGBA *span,int length){
   RIuint8* scanline = self->_bytes + y * self->_bytesPerRow;
   int i;
   
   for(i=0;i<length;i++,x++){
    unsigned int p=KGRGBAPack(span[i],self);
		RIuint8* s = scanline + (x>>3);
		RIuint8 d = *s;
		d &= ~(1<<(x&7));
		d |= (RIuint8)(p<<(x&7));
		*s = d;
   
   }
}

static BOOL initFunctionsForParameters(KGSurface *self,size_t bitsPerComponent,size_t bitsPerPixel,KGColorSpace *colorSpaceName,CGBitmapInfo bitmapInfo,KGSurfaceFormat imageFormat){

   switch(bitsPerComponent){
    case 32:
    
    case  8:
     switch(bitsPerPixel){
     }
     break;
     
    case  4:
    case  2:
    case  1:
     break;
   }
   
   switch(imageFormat){
    case VG_sRGBA_8888:
    case VG_lRGBA_8888:
     self->_readSpan=KGImageReadPixelSpan_RGBA_8888;
     self->_writeSpan=KGSurfaceWritePixelSpan_RGBA_8888;
     return YES;
     
    case VG_sRGBA_8888_PRE:
    case VG_lRGBA_8888_PRE:
     self->_readSpan=KGImageReadPixelSpan_RGBA_8888;
     self->_writeSpan=KGSurfaceWritePixelSpan_RGBA_8888;
     return YES;

    default:
     switch(bitsPerPixel){
      case 32:
       if(bitmapInfo&kCGBitmapFloatComponents){
       }
       else {
        switch(bitmapInfo&kCGBitmapAlphaInfoMask){
         case kCGImageAlphaNone:
          break;
        }
        
        self->_readSpan=KGImageReadPixelSpan_32;
          self->_writeSpan=KGSurfaceWritePixelSpan_32;
        return YES;
       }

      case 16:
       self->_readSpan=KGImageReadPixelSpan_16;
          self->_writeSpan=KGSurfaceWritePixelSpan_16;
       return YES;
 
      case  8:
       self->_readSpan=KGImageReadPixelSpan_08;
          self->_writeSpan=KGSurfaceWritePixelSpan_08;
       return YES;
     
      case  1:
       self->_readSpan=KGImageReadPixelSpan_01;
         self->_writeSpan=KGSurfaceWritePixelSpan_01;
       return YES;
     }
     break;
   }
   return NO;
   
}

//clamp premultiplied color to alpha to enforce consistency
static void clampPremultipliedSpan(KGRGBA *span,int length){
   int i;
   
   for(i=0;i<length;i++){
    span[i].r = RI_MIN(span[i].r, span[i].a);
    span[i].g = RI_MIN(span[i].g, span[i].a);
    span[i].b = RI_MIN(span[i].b, span[i].a);
   }
}

KGSurface *KGSurfaceAlloc() {
   return (KGSurface *)NSZoneCalloc(NULL,1,sizeof(KGSurface));
}

KGSurface *KGSurfaceInit(KGSurface *self,size_t width, size_t height,size_t bitsPerComponent,size_t bitsPerPixel,KGColorSpace *colorSpace,CGBitmapInfo bitmapInfo,KGSurfaceFormat imageFormat){
	self->_width=width;
	self->_height=height;
    self->_bitsPerComponent=bitsPerComponent;
    self->_bitsPerPixel=bitsPerPixel;
	self->_bytesPerRow=0;
    self->_colorSpace=[colorSpace copy];
    self->_bitmapInfo=bitmapInfo;
    
    if(!initFunctionsForParameters(self,bitsPerComponent,bitsPerPixel,colorSpace,bitmapInfo,imageFormat))
     NSLog(@"error, return");
    
    self->_imageFormat=imageFormat;
    size_t checkBPP;
	self->m_desc=KGSurfaceParametersToPixelLayout(imageFormat,&checkBPP,&(self->_colorFormat));
    RI_ASSERT(checkBPP==bitsPerPixel);
    
	self->_bytes=NULL;
	self->m_ownsData=YES;
    self->_clampExternalPixels=NO; // only set to yes if premultiplied
	self->m_mipmapsValid=NO;

	RI_ASSERT(KGSurfaceParametersAreValid(self->m_desc,self->_imageFormat,self->_bitsPerPixel,self->_colorFormat));
	RI_ASSERT(width > 0 && height > 0);
	
	if( self->_bitsPerPixel != 1 )
	{
		RI_ASSERT(self->_bitsPerPixel == 8 || self->_bitsPerPixel == 16 || self->_bitsPerPixel == 32);
		self->_bytesPerRow = self->_width*self->_bitsPerPixel/8;
	}
	else
	{
		RI_ASSERT(self->_bitsPerPixel == 1);
		self->_bytesPerRow = (self->_width+7)/8;
	}
	self->_bytes = NSZoneMalloc(NULL,self->_bytesPerRow*self->_height*sizeof(RIuint8));
	memset(self->_bytes, 0, self->_bytesPerRow*self->_height);	//clear image
    self->_mipmapsCount=0;
    self->_mipmapsCapacity=2;
    self->_mipmaps=(KGSurface **)NSZoneMalloc(NULL,self->_mipmapsCapacity*sizeof(KGSurface *));
    return self;
}

KGSurface *KGSurfaceInitWithBytes(KGSurface *self,size_t width,size_t height,size_t bitsPerComponent,size_t bitsPerPixel,size_t bytesPerRow,KGColorSpace *colorSpace,CGBitmapInfo bitmapInfo,KGSurfaceFormat imageFormat,RIuint8* data) {
	self->_width=width;
	self->_height=height;
    self->_bitsPerComponent=bitsPerComponent;
    self->_bitsPerPixel=bitsPerPixel;
	self->_bytesPerRow=bytesPerRow;
    self->_colorSpace=[colorSpace copy];
    self->_bitmapInfo=bitmapInfo;
    if(!initFunctionsForParameters(self,bitsPerComponent,bitsPerPixel,colorSpace,bitmapInfo,imageFormat))
     NSLog(@"error, return");

    self->_imageFormat=imageFormat;
    size_t checkBPP;
	self->m_desc=KGSurfaceParametersToPixelLayout(imageFormat,&checkBPP,&(self->_colorFormat));
    RI_ASSERT(checkBPP==bitsPerPixel);

	self->_bytes=data;
	self->m_ownsData=NO;
    self->_clampExternalPixels=NO; // only set to yes if premultiplied
	self->m_mipmapsValid=NO;
	RI_ASSERT(KGSurfaceParametersAreValid(self->m_desc,self->_imageFormat,self->_bitsPerPixel,self->_colorFormat));
	RI_ASSERT(width > 0 && height > 0);
	RI_ASSERT(data);
    self->_mipmapsCount=0;
    self->_mipmapsCapacity=2;
    self->_mipmaps=(KGSurface **)NSZoneMalloc(NULL,self->_mipmapsCapacity*sizeof(KGSurface *));
    return self;
}

void KGSurfaceDealloc(KGSurface *self) {
    int i;
    
	for(i=0;i<self->_mipmapsCount;i++){
			KGSurfaceDealloc(self->_mipmaps[i]);
	}
	self->_mipmapsCount=0;

	if(self->m_ownsData)
	{
		NSZoneFree(NULL,self->_bytes);	//delete image data if we own it
	}
}

/*-------------------------------------------------------------------*//*!
* \brief	Resizes an image. New pixels are set to the given color.
* \param	
* \return	
* \note		
*//*-------------------------------------------------------------------*/

void KGSurfaceResize(KGSurface *self,int newWidth, int newHeight, VGColor newPixelColor){
	RI_ASSERT(newWidth > 0 && newHeight > 0);

	//destroy mipmaps
    int i;
	for(i=0;i<self->_mipmapsCount;i++)
	{
			KGSurfaceDealloc(self->_mipmaps[i]);
	}
	self->_mipmapsCount=0;
	self->m_mipmapsValid = NO;
	
	int newStride;
	if( self->_bitsPerPixel != 1 )
	{
		RI_ASSERT(self->_bitsPerPixel == 8 || self->_bitsPerPixel == 16 || self->_bitsPerPixel == 32);
		newStride = newWidth*self->_bitsPerPixel/8;
	}
	else
	{
		RI_ASSERT(self->_bitsPerPixel == 1);
		newStride = (newWidth+7)/8;
	}

	RIuint8* newData = NSZoneMalloc(NULL,sizeof(RIuint8)*newStride*newHeight);

	VGColor col = newPixelColor;
	col=VGColorClamp(col);
	col=VGColorConvert(col,self->_colorFormat);
	unsigned int c = VGColorPack(col,self);

	int w = RI_INT_MIN(self->_width, newWidth);
    int j;
	for(j=0;j<newHeight;j++)
	{
		if(j >= self->_height)
			w = 0;		//clear new scanlines
		RIuint8* d = newData + j * newStride;
		RIuint8* s = self->_bytes + j * self->_bytesPerRow;
		switch(self->_bitsPerPixel)
		{
		case 32:
		{
			for(i=0;i<w;i++)
			{
				*(RIuint32*)d = *(RIuint32*)s;	//copy old pixels
				d += 4; s += 4;
			}
			for(i=w;i<newWidth;i++)
			{
				*(RIuint32*)d = (RIuint32)c;	//clear new pixels
				d += 4;
			}
			break;
		}

		case 16:
		{
			for(i=0;i<w;i++)
			{
				*(RIuint16*)d = *(RIuint16*)s;	//copy old pixels
				d += 2; s += 2;
			}
			for(i=w;i<newWidth;i++)
			{
				*(RIuint16*)d = (RIuint16)c;	//clear new pixels
				d += 2;
			}
			break;
		}

		case 8:
		{
			for(i=0;i<w;i++)
				*d++ = *s++;	//copy old pixels
			for(i=w;i<newWidth;i++)
				*d++ = (RIuint8)c;	//clear new pixels
			break;
		}

		default:
		{
			RI_ASSERT(self->_bitsPerPixel == 1);
			if( c )
				c = 0xff;
			int e = w>>3;	//number of full bytes
			for(i=0;i<e;i++)
				*d++ = *s++;	//copy old pixels

			//copy end leftovers and clear the rest
			int numLeftoverBits = w - (e<<3);
			RI_ASSERT(numLeftoverBits >= 0 && numLeftoverBits < 8);
			if( numLeftoverBits )
			{
				unsigned int maskBits = ((1 << numLeftoverBits) - 1);
				unsigned int l = ((unsigned int)*s) & maskBits;
				if( c )
					l |= ~maskBits;
				*d++ = (RIuint8)l;
				e++;
			}

			for(i=e;i<((newWidth+7)>>3);i++)
				*d++ = (RIuint8)c;	//clear new pixels
			break;
		}
		}
	}

	NSZoneFree(NULL,self->_bytes);
	self->_bytes = newData;
	self->_width = newWidth;
	self->_height = newHeight;
	self->_bytesPerRow = newStride;
}

/*-------------------------------------------------------------------*//*!
* \brief	Clears a rectangular portion of an image with the given clear color.
* \param	
* \return	
* \note		
*//*-------------------------------------------------------------------*/

void KGSurfaceClear(KGSurface *self,VGColor clearColor, int x, int y, int w, int h){
	RI_ASSERT(self->_bytes);

	//intersect clear region with image bounds
	KGIntRect r=KGIntRectInit(0,0,self->_width,self->_height);
	r=KGIntRectIntersect(r,KGIntRectInit(x,y,w,h));
	if(!r.width || !r.height)
		return;		//intersection is empty or one of the rectangles is invalid

	VGColor col = clearColor;
	col=VGColorClamp(col);
	col=VGColorConvert(col,self->_colorFormat);

    int j;
	for(j=r.y;j<r.y + r.height;j++)
	{
        int i;
		for(i=r.x;i<r.x + r.width;i++)
		{
			KGSurfaceWritePixel(self,i, j, col);
		}
	}

	self->m_mipmapsValid = NO;
}

/*-------------------------------------------------------------------*//*!
* \brief	Blits a source region to destination. Source and destination
*			can overlap.
* \param	
* \return	
* \note		
*//*-------------------------------------------------------------------*/

static RIfloat ditherChannel(RIfloat c, int bits, RIfloat m)
{
	RIfloat fc = c * (RIfloat)((1<<bits)-1);
	RIfloat ic = (RIfloat)floor(fc);
	if(fc - ic > m) ic += 1.0f;
	return RI_MIN(ic / (RIfloat)((1<<bits)-1), 1.0f);
}

void KGSurfaceBlit(KGSurface *self,KGSurface * src, int sx, int sy, int dx, int dy, int w, int h, BOOL dither) {
	RI_ASSERT(src->_bytes);	//source exists
	RI_ASSERT(self->_bytes);	//destination exists
	RI_ASSERT(w > 0 && h > 0);

	sx = RI_INT_MIN(RI_INT_MAX(sx, (int)(RI_INT32_MIN>>2)), (int)(RI_INT32_MAX>>2));
	sy = RI_INT_MIN(RI_INT_MAX(sy, (int)(RI_INT32_MIN>>2)), (int)(RI_INT32_MAX>>2));
	dx = RI_INT_MIN(RI_INT_MAX(dx, (int)(RI_INT32_MIN>>2)), (int)(RI_INT32_MAX>>2));
	dy = RI_INT_MIN(RI_INT_MAX(dy, (int)(RI_INT32_MIN>>2)), (int)(RI_INT32_MAX>>2));
	w = RI_INT_MIN(w, (int)(RI_INT32_MAX>>2));
	h = RI_INT_MIN(h, (int)(RI_INT32_MAX>>2));
	int srcsx = sx, srcex = sx + w, dstsx = dx, dstex = dx + w;
	if(srcsx < 0)
	{
		dstsx -= srcsx;
		srcsx = 0;
	}
	if(srcex > src->_width)
	{
		dstex -= srcex - src->_width;
		srcex = src->_width;
	}
	if(dstsx < 0)
	{
		srcsx -= dstsx;
		dstsx = 0;
	}
	if(dstex > self->_width)
	{
		srcex -= dstex - self->_width;
		dstex = self->_width;
	}
	RI_ASSERT(srcsx >= 0 && dstsx >= 0 && srcex <= src->_width && dstex <= self->_width);
	w = srcex - srcsx;
	RI_ASSERT(w == dstex - dstsx);
	if(w <= 0)
		return;	//zero area

	int srcsy = sy, srcey = sy + h, dstsy = dy, dstey = dy + h;
	if(srcsy < 0)
	{
		dstsy -= srcsy;
		srcsy = 0;
	}
	if(srcey > src->_height)
	{
		dstey -= srcey - src->_height;
		srcey = src->_height;
	}
	if(dstsy < 0)
	{
		srcsy -= dstsy;
		dstsy = 0;
	}
	if(dstey > self->_height)
	{
		srcey -= dstey - self->_height;
		dstey = self->_height;
	}
	RI_ASSERT(srcsy >= 0 && dstsy >= 0 && srcey <= src->_height && dstey <= self->_height);
	h = srcey - srcsy;
	RI_ASSERT(h == dstey - dstsy);
	if(h <= 0)
		return;	//zero area

	VGColor *tmp=(VGColor *)NSZoneMalloc(NULL,w*h*sizeof(VGColor));

	//copy source region to tmp
    int j;
	for(j=0;j<h;j++)
	{
        int i;
		for(i=0;i<w;i++)
		{
			VGColor c = KGSurfaceReadPixel(src,srcsx + i, srcsy + j);
			c=VGColorConvert(c,self->_colorFormat);
			tmp[j*w+i] = c;
		}
	}

	int rbits = self->m_desc.redBits, gbits = self->m_desc.greenBits, bbits = self->m_desc.blueBits, abits = self->m_desc.alphaBits;
	if(self->m_desc.luminanceBits)
	{
		rbits = gbits = bbits = self->m_desc.luminanceBits;
		abits = 0;
	}

	//write tmp to destination region
	for(j=0;j<h;j++)
	{
        int i;
		for(i=0;i<w;i++)
		{
			VGColor col = tmp[j*w+i];

			if(dither)
			{
				static const int matrix[16] = {
					0,  8,  2,  10,
					12, 4,  14, 6,
					3,  11, 1,  9,
					15, 7,  13, 5};
				int x = i & 3;
				int y = j & 3;
				RIfloat m = matrix[y*4+x] / 16.0f;

				if(rbits) col.r = ditherChannel(col.r, rbits, m);
				if(gbits) col.g = ditherChannel(col.g, gbits, m);
				if(bbits) col.b = ditherChannel(col.b, bbits, m);
				if(abits) col.a = ditherChannel(col.a, abits, m);
			}

			KGSurfaceWritePixel(self,dstsx + i, dstsy + j, col);
		}
	}
    NSZoneFree(NULL,tmp);
	self->m_mipmapsValid = NO;
}

/*-------------------------------------------------------------------*//*!
* \brief	Applies a mask operation to a rectangular portion of a mask image.
* \param	
* \return	
* \note		
*//*-------------------------------------------------------------------*/

void KGSurfaceMask(KGSurface *self,KGSurface* src, VGMaskOperation operation, int x, int y, int w, int h) {
	RI_ASSERT(self->_bytes);	//destination exists
	RI_ASSERT(w > 0 && h > 0);

	self->m_mipmapsValid = NO;
	if(operation == VG_CLEAR_MASK)
	{
		KGSurfaceClear(self,VGColorRGBA(0,0,0,0,VGColor_lRGBA), x, y, w, h);
		return;
	}
	if(operation == VG_FILL_MASK)
	{
		KGSurfaceClear(self,VGColorRGBA(1,1,1,1,VGColor_lRGBA), x, y, w, h);
		return;
	}

	RI_ASSERT(src->_bytes);	//source exists

	//intersect destination region with source and destination image bounds
	x = RI_INT_MIN(RI_INT_MAX(x, (int)(RI_INT32_MIN>>2)), (int)(RI_INT32_MAX>>2));
	y = RI_INT_MIN(RI_INT_MAX(y, (int)(RI_INT32_MIN>>2)), (int)(RI_INT32_MAX>>2));
	w = RI_INT_MIN(w, (int)(RI_INT32_MAX>>2));
	h = RI_INT_MIN(h, (int)(RI_INT32_MAX>>2));

	int srcsx = 0, srcex = w, dstsx = x, dstex = x + w;
	if(srcex > src->_width)
	{
		dstex -= srcex - src->_width;
		srcex = src->_width;
	}
	if(dstsx < 0)
	{
		srcsx -= dstsx;
		dstsx = 0;
	}
	if(dstex > self->_width)
	{
		srcex -= dstex - self->_width;
		dstex = self->_width;
	}
	RI_ASSERT(srcsx >= 0 && dstsx >= 0 && srcex <= src->_width && dstex <= self->_width);
	w = srcex - srcsx;
	RI_ASSERT(w == dstex - dstsx);
	if(w <= 0)
		return;	//zero area

	int srcsy = 0, srcey = h, dstsy = y, dstey = y + h;
	if(srcey > src->_height)
	{
		dstey -= srcey - src->_height;
		srcey = src->_height;
	}
	if(dstsy < 0)
	{
		srcsy -= dstsy;
		dstsy = 0;
	}
	if(dstey > self->_height)
	{
		srcey -= dstey - self->_height;
		dstey = self->_height;
	}
	RI_ASSERT(srcsy >= 0 && dstsy >= 0 && srcey <= src->_height && dstey <= self->_height);
	h = srcey - srcsy;
	RI_ASSERT(h == dstey - dstsy);
	if(h <= 0)
		return;	//zero area

    int j;
	for(j=0;j<h;j++)
	{
        int i;
		for(i=0;i<w;i++)
		{
			RIfloat aprev = KGSurfaceReadMaskPixel(self,dstsx + i, dstsy + j);
			RIfloat amask = KGSurfaceReadMaskPixel(src,srcsx + i, srcsy + j);
			RIfloat anew = 0.0f;
			switch(operation)
			{
			case VG_SET_MASK:
				anew = amask;
				break;

			case VG_UNION_MASK:
				anew = 1.0f - (1.0f - amask)*(1.0f - aprev);
				break;

			case VG_INTERSECT_MASK:
				anew = amask * aprev;
				break;

			default:
				RI_ASSERT(operation == VG_SUBTRACT_MASK);
				anew = aprev * (1.0f - amask);
				break;
			}
			KGSurfaceWriteMaskPixel(self,dstsx + i, dstsy + j, anew);
		}
	}
}

/*-------------------------------------------------------------------*//*!
* \brief	Returns the color at pixel (x,y).
* \param	
* \return	
* \note		
*//*-------------------------------------------------------------------*/

VGColor inline KGSurfaceReadPixel(KGImage *self,int x, int y) {
	RI_ASSERT(self->_bytes);
	RI_ASSERT(x >= 0 && x < self->_width);
	RI_ASSERT(y >= 0 && y < self->_height);
 
    KGRGBA span;
    
    self->_readSpan(self,x,y,&span,1);
   
   if(self->_clampExternalPixels)
    clampPremultipliedSpan(&span,1); // We don't need to do this for internally generated images (context)

   return VGColorFromKGRGBA(span,self->_colorFormat);
}

KGRGBA inline KGSurfaceReadRGBA(KGImage *self,int x, int y) {
	RI_ASSERT(self->_bytes);
	RI_ASSERT(x >= 0 && x < self->_width);
	RI_ASSERT(y >= 0 && y < self->_height);
 
    KGRGBA span;
    
    self->_readSpan(self,x,y,&span,1);
   
   if(self->_clampExternalPixels)
    clampPremultipliedSpan(&span,1); // We don't need to do this for internally generated images (context)

   return span;
}

VGColorInternalFormat KGSurfaceReadPremultipliedSpan_ffff(KGSurface *self,int x,int y,KGRGBA *span,int length) {
   self->_readSpan(self,x,y,span,length);
   
   
   if(!(self->_colorFormat&VGColorPREMULTIPLIED))
    KGRGBPremultiplySpan(span,length);
   else if(self->_clampExternalPixels)
    clampPremultipliedSpan(span,length); // We don't need to do this for internally generated images (context)

   return self->_colorFormat|VGColorPREMULTIPLIED;
}

/*-------------------------------------------------------------------*//*!
* \brief	Writes the color to pixel (x,y). Internal color formats must
*			match.
* \param	
* \return	
* \note		
*//*-------------------------------------------------------------------*/


void KGSurfaceWritePixelSpan(KGSurface *self,int x,int y,KGRGBA *span,int length,VGColorInternalFormat format) {   
   if(length==0)
    return;
    
   convertSpan(span,length,format,self->_colorFormat);
   
   self->_writeSpan(self,x,y,span,length);
   
   self->m_mipmapsValid = NO;
}

void inline KGSurfaceWritePixel(KGSurface *self,int x, int y, VGColor c) {
	RI_ASSERT(self->_bytes);
	RI_ASSERT(x >= 0 && x < self->_width);
	RI_ASSERT(y >= 0 && y < self->_height);
	RI_ASSERT(c.m_format == self->_colorFormat);
    KGRGBA span=KGRGBAFromColor(c);
    
    KGSurfaceWritePixelSpan(self,x,y,&span,1,c.m_format);
#if 0    
	unsigned int p = VGColorPack(c,self);
	RIuint8* scanline = self->_bytes + y * self->_bytesPerRow;
	switch(self->_bitsPerPixel)
	{
	case 32:
	{
		RIuint32* s = ((RIuint32*)scanline) + x;
		*s = (RIuint32)p;
		break;
	}

	case 16:
	{
		RIuint16* s = ((RIuint16*)scanline) + x;
		*s = (RIuint16)p;
		break;
	}

	case 8:
	{
		RIuint8* s = ((RIuint8*)scanline) + x;
		*s = (RIuint8)p;
		break;
	}

	default:
	{
		RI_ASSERT(self->_bitsPerPixel == 1);
		RIuint8* s = scanline + (x>>3);
		RIuint8 d = *s;
		d &= ~(1<<(x&7));
		d |= (RIuint8)(p<<(x&7));
		*s = d;
		break;
	}
	}
	self->m_mipmapsValid = NO;
#endif
}



/*-------------------------------------------------------------------*//*!
* \brief	Writes a filtered color to destination surface
* \param	
* \return	
* \note		
*//*-------------------------------------------------------------------*/

void KGSurfaceWriteFilteredPixel(KGSurface *self,int i, int j, VGColor color, VGbitfield channelMask) {
	//section 3.4.4: before color space conversion, premultiplied colors are
	//clamped to alpha, and the color is converted to nonpremultiplied format
	//section 11.2: how to deal with channel mask
	//step 1
	VGColor f = color;
	f=VGColorClamp(f);			//vgColorMatrix and vgLookups can produce colors that exceed alpha or [0,1] range
	f=VGColorUnpremultiply(f);

	//step 2: color space conversion
	f=VGColorConvert(f,(VGColorInternalFormat)(self->_colorFormat & (VGColorNONLINEAR | VGColorLUMINANCE)));

	//step 3: read the destination color and convert it to nonpremultiplied
	VGColor d = KGSurfaceReadPixel(self,i,j);
	d=VGColorUnpremultiply(d);
	RI_ASSERT(d.m_format == f.m_format);

	//step 4: replace the destination channels specified by the channelMask
	if(channelMask & VG_RED)
		d.r = f.r;
	if(channelMask & VG_GREEN)
		d.g = f.g;
	if(channelMask & VG_BLUE)
		d.b = f.b;
	if(channelMask & VG_ALPHA)
		d.a = f.a;

	//step 5: if destination is premultiplied, convert to premultiplied format
	if(self->_colorFormat & VGColorPREMULTIPLIED)
		d=VGColorPremultiply(d);
	//write the color to destination
	KGSurfaceWritePixel(self,i,j,d);
}

/*-------------------------------------------------------------------*//*!
* \brief	Reads the pixel (x,y) and converts it into an alpha mask value.
* \param	
* \return	
* \note		
*//*-------------------------------------------------------------------*/

RIfloat KGSurfaceReadMaskPixel(KGSurface *self,int x, int y){
	RI_ASSERT(self->_bytes);
	RI_ASSERT(x >= 0 && x < self->_width);
	RI_ASSERT(y >= 0 && y < self->_height);

	VGColor c = KGSurfaceReadPixel(self,x,y);
	if(self->m_desc.luminanceBits)
	{	//luminance
		return c.r;	//luminance/luma is read into the color channels
	}
	else
	{	//rgba
		if(self->m_desc.alphaBits)
			return c.a;
		return c.r;
	}
}

void KGSurfaceReadMaskPixelSpanIntoCoverage(KGSurface *self,int x,int y,RIfloat *coverage,int length) {
   int i;
   
   for(i=0;i<length;i++,x++){
    coverage[i] *= KGSurfaceReadMaskPixel(self,x, y);
   }
}

/*-------------------------------------------------------------------*//*!
* \brief	Writes the alpha mask to pixel (x,y) of a VG_A_8 image.
* \param	
* \return	
* \note		
*//*-------------------------------------------------------------------*/

void KGSurfaceWriteMaskPixel(KGSurface *self,int x, int y, RIfloat m)	//can write only to VG_A_8
{
	RI_ASSERT(self->_bytes);
	RI_ASSERT(x >= 0 && x < self->_width);
	RI_ASSERT(y >= 0 && y < self->_height);
	RI_ASSERT(self->m_desc.alphaBits == 8 && self->m_desc.redBits == 0 && self->m_desc.greenBits == 0 && self->m_desc.blueBits == 0 && self->m_desc.luminanceBits == 0 && self->_bitsPerPixel == 8);

	RIuint8* s = ((RIuint8*)(self->_bytes + y * self->_bytesPerRow)) + x;
	*s = (RIuint8)colorToInt(m, 255);
	self->m_mipmapsValid = NO;
}

/*-------------------------------------------------------------------*//*!
* \brief	Reads a texel (u,v) at the given mipmap level. Tiling modes and
*			color space conversion are applied. Outputs color in premultiplied
*			format.
* \param	
* \return	
* \note		
*//*-------------------------------------------------------------------*/

/* Theoretically the edges of the polygon fill used to draw resampled images would
   perfectly fit the edges of the raster image, however, numerical error will probably
   place some sampled pixels outside the image. Two good choices are to use the edge value
   or zero. This uses the edge value.  I don't know what Apple does.
 */
void KGSurfaceReadTexelTilePad(KGImage *self,int u, int v, KGRGBA *span,int length){
   int i;

   v = RI_INT_CLAMP(v,0,self->_height-1);
   
   for(i=0;i<length && u<0;u++,i++)
    span[i]=KGSurfaceReadRGBA(self,0,v);

   int chunk=RI_MIN(length-i,self->_width-u);
   self->_readSpan(self,u,v,span+i,chunk);
   i+=chunk;
   u+=chunk;

   for(;i<length;i++)
    span[i]=KGSurfaceReadRGBA(self,self->_width-1,v);

   if(self->_clampExternalPixels)
    clampPremultipliedSpan(span,length); // We don't need to do this for internally generated images (context)
}

/*-------------------------------------------------------------------*//*!
* \brief	Maps point (x,y) to an image and returns a filtered,
*			premultiplied color value.
* \param	
* \return	
* \note		
*//*-------------------------------------------------------------------*/


void KGSurfaceReadTexelTileRepeat(KGSurface *self,int u, int v, KGRGBA *span,int length){
   int i;

   v = RI_INT_MOD(v, self->_height);
   
   for(i=0;i<length;i++,u++){
    u = RI_INT_MOD(u, self->_width);

	span[i]=KGRGBAPremultiply(KGSurfaceReadRGBA(self,u, v));
   }
}

void KGSurfacePattern_Bilinear(KGSurface *self,RIfloat x, RIfloat y,KGRGBA *span,int length, Matrix3x3 surfaceToImage){
   int i;
   
   for(i=0;i<length;i++,x++){
	Vector3 uvw=Vector3Make(x+0.5,y+0.5,1);
	uvw = Matrix3x3MultiplyVector3(surfaceToImage ,uvw);
	RIfloat oow = 1.0f / uvw.z;
	uvw=Vector3MultiplyByFloat(uvw,oow);
    uvw.x -= 0.5f;
	uvw.y -= 0.5f;
	int u = RI_FLOOR_TO_INT(uvw.x);
	int v = RI_FLOOR_TO_INT(uvw.y);
	KGRGBA c00c01[2];
    KGSurfaceReadTexelTileRepeat(self,u,v,c00c01,2);

    KGRGBA c01c11[2];
    KGSurfaceReadTexelTileRepeat(self,u,v+1,c01c11,2);

    RIfloat fu = uvw.x - (RIfloat)u;
    RIfloat fv = uvw.y - (RIfloat)v;
    KGRGBA c0 = KGRGBAAdd(KGRGBAMultiplyByFloat(c00c01[0],(1.0f - fu)),KGRGBAMultiplyByFloat(c00c01[1],fu));
    KGRGBA c1 = KGRGBAAdd(KGRGBAMultiplyByFloat(c01c11[0],(1.0f - fu)),KGRGBAMultiplyByFloat(c01c11[1],fu));
    span[i]=KGRGBAAdd(KGRGBAMultiplyByFloat(c0,(1.0f - fv)),KGRGBAMultiplyByFloat(c1, fv));
   }
}

void KGSurfacePattern_PointSampling(KGSurface *self,RIfloat x, RIfloat y,KGRGBA *span,int length, Matrix3x3 surfaceToImage){	//point sampling
   int i;
   
   for(i=0;i<length;i++,x++){
    Vector3 uvw=Vector3Make(x+0.5,y+0.5,1);
	uvw = Matrix3x3MultiplyVector3(surfaceToImage ,uvw);
	RIfloat oow = 1.0f / uvw.z;
	uvw=Vector3MultiplyByFloat(uvw,oow);
    KGSurfaceReadTexelTileRepeat(self,RI_FLOOR_TO_INT(uvw.x), RI_FLOOR_TO_INT(uvw.y),span+i,1);
   }
}

void KGSurfacePatternSpan(KGSurface *self,RIfloat x, RIfloat y, KGRGBA *span,int length,int colorFormat, Matrix3x3 surfaceToImage, CGPatternTiling distortion)	{
    
   switch(distortion){
    case kCGPatternTilingNoDistortion:
      KGSurfacePattern_PointSampling(self,x,y,span,length,surfaceToImage);
      break;

    case kCGPatternTilingConstantSpacingMinimalDistortion:
    case kCGPatternTilingConstantSpacing:
     default:
      KGSurfacePattern_Bilinear(self,x,y,span,length,surfaceToImage);
      break;
   }
       
   convertSpan(span,length,self->_colorFormat|VGColorPREMULTIPLIED,colorFormat);
}

/*-------------------------------------------------------------------*//*!
* \brief	Generates mip maps for an image.
* \param	
* \return	
* \note		Downsampling is done in the input color space. We use a box
*			filter for downsampling.
*//*-------------------------------------------------------------------*/

void KGSurfaceMakeMipMaps(KGImage *self) {
	RI_ASSERT(self->_bytes);

	if(self->m_mipmapsValid)
		return;

	//delete existing mipmaps
    int i;
	for(i=0;i<self->_mipmapsCount;i++)
	{
			KGSurfaceDealloc(self->_mipmaps[i]);
	}
	self->_mipmapsCount=0;

//	try
	{
		VGColorInternalFormat procFormat = self->_colorFormat;
		procFormat = (VGColorInternalFormat)(procFormat | VGColorPREMULTIPLIED);	//premultiplied

		//generate mipmaps until width and height are one
		KGImage* prev = self;
		while( prev->_width > 1 || prev->_height > 1 )
		{
			int nextw = (int)ceil(prev->_width*0.5f);
			int nexth = (int)ceil(prev->_height*0.5f);
			RI_ASSERT(nextw >= 1 && nexth >= 1);
			RI_ASSERT(nextw < prev->_width || nexth < prev->_height);

            if(self->_mipmapsCount+1>self->_mipmapsCapacity){
             self->_mipmapsCapacity*=2;
             self->_mipmaps=(KGSurface **)NSZoneRealloc(NULL,self->_mipmaps,sizeof(KGSurface *)*self->_mipmapsCapacity);
            }
            self->_mipmapsCount++;
			self->_mipmaps[self->_mipmapsCount-1] = NULL;

			KGSurface* next =  KGSurfaceInit(KGSurfaceAlloc(),nextw, nexth,self->_bitsPerComponent,self->_bitsPerPixel,self->_colorSpace,self->_bitmapInfo,self->_imageFormat);
            int j;
			for(j=0;j<next->_height;j++)
			{
				for(i=0;i<next->_width;i++)
				{
					RIfloat u0 = (RIfloat)i / (RIfloat)next->_width;
					RIfloat u1 = (RIfloat)(i+1) / (RIfloat)next->_width;
					RIfloat v0 = (RIfloat)j / (RIfloat)next->_height;
					RIfloat v1 = (RIfloat)(j+1) / (RIfloat)next->_height;

					u0 *= prev->_width;
					u1 *= prev->_width;
					v0 *= prev->_height;
					v1 *= prev->_height;

					int su = RI_FLOOR_TO_INT(u0);
					int eu = (int)ceil(u1);
					int sv = RI_FLOOR_TO_INT(v0);
					int ev = (int)ceil(v1);

					VGColor c=VGColorRGBA(0,0,0,0,procFormat);
					int samples = 0;
                    int y;
					for(y=sv;y<ev;y++)
					{
                        int x;
						for(x=su;x<eu;x++)
						{
							VGColor p = KGSurfaceReadPixel(prev,x, y);
							p=VGColorConvert(p,procFormat);
							c=VGColorAdd(c, p);
							samples++;
						}
					}
					c=VGColorMultiplyByFloat(c,(1.0f/samples));
					c=VGColorConvert(c,self->_colorFormat);
					KGSurfaceWritePixel(next,i,j,c);
				}
			}
			self->_mipmaps[self->_mipmapsCount-1] = next;
			prev = next;
		}
		RI_ASSERT(prev->_width == 1 && prev->_height == 1);
		self->m_mipmapsValid = YES;
	}
#if 0
	catch(std::bad_alloc)
	{
		//delete existing mipmaps
		for(int i=0;i<self->_mipmapsCount;i++)
		{
			if(self->_mipmaps[i])
			{
					KGSurfaceDealloc(self->_mipmaps[i]);
			}
		}
		self->_mipmapsCount=0;
		self->m_mipmapsValid = NO;
		throw;
	}
#endif
}

/*-------------------------------------------------------------------*//*!
* \brief	Applies color matrix filter.
* \param	
* \return	
* \note		
*//*-------------------------------------------------------------------*/

void KGSurfaceColorMatrix(KGSurface *self,KGSurface * src, const RIfloat* matrix, BOOL filterFormatLinear, BOOL filterFormatPremultiplied, VGbitfield channelMask) {
	RI_ASSERT(src->_bytes);	//source exists
	RI_ASSERT(self->_bytes);	//destination exists
	RI_ASSERT(matrix);

	int w = RI_INT_MIN(self->_width, src->_width);
	int h = RI_INT_MIN(self->_height, src->_height);
	RI_ASSERT(w > 0 && h > 0);

	VGColorInternalFormat srcFormat = src->_colorFormat;
	VGColorInternalFormat procFormat = (VGColorInternalFormat)(srcFormat & ~VGColorLUMINANCE);	//process in RGB, not luminance
	if(filterFormatLinear)
		procFormat = (VGColorInternalFormat)(procFormat & ~VGColorNONLINEAR);
	else
		procFormat = (VGColorInternalFormat)(procFormat | VGColorNONLINEAR);

	if(filterFormatPremultiplied)
		procFormat = (VGColorInternalFormat)(procFormat | VGColorPREMULTIPLIED);
	else
		procFormat = (VGColorInternalFormat)(procFormat & ~VGColorPREMULTIPLIED);

    int j,i;
	for(j=0;j<h;j++)
	{
		for(i=0;i<w;i++)
		{
			VGColor s = KGSurfaceReadPixel(src,i,j);	//convert to RGBA [0,1]
			s=VGColorConvert(s,procFormat);

			VGColor d=VGColorRGBA(0,0,0,0,procFormat);
			d.r = matrix[0+4*0] * s.r + matrix[0+4*1] * s.g + matrix[0+4*2] * s.b + matrix[0+4*3] * s.a + matrix[0+4*4];
			d.g = matrix[1+4*0] * s.r + matrix[1+4*1] * s.g + matrix[1+4*2] * s.b + matrix[1+4*3] * s.a + matrix[1+4*4];
			d.b = matrix[2+4*0] * s.r + matrix[2+4*1] * s.g + matrix[2+4*2] * s.b + matrix[2+4*3] * s.a + matrix[2+4*4];
			d.a = matrix[3+4*0] * s.r + matrix[3+4*1] * s.g + matrix[3+4*2] * s.b + matrix[3+4*3] * s.a + matrix[3+4*4];

			KGSurfaceWriteFilteredPixel(self,i, j, d, channelMask);
		}
	}
}

/*-------------------------------------------------------------------*//*!
* \brief	Reads a pixel from image with tiling mode applied.
* \param	
* \return	
* \note		
*//*-------------------------------------------------------------------*/

static VGColor readTiledPixel(int x, int y, int w, int h, VGTilingMode tilingMode,VGColor *image, VGColor edge)
{
	VGColor s=VGColorZero();
	if(x < 0 || x >= w || y < 0 || y >= h)
	{	//apply tiling mode
		switch(tilingMode)
		{
		case VG_TILE_FILL:
			s = edge;
			break;
		case VG_TILE_PAD:
			x = RI_INT_MIN(RI_INT_MAX(x, 0), w-1);
			y = RI_INT_MIN(RI_INT_MAX(y, 0), h-1);
			RI_ASSERT(x >= 0 && x < w && y >= 0 && y < h);
			s = image[y*w+x];
			break;
		case VG_TILE_REPEAT:
			x = RI_INT_MOD(x, w);
			y = RI_INT_MOD(y, h);
			RI_ASSERT(x >= 0 && x < w && y >= 0 && y < h);
			s = image[y*w+x];
			break;
		}
	}
	else
	{
		RI_ASSERT(x >= 0 && x < w && y >= 0 && y < h);
		s = image[y*w+x];
	}
	return s;
}

/*-------------------------------------------------------------------*//*!
* \brief	Returns processing format for filtering.
* \param	
* \return	
* \note		
*//*-------------------------------------------------------------------*/

static VGColorInternalFormat getProcessingFormat(VGColorInternalFormat srcFormat, BOOL filterFormatLinear, BOOL filterFormatPremultiplied)
{
	VGColorInternalFormat procFormat = (VGColorInternalFormat)(srcFormat & ~VGColorLUMINANCE);	//process in RGB, not luminance
	if(filterFormatLinear)
		procFormat = (VGColorInternalFormat)(procFormat & ~VGColorNONLINEAR);
	else
		procFormat = (VGColorInternalFormat)(procFormat | VGColorNONLINEAR);

	if(filterFormatPremultiplied)
		procFormat = (VGColorInternalFormat)(procFormat | VGColorPREMULTIPLIED);
	else
		procFormat = (VGColorInternalFormat)(procFormat & ~VGColorPREMULTIPLIED);
	return procFormat;
}

/*-------------------------------------------------------------------*//*!
* \brief	Applies convolution filter.
* \param	
* \return	
* \note		
*//*-------------------------------------------------------------------*/

void KGSurfaceConvolve(KGSurface *self,KGSurface * src, int kernelWidth, int kernelHeight, int shiftX, int shiftY, const RIint16* kernel, RIfloat scale, RIfloat bias, VGTilingMode tilingMode, VGColor edgeFillColor, BOOL filterFormatLinear, BOOL filterFormatPremultiplied, VGbitfield channelMask) {
	RI_ASSERT(src->_bytes);	//source exists
	RI_ASSERT(self->_bytes);	//destination exists
	RI_ASSERT(kernel && kernelWidth > 0 && kernelHeight > 0);

	//the area to be written is an intersection of source and destination image areas.
	//lower-left corners of the images are aligned.
	int w = RI_INT_MIN(self->_width, src->_width);
	int h = RI_INT_MIN(self->_height, src->_height);
	RI_ASSERT(w > 0 && h > 0);

	VGColorInternalFormat procFormat = getProcessingFormat(src->_colorFormat, filterFormatLinear, filterFormatPremultiplied);

	VGColor edge = edgeFillColor;
	edge=VGColorClamp(edge);
	edge=VGColorConvert(edge,procFormat);

	VGColor *tmp=(VGColor *)NSZoneMalloc(NULL,src->_width*src->_height*sizeof(VGColor));

	//copy source region to tmp and do conversion
    int j;
	for(j=0;j<src->_height;j++)
	{
        int i;
		for(i=0;i<src->_width;i++)
		{
			VGColor s = KGSurfaceReadPixel(src,i, j);
			s=VGColorConvert(s,procFormat);
			tmp[j*src->_width+i] = s;
		}
	}

	for(j=0;j<h;j++)
	{
        int i;
		for(i=0;i<w;i++)
		{
			VGColor sum=VGColorRGBA(0,0,0,0,procFormat);
            int kj;
			for(kj=0;kj<kernelHeight;kj++)
			{
                int ki;
				for(ki=0;ki<kernelWidth;ki++)
				{
					int x = i+ki-shiftX;
					int y = j+kj-shiftY;
					VGColor s = readTiledPixel(x, y, src->_width, src->_height, tilingMode, tmp, edge);

					int kx = kernelWidth-ki-1;
					int ky = kernelHeight-kj-1;
					RI_ASSERT(kx >= 0 && kx < kernelWidth && ky >= 0 && ky < kernelHeight);

					sum=VGColorAdd(sum, VGColorMultiplyByFloat(s,(RIfloat)kernel[kx*kernelHeight+ky]));
				}
			}

			sum=VGColorMultiplyByFloat(sum ,scale);
			sum.r += bias;
			sum.g += bias;
			sum.b += bias;
			sum.a += bias;

			KGSurfaceWriteFilteredPixel(self,i, j, sum, channelMask);
		}
	}
    NSZoneFree(NULL,tmp);
}

/*-------------------------------------------------------------------*//*!
* \brief	Applies separable convolution filter.
* \param	
* \return	
* \note		
*//*-------------------------------------------------------------------*/

void KGSurfaceSeparableConvolve(KGSurface *self,KGSurface * src, int kernelWidth, int kernelHeight, int shiftX, int shiftY, const RIint16* kernelX, const RIint16* kernelY, RIfloat scale, RIfloat bias, VGTilingMode tilingMode, VGColor edgeFillColor, BOOL filterFormatLinear, BOOL filterFormatPremultiplied, VGbitfield channelMask) {
	RI_ASSERT(src->_bytes);	//source exists
	RI_ASSERT(self->_bytes);	//destination exists
	RI_ASSERT(kernelX && kernelY && kernelWidth > 0 && kernelHeight > 0);

	//the area to be written is an intersection of source and destination image areas.
	//lower-left corners of the images are aligned.
	int w = RI_INT_MIN(self->_width, src->_width);
	int h = RI_INT_MIN(self->_height, src->_height);
	RI_ASSERT(w > 0 && h > 0);

	VGColorInternalFormat procFormat = getProcessingFormat(src->_colorFormat, filterFormatLinear, filterFormatPremultiplied);

	VGColor edge = edgeFillColor;
	edge=VGColorClamp(edge);
	edge=VGColorConvert(edge,procFormat);

	VGColor *tmp=(VGColor *)NSZoneMalloc(NULL,src->_width*src->_height*sizeof(VGColor));

	//copy source region to tmp and do conversion
    int j;
	for(j=0;j<src->_height;j++)
	{
        int i;
		for(i=0;i<src->_width;i++)
		{
			VGColor s = KGSurfaceReadPixel(src,i, j);
			s=VGColorConvert(s,procFormat);
			tmp[j*src->_width+i] = s;
		}
	}

	VGColor *tmp2=(VGColor *)NSZoneMalloc(NULL,w*src->_height*sizeof(VGColor));

	for(j=0;j<src->_height;j++)
	{
        int i;
		for(i=0;i<w;i++)
		{
			VGColor sum=VGColorRGBA(0,0,0,0,procFormat);
            int ki;
            
			for(ki=0;ki<kernelWidth;ki++)
			{
				int x = i+ki-shiftX;
				VGColor s = readTiledPixel(x, j, src->_width, src->_height, tilingMode, tmp, edge);

				int kx = kernelWidth-ki-1;
				RI_ASSERT(kx >= 0 && kx < kernelWidth);

				sum=VGColorAdd(sum , VGColorMultiplyByFloat(s,(RIfloat)kernelX[kx])) ;
			}
			tmp2[j*w+i] = sum;
		}
	}

	if(tilingMode == VG_TILE_FILL)
	{	//convolve the edge color
		VGColor sum=VGColorRGBA(0,0,0,0,procFormat);
        int ki;
		for(ki=0;ki<kernelWidth;ki++)
		{
			sum=VGColorAdd(sum, VGColorMultiplyByFloat(edge, (RIfloat)kernelX[ki]));
		}
		edge = sum;
	}

	for(j=0;j<h;j++)
	{
        int i;
		for(i=0;i<w;i++)
		{
			VGColor sum=VGColorRGBA(0,0,0,0,procFormat);
            int kj;
			for(kj=0;kj<kernelHeight;kj++)
			{
				int y = j+kj-shiftY;
				VGColor s = readTiledPixel(i, y, w, src->_height, tilingMode, tmp2, edge);

				int ky = kernelHeight-kj-1;
				RI_ASSERT(ky >= 0 && ky < kernelHeight);

				sum=VGColorAdd(sum, VGColorMultiplyByFloat(s, (RIfloat)kernelY[ky]));
			}

			sum=VGColorMultiplyByFloat(sum,scale);
			sum.r += bias;
			sum.g += bias;
			sum.b += bias;
			sum.a += bias;

			KGSurfaceWriteFilteredPixel(self,i, j, sum, channelMask);
		}
	}
    NSZoneFree(NULL,tmp);
    NSZoneFree(NULL,tmp2);
}

/*-------------------------------------------------------------------*//*!
* \brief	Applies Gaussian blur filter.
* \param	
* \return	
* \note		
*//*-------------------------------------------------------------------*/

void KGSurfaceGaussianBlur(KGSurface *self,KGSurface * src, RIfloat stdDeviationX, RIfloat stdDeviationY, VGTilingMode tilingMode, VGColor edgeFillColor, BOOL filterFormatLinear, BOOL filterFormatPremultiplied, VGbitfield channelMask){
	RI_ASSERT(src->_bytes);	//source exists
	RI_ASSERT(self->_bytes);	//destination exists
	RI_ASSERT(stdDeviationX > 0.0f && stdDeviationY > 0.0f);
	RI_ASSERT(stdDeviationX <= RI_MAX_GAUSSIAN_STD_DEVIATION && stdDeviationY <= RI_MAX_GAUSSIAN_STD_DEVIATION);

	//the area to be written is an intersection of source and destination image areas.
	//lower-left corners of the images are aligned.
	int w = RI_INT_MIN(self->_width, src->_width);
	int h = RI_INT_MIN(self->_height, src->_height);
	RI_ASSERT(w > 0 && h > 0);

	VGColorInternalFormat procFormat = getProcessingFormat(src->_colorFormat, filterFormatLinear, filterFormatPremultiplied);

	VGColor edge = edgeFillColor;
	edge=VGColorClamp(edge);
	edge=VGColorConvert(edge,procFormat);

	VGColor *tmp=(VGColor *)NSZoneMalloc(NULL,src->_width*src->_height*sizeof(VGColor));

	//copy source region to tmp and do conversion
    int j;
	for(j=0;j<src->_height;j++)
	{
        int i;
		for(i=0;i<src->_width;i++)
		{
			VGColor s = KGSurfaceReadPixel(src,i, j);
			s=VGColorConvert(s,procFormat);
			tmp[j*src->_width+i] = s;
		}
	}

	//find a size for the kernel
	RIfloat totalWeightX = stdDeviationX*(RIfloat)sqrt(2.0f*M_PI);
	RIfloat totalWeightY = stdDeviationY*(RIfloat)sqrt(2.0f*M_PI);
	const RIfloat tolerance = 0.99f;	//use a kernel that covers 99% of the total Gaussian support

	RIfloat expScaleX = -1.0f / (2.0f*stdDeviationX*stdDeviationX);
	RIfloat expScaleY = -1.0f / (2.0f*stdDeviationY*stdDeviationY);

	int kernelWidth = 0;
	RIfloat e = 0.0f;
	RIfloat sumX = 1.0f;	//the weight of the middle entry counted already
	do
	{
		kernelWidth++;
		e = (RIfloat)exp((RIfloat)(kernelWidth * kernelWidth) * expScaleX);
		sumX += e*2.0f;	//count left&right lobes
	}
	while(sumX < tolerance*totalWeightX);

	int kernelHeight = 0;
	e = 0.0f;
	RIfloat sumY = 1.0f;	//the weight of the middle entry counted already
	do
	{
		kernelHeight++;
		e = (RIfloat)exp((RIfloat)(kernelHeight * kernelHeight) * expScaleY);
		sumY += e*2.0f;	//count left&right lobes
	}
	while(sumY < tolerance*totalWeightY);

	//make a separable kernel
    int kernelXSize=kernelWidth*2+1;
	RIfloat kernelX[kernelXSize];
	int shiftX = kernelWidth;
	RIfloat scaleX = 0.0f;
    int i;
	for(i=0;i<kernelXSize;i++)
	{
		int x = i-shiftX;
		kernelX[i] = (RIfloat)exp((RIfloat)x*(RIfloat)x * expScaleX);
		scaleX += kernelX[i];
	}
	scaleX = 1.0f / scaleX;	//NOTE: using the mathematical definition of the scaling term doesn't work since we cut the filter support early for performance

    int kernelYSize=kernelHeight*2+1;
	RIfloat kernelY[kernelYSize];
	int shiftY = kernelHeight;
	RIfloat scaleY = 0.0f;
	for(i=0;i<kernelYSize;i++)
	{
		int y = i-shiftY;
		kernelY[i] = (RIfloat)exp((RIfloat)y*(RIfloat)y * expScaleY);
		scaleY += kernelY[i];
	}
	scaleY = 1.0f / scaleY;	//NOTE: using the mathematical definition of the scaling term doesn't work since we cut the filter support early for performance

	VGColor *tmp2=(VGColor *)NSZoneMalloc(NULL,w*src->_height*sizeof(VGColor));

	//horizontal pass
	for(j=0;j<src->_height;j++)
	{
		for(i=0;i<w;i++)
		{
			VGColor sum=VGColorRGBA(0,0,0,0,procFormat);
            int ki;
			for(ki=0;ki<kernelXSize;ki++)
			{
				int x = i+ki-shiftX;
				sum=VGColorAdd(sum, VGColorMultiplyByFloat(readTiledPixel(x, j, src->_width, src->_height, tilingMode, tmp, edge),kernelX[ki]));
			}
			tmp2[j*w+i] = VGColorMultiplyByFloat(sum, scaleX);
		}
	}
	//vertical pass
	for(j=0;j<h;j++)
	{
		for(i=0;i<w;i++)
		{
			VGColor sum=VGColorRGBA(0,0,0,0,procFormat);
            int kj;
			for(kj=0;kj<kernelYSize;kj++)
			{
				int y = j+kj-shiftY;
				sum=VGColorAdd(sum,  VGColorMultiplyByFloat(readTiledPixel(i, y, w, src->_height, tilingMode, tmp2, edge), kernelY[kj]));
			}
			KGSurfaceWriteFilteredPixel(self,i, j, VGColorMultiplyByFloat(sum, scaleY), channelMask);
		}
	}
    NSZoneFree(NULL,tmp);
    NSZoneFree(NULL,tmp2);
}

/*-------------------------------------------------------------------*//*!
* \brief	Returns lookup table format for lookup filters.
* \param	
* \return	
* \note		
*//*-------------------------------------------------------------------*/

static VGColorInternalFormat getLUTFormat(BOOL outputLinear, BOOL outputPremultiplied)
{
	VGColorInternalFormat lutFormat = VGColor_lRGBA;
	if(outputLinear && outputPremultiplied)
		lutFormat = VGColor_lRGBA_PRE;
	else if(!outputLinear && !outputPremultiplied)
		lutFormat = VGColor_sRGBA;
	else if(!outputLinear && outputPremultiplied)
		lutFormat = VGColor_sRGBA_PRE;
	return lutFormat;
}

/*-------------------------------------------------------------------*//*!
* \brief	Applies multi-channel lookup table filter.
* \param	
* \return	
* \note		
*//*-------------------------------------------------------------------*/

void KGSurfaceLookup(KGSurface *self,KGSurface * src, const RIuint8 * redLUT, const RIuint8 * greenLUT, const RIuint8 * blueLUT, const RIuint8 * alphaLUT, BOOL outputLinear, BOOL outputPremultiplied, BOOL filterFormatLinear, BOOL filterFormatPremultiplied, VGbitfield channelMask){
	RI_ASSERT(src->_bytes);	//source exists
	RI_ASSERT(self->_bytes);	//destination exists
	RI_ASSERT(redLUT && greenLUT && blueLUT && alphaLUT);

	//the area to be written is an intersection of source and destination image areas.
	//lower-left corners of the images are aligned.
	int w = RI_INT_MIN(self->_width, src->_width);
	int h = RI_INT_MIN(self->_height, src->_height);
	RI_ASSERT(w > 0 && h > 0);

	VGColorInternalFormat procFormat = getProcessingFormat(src->_colorFormat, filterFormatLinear, filterFormatPremultiplied);
	VGColorInternalFormat lutFormat = getLUTFormat(outputLinear, outputPremultiplied);

    int j;
	for(j=0;j<h;j++)
	{
        int i;
		for(i=0;i<w;i++)
		{
			VGColor s = KGSurfaceReadPixel(src,i,j);	//convert to RGBA [0,1]
			s=VGColorConvert(s,procFormat);

			VGColor d=VGColorRGBA(0,0,0,0,lutFormat);
			d.r = intToColor(  redLUT[colorToInt(s.r, 255)], 255);
			d.g = intToColor(greenLUT[colorToInt(s.g, 255)], 255);
			d.b = intToColor( blueLUT[colorToInt(s.b, 255)], 255);
			d.a = intToColor(alphaLUT[colorToInt(s.a, 255)], 255);

			KGSurfaceWriteFilteredPixel(self,i, j, d, channelMask);
		}
	}
}

/*-------------------------------------------------------------------*//*!
* \brief	Applies single channel lookup table filter.
* \param	
* \return	
* \note		
*//*-------------------------------------------------------------------*/

void KGSurfaceLookupSingle(KGSurface *self,KGSurface * src, const RIuint32 * lookupTable, KGSurfaceChannel sourceChannel, BOOL outputLinear, BOOL outputPremultiplied, BOOL filterFormatLinear, BOOL filterFormatPremultiplied, VGbitfield channelMask){
	RI_ASSERT(src->_bytes);	//source exists
	RI_ASSERT(self->_bytes);	//destination exists
	RI_ASSERT(lookupTable);

	//the area to be written is an intersection of source and destination image areas.
	//lower-left corners of the images are aligned.
	int w = RI_INT_MIN(self->_width, src->_width);
	int h = RI_INT_MIN(self->_height, src->_height);
	RI_ASSERT(w > 0 && h > 0);

	if(src->m_desc.luminanceBits)
		sourceChannel = VG_RED;
	else if(src->m_desc.redBits + src->m_desc.greenBits + src->m_desc.blueBits == 0)
	{
		RI_ASSERT(src->m_desc.alphaBits);
		sourceChannel = VG_ALPHA;
	}

	VGColorInternalFormat procFormat = getProcessingFormat(src->_colorFormat, filterFormatLinear, filterFormatPremultiplied);
	VGColorInternalFormat lutFormat = getLUTFormat(outputLinear, outputPremultiplied);

    int j;
	for(j=0;j<h;j++)
	{
        int i;
		for(i=0;i<w;i++)
		{
			VGColor s = KGSurfaceReadPixel(src,i,j);	//convert to RGBA [0,1]
			s=VGColorConvert(s,procFormat);
			int e;
			switch(sourceChannel)
			{
			case VG_RED:
				e = colorToInt(s.r, 255);
				break;
			case VG_GREEN:
				e = colorToInt(s.g, 255);
				break;
			case VG_BLUE:
				e = colorToInt(s.b, 255);
				break;
			default:
				RI_ASSERT(sourceChannel == VG_ALPHA);
				e = colorToInt(s.a, 255);
				break;
			}

			RIuint32 l = ((const RIuint32*)lookupTable)[e];
			VGColor d=VGColorRGBA(0,0,0,0,lutFormat);
			d.r = intToColor((l>>24), 255);
			d.g = intToColor((l>>16), 255);
			d.b = intToColor((l>> 8), 255);
			d.a = intToColor((l    ), 255);

			KGSurfaceWriteFilteredPixel(self,i, j, d, channelMask);
		}
	}
}

@end