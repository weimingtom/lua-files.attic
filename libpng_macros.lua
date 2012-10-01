--macros from png.h from libpng 1.6.0.b29
--TODO: translate them
local M = {}
setfenv(1, M)

-- Interlace support.  The following macros are always defined so that if
-- libpng interlace handling is turned off the macros may be used to handle
-- interlaced images within the application.

PNG_INTERLACE_ADAM7_PASSES = 7

-- Two macros to return the first row and first column of the original,
-- full, image which appears in a given pass.  'pass' is in the range 0
-- to 6 and the result is in the range 0 to 7.

PNG_PASS_START_ROW(pass) = (((1&~(pass))<<(3-((pass)>>1)))&7)
PNG_PASS_START_COL(pass) = (((1& (pass))<<(3-(((pass)+1)>>1)))&7)

-- A macro to return the offset between pixels in the output row for a pair of
-- pixels in the input - effectively the inverse of the 'COL_SHIFT' macro that
-- follows.  Note that ROW_OFFSET is the offset from one row to the next whereas
-- COL_OFFSET is from one column to the next, within a row.

PNG_PASS_ROW_OFFSET(pass) = ((pass)>2?(8>>(((pass)-1)>>1)):8)
PNG_PASS_COL_OFFSET(pass) = (1<<((7-(pass))>>1))

-- Two macros to help evaluate the number of rows or columns in each
-- pass.  This is expressed as a shift - effectively log2 of the number or
-- rows or columns in each 8x8 tile of the original image.

PNG_PASS_ROW_SHIFT(pass) = ((pass)>2?(8-(pass))>>1:3)
PNG_PASS_COL_SHIFT(pass) = ((pass)>1?(7-(pass))>>1:3)

-- Hence two macros to determine the number of rows or columns in a given
-- pass of an image given its height or width.  In fact these macros may
-- return non-zero even though the sub-image is empty, because the other
-- dimension may be empty for a small image.

PNG_PASS_ROWS(height, = pass) (((height)+(((1<<PNG_PASS_ROW_SHIFT(pass))\
   -1)-PNG_PASS_START_ROW(pass)))>>PNG_PASS_ROW_SHIFT(pass))
PNG_PASS_COLS(width, = pass) (((width)+(((1<<PNG_PASS_COL_SHIFT(pass))\
   -1)-PNG_PASS_START_COL(pass)))>>PNG_PASS_COL_SHIFT(pass))

-- For the reader row callbacks (both progressive and sequential) it is
-- necessary to find the row in the output image given a row in an interlaced
-- image, so two more macros:

PNG_ROW_FROM_PASS_ROW(y_in, = pass) \
   (((y_in)<<PNG_PASS_ROW_SHIFT(pass))+PNG_PASS_START_ROW(pass))
PNG_COL_FROM_PASS_COL(x_in, = pass) \
   (((x_in)<<PNG_PASS_COL_SHIFT(pass))+PNG_PASS_START_COL(pass))

-- Two macros which return a boolean (0 or 1) saying whether the given row
-- or column is in a particular pass.  These use a common utility macro that
-- returns a mask for a given pass - the offset 'off' selects the row or
-- column version.  The mask has the appropriate bit set for each column in
-- the tile.

PNG_PASS_MASK(pass,off) = ( \
   ((0x110145AF>>(((7-(off))-(pass))<<2)) & 0xF) | \
   ((0x01145AF0>>(((7-(off))-(pass))<<2)) & 0xF0))

PNG_ROW_IN_INTERLACE_PASS(y, = pass) \
   ((PNG_PASS_MASK(pass,0) >> ((y)&7)) & 1)
PNG_COL_IN_INTERLACE_PASS(x, = pass) \
   ((PNG_PASS_MASK(pass,1) >> ((x)&7)) & 1)

-- SIMPLIFIED API (v1.6+)
-- PNG_IMAGE macros
--
-- These are convenience macros to derive information from a png_image
-- structure.  The PNG_IMAGE_SAMPLE_ macros return values appropriate to the
-- actual image sample values - either the entries in the color-map or the
-- pixels in the image.  The PNG_IMAGE_PIXEL_ macros return corresponding values
-- for the pixels and will always return 1 for color-mapped formats.  The
-- remaining macros return information about the rows in the image and the
-- complete image.
--
-- NOTE: All the macros that take a png_image::format parameter are compile time
-- constants if the format parameter is, itself, a constant.  Therefore these
-- macros can be used in array declarations and case labels where required.
-- Similarly the macros are also pre-processor constants (sizeof is not used) so
-- they can be used in #if tests.
--
-- First the information about the samples.

PNG_IMAGE_SAMPLE_CHANNELS(fmt)\
   (((fmt)&(PNG_FORMAT_FLAG_COLOR|PNG_FORMAT_FLAG_ALPHA))+1)
   -- Return the total number of channels in a given format: 1..4

PNG_IMAGE_SAMPLE_COMPONENT_SIZE(fmt)\
   ((((fmt) & PNG_FORMAT_FLAG_LINEAR) >> 2)+1)
-- Return the size in bytes of a single component of a pixel or color-map
-- entry (as appropriate) in the image: 1 or 2.


PNG_IMAGE_SAMPLE_SIZE(fmt)\
   (PNG_IMAGE_SAMPLE_CHANNELS(fmt) * PNG_IMAGE_SAMPLE_COMPONENT_SIZE(fmt))
-- This is the size of the sample data for one sample.  If the image is
-- color-mapped it is the size of one color-map entry (and image pixels are
-- one byte in size), otherwise it is the size of one image pixel.


PNG_IMAGE_MAXIMUM_COLORMAP_COMPONENTS(fmt)\
   (PNG_IMAGE_SAMPLE_CHANNELS(fmt) * 256)
-- The maximum size of the color-map required by the format expressed in a
-- count of components.  This can be used to compile-time allocate a
-- color-map:
--
-- png_uint_16 colormap[PNG_IMAGE_MAXIMUM_COLORMAP_COMPONENTS(linear_fmt)];
--
-- png_byte colormap[PNG_IMAGE_MAXIMUM_COLORMAP_COMPONENTS(sRGB_fmt)];
--
-- Alternatively use the PNG_IMAGE_COLORMAP_SIZE macro below to use the
-- information from one of the png_image_begin_read_ APIs and dynamically
-- allocate the required memory.


-- Corresponding information about the pixels
PNG_IMAGE_PIXEL_(test,fmt)\
   (((fmt)&PNG_FORMAT_FLAG_COLORMAP)?1:test(fmt))

PNG_IMAGE_PIXEL_CHANNELS(fmt)\
   PNG_IMAGE_PIXEL_(PNG_IMAGE_SAMPLE_CHANNELS,fmt)
-- The number of separate channels (components) in a pixel; 1 for a
-- color-mapped image.


PNG_IMAGE_PIXEL_COMPONENT_SIZE(fmt)\
   PNG_IMAGE_PIXEL_(PNG_IMAGE_SAMPLE_COMPONENT_SIZE,fmt)
-- The size, in bytes, of each component in a pixel; 1 for a color-mapped
-- image.


PNG_IMAGE_PIXEL_SIZE(fmt) = PNG_IMAGE_PIXEL_(PNG_IMAGE_SAMPLE_SIZE,fmt)
   -- The size, in bytes, of a complete pixel; 1 for a color-mapped image.

-- Information about the whole row, or whole image
PNG_IMAGE_ROW_STRIDE(image)\
   (PNG_IMAGE_PIXEL_CHANNELS((image).format) * (image).width)
-- Return the total number of components in a single row of the image; this
-- is the minimum 'row stride', the minimum count of components between each
-- row.  For a color-mapped image this is the minimum number of bytes in a
-- row.


PNG_IMAGE_BUFFER_SIZE(image, = row_stride)\
   (PNG_IMAGE_PIXEL_COMPONENT_SIZE((image).format)*(image).height*(row_stride))
-- Return the size, in bytes, of an image buffer given a png_image and a row
-- stride - the number of components to leave space for in each row.


PNG_IMAGE_SIZE(image)\
   PNG_IMAGE_BUFFER_SIZE(image, PNG_IMAGE_ROW_STRIDE(image))
-- Return the size, in bytes, of the image in memory given just a png_image;
-- the row stride is the minimum stride required for the image.


PNG_IMAGE_COLORMAP_SIZE(image)\
   (PNG_IMAGE_SAMPLE_SIZE((image).format) * (image).colormap_entries)
-- Return the size, in bytes, of the color-map of this image.  If the image
-- format is not a color-map format this will return a size sufficient for
-- 256 entries in the given format; check PNG_FORMAT_FLAG_COLORMAP if
-- you don't want to allocate a color-map in this case.


-- PNG_IMAGE_FLAG_*
--
-- Flags containing additional information about the image are held in the
-- 'flags' field of png_image.

PNG_IMAGE_FLAG_COLORSPACE_NOT_sRGB = 0x01
-- This indicates the the RGB values of the in-memory bitmap do not
-- correspond to the red, green and blue end-points defined by sRGB.


PNG_IMAGE_FLAG_FAST = 0x02
-- On write emphasise speed over compression; the resultant PNG file will be
-- larger but will be produced significantly faster, particular for large
-- images.  Do not use this option for images which will be distributed, only
-- used it when producing intermediate files that will be read back in
-- repeatedly.  For a typical 24-bit image the option will double the read
-- speed at the cost of increasing the image size by 25%, however for many
-- more compressible images the PNG file can be 10 times larger with only a
-- slight speed gain.

return M
