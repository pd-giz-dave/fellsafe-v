module consts

import math

// consts - hold-all for constants and types that are used all over the place

// History:
// 18/04/23 DCN: Created by copying and re-implementing const.py from the kilo-codes Python prototype

// Float - the floating point size we want to use
pub type Float = f32

// Empty - use in a sum type when an option is 'nothing'
pub struct Empty {}

// Point is the x,y co-ordinates of a pixel in some image (the co-ordinates may be fractional)
pub struct Point {
pub:
	x Float // < 0 means 'empty'
	y Float
}

// Line is a straight line identified by its start and end co-ordinates
pub struct Line {
pub:
	start Point
	end   Point
}

// Box is a rectangle in some image identified by its top-left and bottom-right corners
pub struct Box {
pub:
	top_left     Point
	bottom_right Point
}

// Colour rgb pixel (actually bgr to be compatible with openCV)
pub struct ColourPixel {
pub:
	b u8
	g u8
	r u8
}

pub struct MonochromePixel {
pub:
	val u8
}

type Colour = ColourPixel | Empty | MonochromePixel

// diagnostic image colours
pub const (
	black       = MonochromePixel{0}
	grey        = MonochromePixel{128}
	white       = MonochromePixel{255}
	red         = ColourPixel{0, 0, 255}
	green       = ColourPixel{0, 255, 0}
	dark_green  = ColourPixel{0, 128, 0}
	blue        = ColourPixel{255, 0, 0}
	dark_blue   = ColourPixel{64, 0, 0}
	yellow      = ColourPixel{0, 255, 255}
	purple      = ColourPixel{255, 0, 255}
	pink        = ColourPixel{128, 0, 128}
	pale_red    = ColourPixel{0, 0, 128}
	pale_blue   = ColourPixel{128, 0, 0}
	pale_green  = ColourPixel{0, 128, 0}
	cyan        = ColourPixel{255, 255, 0}
	olive       = ColourPixel{0, 128, 128}
	orange      = ColourPixel{80, 127, 255}
	pale_orange = ColourPixel{138, 189, 227}
	// synonyms
	lime        = green
	magenta     = purple
	maroon      = pale_red
	navy        = pale_blue
)

// binary/tertiary image luminance levels
pub const (
	min_luminance = black
	mid_luminance = grey
	max_luminance = white
)

// Video modes (image width in pixels)
const (
	video_sd  = 480
	video_hd  = 720
	video_fhd = 1080
	video_2k  = 1152
	video_4k  = 2160
)

const blur_kernel_size = 3 // 0==do not blur, helps in dropping large numbers of small anomalies

// Proximity options
// these control the contour detection, for big targets that cover the whole image a bigger
// integration area is required (i.e. smaller image fraction), this is used for testing print images
struct Proximity {
	box_size    int   // size of integration box when binarizing as a fraction of the image width
	black_level Float // % below the average considered to be black
}

const (
	proximity_far   = Proximity{48, 25.0} // suitable for most images (photos and videos)
	proximity_close = Proximity{3, -0.01} // suitable for print images
)

// Blob circle radius modes
pub const (
	radius_mode_none    = 0 // *MUST* be zero
	radius_mode_inside  = 1
	radius_mode_mean    = 2
	radius_mode_outside = 3
	radius_modes        = 4 // count of the number of modes
)

// Reject codes for blobs being ignored
struct Reject {
	description string // description of the reject reason
	colour      Colour // colour used to show it on contour images
	colour_name string // name of that colour (for hints in the logs)
}

const (
	reject_none       = Reject{'accepted', lime, 'lime'}
	reject_split      = Reject{'split at bottleneck', pale_red, 'pale red'}
	reject_splits     = Reject{'too many splits', red, 'red'}
	reject_sameness   = Reject{'too much sameness across contour edge', cyan, 'cyan'}
	reject_thickness  = Reject{'thickness too different to box size', pale_orange, 'pale orange'}
	reject_too_small  = Reject{'size below minimum', yellow, 'yellow'}
	reject_too_big    = Reject{'size above maximum', yellow, 'yellow'}
	reject_internals  = Reject{'too many internal contours', olive, 'olive'}
	reject_whiteness  = Reject{'not enough circle whiteness', maroon, 'maroon'}
	reject_blackness  = Reject{'too much box blackness', pink, 'pink'}
	reject_squareness = Reject{'not enough box squareness', navy, 'navy'}
	reject_wavyness   = Reject{'too much perimeter wavyness', magenta, 'magenta'}
	reject_offsetness = Reject{'too much centroid offsetness', orange, 'orange'}
)

// CRC parameters
pub const (
	payload_bits  = 10
	payload_range = 1 << payload_bits
	poly_bits     = 12
	polynomial    = 0xae3 // discovered by brute force search, has hamming distance of 7
		// polynomial        = 0xC75  // discovered by brute force search, has hamming distance of 7
)

// is_empty - test if a point is empty
pub fn (p Point) is_empty() bool {
	return !(p.x > Float(math.min_i16))
}

// empty_point - return an empty point
pub fn empty_point() Point {
	return Point{Float(math.min_i16), Float(math.min_i16)}
}

// str - format a point in a concise and consistent way
fn (p Point) str() string {
	if p.is_empty() {
		return '(None)'
	}
	return '(${p.x:.2f}, ${p.y:.2f})'
}

// str - format a box in a concise and consistent way
fn (b Box) str() string {
	if b.top_left.is_empty() {
		return '(None)'
	}
	return '${b.top_left}..${b.bottom_right}'
}
