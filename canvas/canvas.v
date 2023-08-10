// Functions that perform operations on 2D images with 1 channel (greyscale) or 3 channels (RGB).
// Use stbi to read/write image files but is otherwise standalone.

// History:
// 14/04/23 DCN: Created (by re-implementing canvas.py from the kilo-codes prototype)

module canvas

import stbi
import os
import math
import consts
import draw
import fonts

// Buffer structure to hold image characteristics and attach methods to
pub struct Buffer {
	file     ?string     // where it came from (or none)
	image    ?stbi.Image // raw image as loaded by stbi.load (or none)
	width    int         [required] // its width in pixels
	height   int         [required] // its height in pixels
	channels int         [required]
mut: // 1=monochrome, 3=colour
	pixels []u8 // the pixel data
}

// load loads the given image file and returns a Buffer reference
pub fn load(image_file string) !Buffer {
	in_path := os.abs_path(image_file)
	raw_image := stbi.load(in_path, desired_channels: 0) or {
		return error('load of ${image_file} failed')
	}
	mut buffer := Buffer{
		file: in_path
		image: raw_image
		width: raw_image.width
		height: raw_image.height
		channels: raw_image.nr_channels
	}
	image_size := buffer.width * buffer.height * buffer.channels
	buffer.pixels = []u8{}
	unsafe {
		image := buffer.image or { return error('cannot access image data for ${image_file}') }
		buffer.pixels.data = image.data
		buffer.pixels.len = image_size
		buffer.pixels.cap = image_size
	}
	return buffer
}

// unload unloads a buffer to the given image file
pub fn (buffer Buffer) unload(image_file string) !bool {
	out_path := os.abs_path(image_file)
	stbi.stbi_write_png(out_path, buffer.width, buffer.height, buffer.channels, unsafe { buffer.pixels.data },
		buffer.width * buffer.channels) or { return error('unload of ${image_file} failed') }
	return true
}

// greyscale returns a greyscale copy of the given buffer, returns self if already grey
pub fn (buffer Buffer) greyscale() Buffer {
	if buffer.channels == 1 {
		// already grey
		return buffer
	}
	image_size := buffer.width * buffer.height
	mut greyscale := Buffer{
		width: buffer.width
		height: buffer.height
		channels: 1
	}
	greyscale.pixels = []u8{len: image_size}
	for pixel in 0 .. image_size {
		source := pixel * buffer.channels
		mut luminance := 0
		for channel in 0 .. buffer.channels {
			luminance += buffer.pixels[source + channel]
		}
		greyscale.pixels[pixel] = u8(luminance / buffer.channels)
	}
	return greyscale
}

// get_pixel returns the monochrome or colour pixel from the given buffer
pub fn (buffer Buffer) get_pixel(x int, y int) consts.Colour {
	match buffer.channels {
		1 {
			return consts.Colour(consts.MonochromePixel{buffer.pixels[(y * buffer.width) + x]})
		}
		3 {
			pixel_address := ((y * buffer.width) + x) * buffer.channels
			return consts.Colour(consts.ColourPixel{
				r: buffer.pixels[pixel_address + 0]
				g: buffer.pixels[pixel_address + 1]
				b: buffer.pixels[pixel_address + 2]
			})
		}
		else {
			return consts.Colour(consts.Empty{})
		}
	}
}

// put_pixel updates the addressed pixel with the given colour, invalid combinations throw an error
pub fn (mut buffer Buffer) put_pixel(x int, y int, value consts.Colour) ! {
	match value {
		consts.MonochromePixel {
			if buffer.channels == 1 {
				buffer.pixels[(y * buffer.width) + x] = value.val
			} else {
				return error('attempt to write monochrome pixel to a colour buffer')
			}
		}
		consts.ColourPixel {
			if buffer.channels == 3 {
				pixel_address := ((y * buffer.width) + x) * buffer.channels
				buffer.pixels[pixel_address + 0] = value.r
				buffer.pixels[pixel_address + 1] = value.g
				buffer.pixels[pixel_address + 2] = value.b
			} else {
				return error('attempt to write a colour pixel to a monochrome buffer')
			}
		}
		else {} // do nothing (we were given an Empty colour)
	}
}

// clone return a copy of the given buffer
pub fn (buffer Buffer) clone() Buffer {
	image_size := (buffer.width * buffer.height) * buffer.channels
	mut new_buffer := Buffer{
		width: buffer.width
		height: buffer.height
		channels: buffer.channels
		pixels: []u8{len: image_size, cap: image_size}
	}
	copy(mut new_buffer.pixels, buffer.pixels)
	return new_buffer
}

// new_grey create a new monochrome buffer of the given size and initialised to the given value
pub fn new_grey(width int, height int, colour consts.MonochromePixel) Buffer {
	image_size := width * height
	mut buffer := Buffer{
		width: width
		height: height
		channels: 1
		pixels: []u8{len: image_size, cap: image_size, init: colour.val}
	}
	return buffer
}

// size get the buffer size (width, height)
pub fn (buffer Buffer) size() (int, int) {
	return buffer.width, buffer.height
}

[params]
struct BoxParam {
	box consts.Box
}

// get_box_corners - breakout box co-ords into min x,y and max x,y defaulting to buffer size
fn (buffer Buffer) get_box_corners(p BoxParam) (int, int, int, int) {
	box := if p.box.bottom_right == consts.Point{0, 0} {
		// we take this to mean caller did not provide a box
		width, height := buffer.size()
		consts.Box{
			top_left: consts.Point{0, 0}
			bottom_right: consts.Point{width, height}
		}
	} else {
		// use supplied box
		consts.Box{
			top_left: p.box.top_left
			bottom_right: consts.Point{p.box.bottom_right.x + 1, p.box.bottom_right.y + 1}
		}
	}
	return int(box.top_left.x), int(box.top_left.y), int(box.bottom_right.x), int(box.bottom_right.y)
}

// integrate - generate the integral of the given box within the given greyscale image buffer
// NB: array returned is Y by X, i.e. address pixels as buffer[y][x]
fn (buffer Buffer) integrate(p BoxParam) [][]u32 {
	box_min_x, box_min_y, box_max_x, box_max_y := buffer.get_box_corners(p)

	box_width := box_max_x - box_min_x
	box_height := box_max_y - box_min_y

	// make an empty buffer to accumulate our integral in
	mut integral := [][]u32{len: box_height, init: []u32{len: box_width}}

	for y in box_min_y .. box_max_y {
		mut acc := u32(0)
		for x in box_min_x .. box_max_x {
			pixel := buffer.get_pixel(x, y) as consts.MonochromePixel
			if x == box_min_x {
				acc = u32(pixel.val) // start a new row
			} else {
				acc += u32(pixel.val) // extend existing row
			}
			ix := x - box_min_x
			iy := y - box_min_y
			if iy == 0 {
				integral[iy][ix] = acc // start a new column
			} else {
				integral[iy][ix] = acc + integral[iy - 1][ix] // extend existing column
			}
		}
	}
	return integral
}

// downsize the given greyscale image such that its width is at most that given,
// the aspect ratio is preserved, its a no-op if image already small enough,
// returns a new buffer of the new size,
// this is purely a diagnostic aid to simulate low-resolution cameras,
// as such it uses a very simple algorithm:
//   it calculates the sub-image size in the original image that must be represented in the downsized image
//   the downsized image pixel is then just the average of the original sub-image pixels
// the assumption is that the light that fell on the pixels in the original sub-image would all of have
// fallen on a single pixel in a 'lesser' camera, so the lesser camera would only have seen their average,
// the averages are calculated from the integral of the original image, this means each pixel of the original
// image is only visited once, and the average over any arbitrary area only requires four accesses of that
// for each downsized pixel.
pub fn (buffer Buffer) downsize(new_width int) !Buffer {
	width, height := buffer.size()
	if width <= new_width {
		// its already small enough
		return buffer
	}
	// bring width down to new size and re-scale height to maintain aspect ratio
	width_scale := f32(width) / f32(new_width)
	new_height := int(f32(height) / width_scale)
	height_scale := f32(height) / f32(new_height)
	// calculate the kernel size for our average
	kernel_width := int(math.round(width_scale)) // guaranteed to be >= 1
	kernel_height := int(math.round(height_scale)) // ..
	kernel_plus_x := kernel_width >> 1 // offset for going forward
	kernel_minus_x := kernel_plus_x - 1 // offset for going backward
	kernel_plus_y := kernel_height >> 1 // ditto
	kernel_minus_y := kernel_plus_y - 1 // ..
	// do the downsize via the integral
	integral := buffer.integrate()
	mut downsized := new_grey(new_width, new_height, consts.min_luminance)
	for x in 0 .. new_width {
		orig_x := int(math.min(x * width_scale, width - 1)) // need int() 'cos width_scale is a f32
		orig_x1 := math.max(orig_x - kernel_minus_x, 0)
		orig_x2 := math.min(orig_x + kernel_plus_x, width - 1)
		for y in 0 .. new_height {
			orig_y := int(math.min(y * height_scale, height - 1)) // need int() 'cos height_scale is a f32
			orig_y1 := math.max(orig_y - kernel_minus_y, 0)
			orig_y2 := math.min(orig_y + kernel_plus_y, height - 1)
			count := (orig_x2 - orig_x1) * (orig_y2 - orig_y1) // how many samples in the integration area
			// sum = bottom right (x2,y2) + top left (x1,y1) - top right (x2,y1) - bottom left (x1,y2)
			// where all but bottom right are *outside* the integration window
			sum := (integral[orig_y2][orig_x2] + integral[orig_y1][orig_x1]) - (
				integral[orig_y1][orig_x2] + integral[orig_y2][orig_x1])
			average := f32(sum) / f32(count)
			downsized.put_pixel(x, y, consts.Colour(consts.MonochromePixel{u8(average)}))!
		}
	}
	return downsized
}

// blur - return the blurred image as a mean blur over the given kernel size
pub fn (buffer Buffer) blur(kernel_size int) !Buffer {
	// we do this by integrating then calculating the average via integral differences,
	// this means we only visit each pixel once irrespective of the kernel size
	if kernel_size < 2 {
		return buffer // pointless
	}

	// integrate the image
	integral := buffer.integrate()

	// get image geometry
	width, height := buffer.size() // integral is same size as the thing integrated

	// set kernel geometry
	kernel_plus := kernel_size >> 1 // offset for going forward
	kernel_minus := kernel_size - 1 // offset for going backward

	// blur the image by averaging over the given kernel size
	mut blurred := new_grey(width, height, consts.min_luminance)
	for x in 0 .. width {
		x1 := math.max(x - kernel_minus, 0)
		x2 := math.min(x + kernel_plus, width - 1)
		for y in 0 .. height {
			y1 := math.max(y - kernel_minus, 0)
			y2 := math.min(y + kernel_plus, height - 1)
			count := f32((x2 - x1) * (y2 - y1)) // how many samples in the integration area
			// sum = bottom right (x2,y2) + top left (x1,y1) - top right (x2,y1) - bottom left (x1,y2)
			// where all but bottom right are *outside* the integration window
			average := f32(integral[y2][x2] + integral[y1][x1] - integral[y1][x2] - integral[y2][x1]) / count
			blurred.put_pixel(x, y, consts.Colour(consts.MonochromePixel{u8(average)}))!
		}
	}
	return blurred
}

[params]
pub struct BinarizeParams {
	box    consts.Box // if box is all zero the whole image is processed, otherwise just the area within the given box
	width  f32 = 8.0 // fraction of the source/box width to use as the integration area
	height f32        // fraction of the source/box height to use as the integration area (0==same as width in pixels)
	black  f32 = 15.0 // % below the average that is considered to be the black/grey boundary
	white  f32 = math.max_i16 // % above the average that is considered to be the grey/white boundary
	// white of max_i16 or above means same as black and will yield a binary image
}

// binarize - create a binary (or tertiary) image of the source image within the box using an adaptive threshold,
// See the adaptive-threshold-algorithm.pdf paper for algorithm details.
// the image returned is the same size as the box (or the source iff no box given)
pub fn (buffer Buffer) binarize(p BinarizeParams) !Buffer {
	// region get the source and box metrics...
	box_min_x, box_min_y, box_max_x, box_max_y := buffer.get_box_corners(box: p.box)
	box_width := box_max_x - box_min_x
	box_height := box_max_y - box_min_y
	// endregion

	// region set the integration size...
	width_pixels := int(box_width / p.width) // we want this to be odd so that there is a centre
	width_plus := math.max(width_pixels >> 1, 2) // offset for going forward
	width_minus := width_plus - 1 // offset for going backward
	height_pixels := if p.height == 0 {
		width_pixels // make it square
	} else {
		int(box_height / p.height) // we want this to be odd so that there is a centre
	}
	height_plus := math.max(height_pixels >> 1, 2) // offset for going forward
	height_minus := height_plus - 1 // offset for going backward
	// endregion

	// integrate the image
	integral := buffer.integrate(box: p.box)

	// region do the threshold on a new image buffer...
	mut binary := new_grey(box_width, box_height, consts.min_luminance)
	black_limit := (100.0 - p.black) / 100.0 // convert % to a ratio
	white_limit := if p.white >= math.max_i16 {
		black_limit
	} else {
		(100.0 + p.white) / 100.0 // convert % to a ratio
	}
	for x in 0 .. box_width {
		x1 := math.max(x - width_minus, 0)
		x2 := math.min(x + width_plus, box_width - 1)
		for y in 0 .. box_height {
			y1 := math.max(y - height_minus, 0)
			y2 := math.min(y + height_plus, box_height - 1)
			count := (x2 - x1) * (y2 - y1) // how many samples in the integration area
			// sum = bottom right (x2,y2) + top left (x1,y1) - top right (x2,y1) - bottom left (x1,y2)
			// where all but bottom right are *outside* the integration window
			pixel := buffer.get_pixel(box_min_x + x, box_min_y + y) as consts.MonochromePixel
			acc := integral[y2][x2] + integral[y1][x1] - integral[y1][x2] - integral[y2][x1]
			src := int(pixel.val) * count // NB: need int 'cos source is u8 (unsigned)
			if src >= (acc * white_limit) {
				binary.put_pixel(x, y, consts.max_luminance)!
			} else if src <= (acc * black_limit) {
				binary.put_pixel(x, y, consts.min_luminance)!
			} else {
				binary.put_pixel(x, y, consts.mid_luminance)!
			}
		}
	}
	// endregion

	return binary
}

// in_colour - turn buffer into a colour image if required by the given colour
fn (buffer Buffer) in_colour(colour consts.Colour) Buffer {
	match colour {
		consts.ColourPixel {
			return buffer.colourize()
		}
		else {
			return buffer
		}
	}
}

// colourize - make grey image into an RGB one, returns the colour image, its a no-op if we're already colour
pub fn (buffer Buffer) colourize() Buffer {
	if buffer.channels == 3 {
		// already colour
		return buffer
	}
	image_size := buffer.width * buffer.height
	mut image := Buffer{
		width: buffer.width
		height: buffer.height
		channels: 3
	}
	image.pixels = []u8{len: image_size * 3}
	for pixel in 0 .. image_size {
		luminance := buffer.pixels[pixel]
		address := pixel * 3
		image.pixels[address + 0] = luminance
		image.pixels[address + 1] = luminance
		image.pixels[address + 2] = luminance
	}
	return image
}

// extract a box from the given image
pub fn (buffer Buffer) extract(box consts.Box) !Buffer {
	tl_x, tl_y, br_x, br_y := buffer.get_box_corners(box: box)
	width := br_x - tl_x + 1
	height := br_y - tl_y + 1
	mut extracted := new_grey(width, height, consts.min_luminance)
	for x in 0 .. width {
		for y in 0 .. height {
			extracted.put_pixel(x, y, buffer.get_pixel(tl_x + x, tl_y + y))!
		}
	}
	return extracted
}

pub struct PixelPart {
	value consts.MonochromePixel // the value of a neighbour pixel
	ratio f32 // its contribution to an interpolated pixel
}

// pixel_parts - get the neighbour parts contributions for a pixel at x,y
pub fn (buffer Buffer) pixel_parts(x f32, y f32) []PixelPart {
	//  x,y are fractional so the pixel contributions is a mixture of the 4 pixels around x,y,
	// the mixture is based on the ratio of the neighbours to include, the ratio of all 4 is 1,
	// code based on:
	//      void interpolateColorPixel(double x, double y) {
	//          int xL, yL;
	// 			xL = (int) Math.floor(x);
	//          yL = (int) Math.floor(y);
	//          xLyL = ipInitial.getPixel(xL, yL, xLyL);
	//          xLyH = ipInitial.getPixel(xL, yL + 1, xLyH);
	//          xHyL = ipInitial.getPixel(xL + 1, yL, xHyL);
	//          xHyH = ipInitial.getPixel(xL + 1, yL + 1, xHyH);
	//          for (int rr = 0; rr < 3; rr++) {
	//              double newValue = (xL + 1 - x) * (yL + 1 - y) * xLyL[rr];
	//              newValue += (x - xL) * (yL + 1 - y) * xHyL[rr];
	//              newValue += (xL + 1 - x) * (y - yL) * xLyH[rr];
	//              newValue += (x - xL) * (y - yL) * xHyH[rr];
	//              rgbArray[rr] = (int) newValue;
	//          }
	//      }
	//  from here: https://imagej.nih.gov/ij/plugins/download/Polar_Transformer.java
	//  explanation:
	//  x,y represent the top-left of a 1x1 pixel
	//  if x or y are not whole numbers the 1x1 pixel area overlaps its neighbours,
	//  the pixel value is the sum of the overlap fractions of its neighbour pixel squares,
	//  P is the fractional pixel address in its pixel, 1, 2 and 3 are its neighbours,
	//  dotted area is contribution from neighbours:
	//      +------+------+
	//      |  P   |   1  |
	//      |  ....|....  |  Ax = 1 - (Px - int(Px) = 1 - Px + int(Px) = (int(Px) + 1) - Px
	//      |  . A | B .  |  Ay = 1 - (Py - int(Py) = 1 - Py + int(Py) = (int(Py) + 1) - Py
	//      +------+------+  et al for B, C, D
	//      |  . D | C .  |
	//      |  ....|....  |
	//      |  3   |   2  |
	//      +----- +------+
	max_x, max_y := buffer.size()
	cx := x
	cy := y
	xl := int(cx)
	yl := int(cy)
	xh := xl + 1
	yh := yl + 1
	xu := math.min(xh, max_x - 1)
	yu := math.min(yh, max_y - 1)
	pixel_xlyl := buffer.get_pixel(xl, yl) as consts.MonochromePixel
	pixel_xlyh := buffer.get_pixel(xl, yu) as consts.MonochromePixel
	pixel_xhyl := buffer.get_pixel(xu, yl) as consts.MonochromePixel
	pixel_xhyh := buffer.get_pixel(xu, yu) as consts.MonochromePixel
	ratio_xlyl := (f32(xh) - cx) * (f32(yh) - cy)
	ratio_xhyl := (cx - f32(xl)) * (f32(yh) - cy)
	ratio_xlyh := (f32(xh) - cx) * (cy - f32(yl))
	ratio_xhyh := (cx - f32(xl)) * (cy - f32(yl))
	return [PixelPart{pixel_xlyl, ratio_xlyl}, PixelPart{pixel_xhyl, ratio_xhyl},
		PixelPart{pixel_xlyh, ratio_xlyh}, PixelPart{pixel_xhyh, ratio_xhyh}]
}

// make_pixel - get the interpolated pixel value from buffer at x,y (x and y can be fractional)
fn (buffer Buffer) make_pixel(x f32, y f32) f32 {
	parts := buffer.pixel_parts(x, y)
	part_xlyl := f32(parts[0].value.val) * parts[0].ratio
	part_xhyl := f32(parts[1].value.val) * parts[1].ratio
	part_xlyh := f32(parts[2].value.val) * parts[2].ratio
	part_xhyh := f32(parts[3].value.val) * parts[3].ratio
	return part_xlyl + part_xhyl + part_xlyh + part_xhyh
}

// upsize the given greyscale image by the given scale in both width and height,
// return a buffer that is scale times bigger in width and height than that given,
// the contents of the given buffer are scaled by interpolating neighbours (using makepixel),
// scale must be positive and greater than 1,
// each source pixel is considered to consist of scale * scale sub-pixels, each destination pixel
// is one sub-pixel and is constructed from an interpolation of a 1x1 source pixel area centred on
// the sub-pixel
pub fn (buffer Buffer) upsize(scale f32) !Buffer {
	if scale <= 1.0 {
		return buffer
	}
	max_x, max_y := buffer.size()
	width := int(math.round(max_x * scale))
	height := int(math.round(max_y * scale))
	mut upsized := new_grey(width, height, consts.min_luminance)
	for dest_x in 0 .. width {
		src_x := f32(dest_x) / scale
		for dest_y in 0 .. height {
			src_y := f32(dest_y) / scale
			pixel := buffer.make_pixel(src_x, src_y)
			upsized.put_pixel(dest_x, dest_y, consts.Colour(consts.MonochromePixel{u8(pixel)}))!
		}
	}
	return upsized
}

// set_text - set a text string at x,y of given colour (greyscale or a colour),
pub fn (buffer Buffer) set_text(text string, origin consts.Point, colour consts.Colour) !Buffer {
	// a very simple 5x7 bitmap font is used (good enough for our purposes)
	mut text_buffer := buffer.in_colour(colour) // colourize iff required
	mut cursor_x, mut cursor_y := int(origin.x), int(origin.y) // this is the bottom left of the text, i.e. the 'baseline'
	cursor_y -= fonts.simple_font_char_height // move it to the top
	start_x := cursor_x // used for new-lines (which we allow)
	for chr in text {
		if chr == '\n'[0] {
			cursor_x = start_x
			cursor_y += fonts.simple_font_char_height + 1 // +1 for the inter-line gap
			continue
		}
		chr_index := int(chr - ' '[0]) * fonts.simple_font_char_width
		if chr_index < 0 || chr_index >= fonts.simple_font.len {
			// ignore control chars and out-of-range chars
			continue
		}
		cols := fonts.simple_font[chr_index..chr_index + fonts.simple_font_char_width]
		for col, bits in cols {
			for row in 0 .. fonts.simple_font_char_height {
				if ((bits >> row) & 1) == 1 {
					// draw this bit
					x := cursor_x + col
					y := cursor_y + row
					text_buffer.put_pixel(x, y, colour)!
				}
			}
		}
		cursor_x += fonts.simple_font_char_width + 1 // +1 for the inter-char gap
	}
	return text_buffer
}

// line - draw a line as directed
pub fn (buffer Buffer) line(from_here consts.Point, to_there consts.Point, colour consts.Colour) !Buffer {
	mut lined := buffer.in_colour(colour) // colourize iff required
	points := draw.line(from_here.x, from_here.y, to_there.x, to_there.y)
	for point in points {
		lined.put_pixel(int(point.x), int(point.y), colour)!
	}
	return lined
}

// circle - draw a circle in the given colour, returns a modified buffer (colourised as required)
pub fn (buffer Buffer) circle(origin consts.Point, radius f32, colour consts.Colour) !Buffer {
	mut circled := buffer.in_colour(colour) // colourize iff required
	if radius < 1 {
		// too small for a circle, do a point instead
		circled.put_pixel(int(origin.x), int(origin.y), colour)!
		return circled
	}
	points := draw.circumference(origin.x, origin.y, radius)
	for point in points {
		circled.put_pixel(int(point.x), int(point.y), colour)!
	}
	return circled
}

// rectangle - draw a rectangle as directed (as four lines)
pub fn (buffer Buffer) rectangle(box consts.Box, colour consts.Colour) !Buffer {
	box_top_right := consts.Point{box.bottom_right.x, box.top_left.y}
	box_bottom_left := consts.Point{box.top_left.x, box.bottom_right.y}
	top := buffer.line(box.top_left, box_top_right, colour)!
	right := top.line(box_top_right, box.bottom_right, colour)!
	bottom := right.line(box.bottom_right, box_bottom_left, colour)!
	left := bottom.line(box_bottom_left, box.top_left, colour)!
	return left
}
