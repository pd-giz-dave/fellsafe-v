module shapes

import canvas
import consts
import math
import draw

// shapes - structs that provide properties for our contours

// History
// 10/08/23 DCN: Created by copying and re-implementing shapes.py from the kilo-codes Python prototype

// Slice - a slice defines a vertical or horizontal strip through an image (context defines which)
struct Slice {
	xy     int // where the slice is
	min_yx int // start of slice
	max_yx int // end of slice
}

// str - pretty format a slice
fn (s Slice) str() string {
	return '(@${s.xy} ${s.min_yx}..${s.max_yx})'
}

// count_pixels - count how many pixels in the area bounded by perimeter within image are black and how many are white,
//   perimeter is a list of x co-ords and the max/min y at that x (i.e a 'vertical' slice),
//   perimeter points are inside the area,
//   co-ords outside the image bounds are ignored,
//   the image must be in binary form
fn count_pixels(image canvas.Buffer, perimeter []Slice) (int, int) {
	limit_x, limit_y := image.size()
	mut black := 0
	mut white := 0
	for slice in perimeter {
		for y in slice.min_yx .. slice.max_yx + 1 {
			if y >= limit_y || y < 0 {
				// ignore outside the image height
			} else if slice.xy >= limit_x || slice.xy < 0 {
				// ignore outside image width
			} else if image.get_pixel(slice.xy, y) == consts.Colour(consts.black) {
				black += 1
			} else {
				white += 1
			}
		}
	}
	return black, white
}

////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////

// Circle - a circle has a centre, radius and a list of points on its circumference (as vertical slices)
pub struct Circle {
	centre consts.Point
	radius f64
pub mut:
	points []Slice
}

pub fn new_circle(centre consts.Point, radius f64) Circle {
	mut circle := Circle{
		centre: centre
		radius: radius
	}
	return circle
}

// str - pretty format a Circle
pub fn (c Circle) str() string {
	return '(centre:${c.centre}, radius:${c.radius:.2f}, area:${c.area():.2f})'
}

// area - calculate the area of the circle
pub fn (c Circle) area() f64 {
	return math.pi * c.radius * c.radius
}

// perimeter - get the x,y co-ordinates of the perimeter of the circle,
//             the co-ords are returned as a list of slices (in random order)
//             where each slice is the x co-ord and its two y co-ords,
//             this format is compatible with count_pixels()
pub fn (mut c Circle) perimeter() []Slice {
	if c.points.len > 0 {
		// already done it
		return c.points
	}
	// this is expensive, so only do it once
	points := draw.circumference(c.centre.x, c.centre.y, c.radius)
	// we want a min_y/max_y value pair for every x
	mut y_limits := map[int][]int{}
	for point in points {
		x := int(point.x)
		y := int(point.y)
		mut value := y_limits[x]
		if value.len == 0 {
			y_limits[x] = [y, y]
		} else if y < value[0] {
			y_limits[x][0] = y
		} else if y > value[1] {
			y_limits[x][1] = y
		}
	}
	// build our slices
	for x, limits in y_limits {
		min_y := limits[0] + 1 // we want exclusive co-ords
		max_y := limits[1] - 1 // ..
		// NB: min_y > max_y can happen at the x extremes, but we chuck those, so we don't care
		c.points << Slice{x, min_y, max_y}
	}
	return c.points
}

//////////////////////////////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////////////////////////////

// Contour - properties of a contour and methods to create/access them,
//          the contour only knows the co-ordinates of its points, it knows nothing of the underlying image,
//          NB: most of the metrics of a contour are in the range 0..1 where 0 is good and 1 is very bad
struct Contour {
mut:
	small          int // contour perimeter length of this or less is considered to be small (affects wavyness function)
	points         []consts.Point // points that make up the contour (NB: contours are a 'closed' set of points)
	enclosing_box  consts.Box     // both points same means not set
	blob_perimeter []consts.Point // unique points on the contour
	x_slices       []Slice
	y_slices       []Slice
	centroid       consts.Point // empty means not set
	radius         []f64        // radius of 0 means not set
	offset         f64 // less than 0 means not set
}

// reset - reset all cached data (so they get re-calculated on next access)
fn (mut c Contour) reset() {
	c.enclosing_box = consts.Box{}
	c.blob_perimeter = []
	c.x_slices = []
	c.y_slices = []
	c.centroid = consts.empty_point()
	c.radius = []f64{len: consts.radius_modes}
	c.offset = -1
}

pub fn new_contour(small int) Contour {
	mut contour := Contour{
		small: small
	}
	contour.reset()
	return contour
}

[params]
pub struct ShowParams {
	verbose bool
	prefix  string = '    '
}

// show - produce a string describing the contour for printing purposes,
//        if verbose is True a multi-line response is made that describes all properties,
//        lines after the first are prefixed by prefix
pub fn (mut c Contour) show(p ShowParams) string {
	if c.points.len == 0 {
		return 'None'
	}
	first_line := 'start:${c.points[0]}, box:${c.get_enclosing_box()}, size:${c.get_size()}, points:${c.points.len}, small:${c.small}'
	if !p.verbose {
		return first_line
	}
	second_line := 'centroid:${c.get_centroid()}, offsetness:${c.get_offsetness():.2f}, squareness:${c.get_squareness():.2f}, wavyness:${c.get_wavyness(0):.2f}'
	return '${first_line}\n${p.prefix}${second_line}'
}

// str - pretty format a Contour
fn (mut c Contour) str() string {
	return c.show()
}

// add_point - add a point to the contour
pub fn (mut c Contour) add_point(point consts.Point) {
	c.points << point
}

// get_enclosing_box - get the minimum sized box that encloses the contour
fn (mut c Contour) get_enclosing_box() consts.Box {
	if c.points.len > 0 {
		if c.enclosing_box.top_left == c.enclosing_box.bottom_right {
			// not been done yet - do it now
			mut top_left_x := math.max_i32
			mut top_left_y := math.max_i32
			mut bottom_right_x := math.min_i32
			mut bottom_right_y := math.min_i32
			for point in c.points {
				x, y := int(point.x), int(point.y)
				if x < top_left_x {
					top_left_x = x
				}
				if y < top_left_y {
					top_left_y = y
				}
				if x > bottom_right_x {
					bottom_right_x = x
				}
				if y > bottom_right_y {
					bottom_right_y = y
				}
			}
			c.enclosing_box = consts.Box{consts.Point{top_left_x, top_left_y}, consts.Point{bottom_right_x, bottom_right_y}}
		}
	}
	return c.enclosing_box
}

// get_wavyness - wavyness is a measure of how different the length of the perimeter is to the number of contour points,
//                result is in range 0..1, where 0 is not wavy and 1 is very wavy,
//                this is a very cheap metric that can be used to quickly drop junk,
//                if small given is >0 it overwrites that given to the Contour constructor
fn (mut c Contour) get_wavyness(small int) f64 {
	if c.points.len == 0 {
		return 1.0
	}
	perimeter := c.get_blob_perimeter()
	if small > 0 {
		c.small = small
	}
	if perimeter.len <= c.small {
		// too small to be measurable
		return 0.0
	}
	// NB: number of points is always more than the perimeter length (by at least 1)
	return 1.0 - (f64(perimeter.len) / f64(c.points.len))
}

// get_size - the size is the maximum width and height of the contour,
//            i.e. the size of the enclosing box
//            this is a very cheap metric that can be used to quickly drop junk
fn (mut c Contour) get_size() (f64, f64) {
	box := c.get_enclosing_box()
	if box.top_left == box.bottom_right {
		return 0, 0
	}
	width := box.bottom_right.x - box.top_left.x + 1
	height := box.bottom_right.y - box.top_left.y + 1
	return width, height
}

// get_squareness - squareness is a measure of how square the enclosing box is,
//                  result is in range 0..1, where 0 is perfect square, 1 is very thin rectangle,
//                  this is a very cheap metric that can be used to quickly drop junk
fn (mut c Contour) get_squareness() f64 {
	x, y := c.get_size()
	ratio := math.min(x, y) / math.max(x, y) // in range 0..1, 0=bad, 1=good
	return 1.0 - ratio // in range 0..1, 0=square, 1=very thin rectangle
}

// get_offsetness - offsetness is a measure of the distance from the centroid to the enclosing box centre,
//                  result is in range 0..1, where 0 is exactly coincident, 1 is very far apart
fn (mut c Contour) get_offsetness() f64 {
	if c.offset < 0 {
		box := c.get_enclosing_box()
		box_size_x, box_size_y := c.get_size()
		max_x := box_size_x / 2.0
		max_y := box_size_y / 2.0
		box_centre := consts.Point{box.top_left.x + max_x, box.top_left.y + max_y}
		centroid := c.get_centroid() // NB: this cannot be outside the enclosing box
		mut x_diff := box_centre.x - centroid.x // max this can be is box_size_x/2
		x_diff *= x_diff
		mut y_diff := box_centre.y - centroid.y // max this can be is box_size_y/2
		y_diff *= y_diff
		distance := x_diff + y_diff // most this can be is (box_size_x/2)^2 + (box_size_y/2)^2
		limit := math.max((max_x * max_x) + (max_y * max_y), 1.0)
		c.offset = distance / limit
	}
	return c.offset
}

// get_x_slices - get the slices in x,
//                for every unique x co-ord find the y extent at that x,
//                this function is lazy
fn (mut c Contour) get_x_slices() []Slice {
	if c.x_slices.len == 0 && c.points.len > 0 {
		mut x_slices := map[int][]int{}
		for point in c.points {
			x, y := int(point.x), int(point.y)
			if x in x_slices {
				x_slices[x] << y
			} else {
				x_slices[x] = [y]
			}
		}
		c.x_slices = []
		for x, ys in x_slices {
			mut min_y := math.max_i32
			mut max_y := math.min_i32
			for y in ys {
				if y < min_y {
					min_y = y
				}
				if y > max_y {
					max_y = y
				}
			}
			c.x_slices << Slice{x, min_y, max_y}
		}
	}
	return c.x_slices
}

// get_y_slices - get the slices in y array,
//                for every unique y co-ord find the x extent at that y,
//                this function is lazy
fn (mut c Contour) get_y_slices() []Slice {
	if c.y_slices.len == 0 && c.points.len > 0 {
		mut y_slices := map[int][]int{}
		for point in c.points {
			x, y := int(point.x), int(point.y)
			if y in y_slices {
				y_slices[y] << x
			} else {
				y_slices[y] = [x]
			}
		}
		c.y_slices = []
		for y, xs in y_slices {
			mut min_x := math.max_i32
			mut max_x := math.min_i32
			for x in xs {
				if x < min_x {
					min_x = x
				}
				if x > max_x {
					max_x = x
				}
			}
			c.y_slices << Slice{y, min_x, max_x}
		}
	}
	return c.y_slices
}

// get_centroid - get the centroid of the blob as: sum(points)/num(points)
fn (mut c Contour) get_centroid() consts.Point {
	if c.centroid.is_empty() {
		mut sum_x := 0
		mut num_x := 0
		for slice in c.get_x_slices() {
			samples := slice.max_yx - slice.min_yx + 1
			sum_x += samples * slice.xy
			num_x += samples
		}
		mut sum_y := 0
		mut num_y := 0
		for slice in c.get_y_slices() {
			samples := slice.max_yx - slice.min_yx + 1
			sum_y += samples * slice.xy
			num_y += samples
		}
		c.centroid = consts.Point{(f64(sum_x) / f64(num_x)) + 0.5, (f64(sum_y) / f64(num_y)) + 0.5} //+0.5 is to get to the pixel centre
	}
	return c.centroid
}

// get_blob_perimeter - get the unique contour perimeter points,
//                      NB: contour.points are in clockwise order, that is preserved in the perimeter
//                      this function is lazy
fn (mut c Contour) get_blob_perimeter() []consts.Point {
	if c.blob_perimeter.len == 0 {
		// not done it yet
		mut seen := map[int]map[int]int{}
		for p, point in c.points {
			x, y := int(point.x), int(point.y)
			if seen[x][y] == 0 {
				// first time we've seen this x,y, so its unique
				seen[x][y] = p + 1 // make sure it is not 0
				c.blob_perimeter << point
			} else {
				// seen this x,y before, so ignore it as not unique
			}
		}
	}
	return c.blob_perimeter
}

// get_blob_radius - get the radius of the blob from its centre for the given mode,
//                   when mode is inside the radius found is the maximum that fits entirely inside the contour
//                   when mode is outside the radius found is the minimum that fits entirely outside the contour
//                   when mode is mean the radius found is the mean distance to the contour perimeter
//                   this is an expensive operation so its lazy, calculated on demand and then cached
fn (mut c Contour) get_blob_radius(mode int) f64 {
	if c.radius[mode] == consts.radius_mode_none {
		centre := c.get_centroid() // the centre of mass of the blob (assuming its solid)
		// the perimeter points are the top-left of a 1x1 pixel square, we want their centre, so we add 0.5
		perimeter := c.get_blob_perimeter()
		mut mean_distance_squared := f64(0)
		mut min_distance_squared := f64(math.max_i32)
		mut max_distance_squared := f64(math.min_i32)
		for point in perimeter {
			mut x := point.x + 0.5
			mut y := point.y + 0.5
			mut x_distance := centre.x - x
			x_distance *= x_distance
			mut y_distance := centre.y - y
			y_distance *= y_distance
			distance := x_distance + y_distance
			mean_distance_squared += distance
			if min_distance_squared > distance {
				min_distance_squared = distance
			}
			if max_distance_squared < distance {
				max_distance_squared = distance
			}
		}
		mut outside_r := f64(0)
		mut inside_r := f64(0)
		mut mean_r := f64(0)
		if perimeter.len <= c.small {
			// too small to do anything but outer
			outside_r = f64(math.max(f64(math.sqrt(max_distance_squared)), f64(0.5)))
			inside_r = outside_r
			mean_r = outside_r
		} else {
			mean_distance_squared /= perimeter.len
			mean_r = f64(math.max(math.sqrt(mean_distance_squared), f64(0.5)))
			inside_r = f64(math.max(math.sqrt(min_distance_squared), f64(0.5)))
			outside_r = f64(math.max(math.sqrt(max_distance_squared), f64(0.5)))
		}
		// cache all results
		c.radius[consts.radius_mode_inside] = inside_r
		c.radius[consts.radius_mode_outside] = outside_r
		c.radius[consts.radius_mode_mean] = mean_r
	}
	// return just the one asked for
	return c.radius[mode]
}

// ToDo: cache the circles in the contour
//
// get_enclosing_circle - get the requested circle type
fn (mut c Contour) get_enclosing_circle(mode int) Circle {
	return new_circle(c.get_centroid(), c.get_blob_radius(mode))
}

// get_circle_perimeter - get the perimeter of the enclosing circle,
//                        NB: the circle perimeter is expected to be cached by the Circle instance
fn (mut c Contour) get_circle_perimeter(mode int) []Slice {
	mut circle := c.get_enclosing_circle(mode)
	return circle.perimeter()
}

//////////////////////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////////////////////

/*
class Blob:
//""" a blob is an external contour and its properties,
//    a blob has access to the underlying image (unlike a Contour)
//    """

def __init__(self, label: int, image, inverted: bool, mode, small: int):
	self.label: int = label
	self.image = image  # the binary image buffer the blob was found within
	self.inverted = inverted  # True if its a black blob, else a white blob
	self.mode = mode  # what type of circle radius required (one of Contour.RADIUS...)
	self.small = small  # any blob with a perimeter of this or less is considered to be 'small'
	self.external: Contour = None
	self.internal: [Contour] = []  # list of internal contours (NB: we're only interested in how many)
	self.rejected = const.REJECT_NONE  # why it was rejected (if it was)
	self.reset()

def __str__(self):
	return self.show()

def reset(self):
	//""" reset all the cached stuff """
	self.blob_black = None
	self.blob_white = None
	self.box_black = None
	self.box_white = None
	self.circle_black = None
	self.circle_white = None
	self.thickness = None  # property set externally, ratio of box size to average contour thickness
	self.sameness  = None  # property set externally, luminance level change across contour edge as fraction of max
	self.splitness = None  # property set externally, how many times the blob was split

def add_contour(self, contour: Contour):
	//""" add a contour to the blob, the first contour is the external one,
	//    subsequent contours are internal,
	//    all contours are guaranteed to have their first and last point the same (needed by later processes)
	//"""
	# the first and last point of a contour must be the same, if not add it
	points = contour.points
	if points is None or len(points) == 0:
		breakpoint()
		raise Exception('Attempt to add a contour with no points')
	if len(points) > 1:
		if points[0] != points[-1]:
			//# add a last point same as first (this is important when calculating perimeter directions later)
			contour.add_point(points[0])
	if self.external is None:
		self.external = contour
	else:
		self.internal.append(contour)

def show(self, verbose: bool = False, prefix: str = '    '):
	//""" describe the blob for printing purposes,
	//    if verbose is True a multi-line response is made that describes all properties,
	//    lines after the first are prefixed by prefix
	//    """
	header = "label:{}({})".format(self.label, self.rejected)
	if self.external is None:
		return header
	body = '{}, {}'.format(header, self.external.show(verbose, prefix))
	if verbose:
		size = self.get_size()
		size = (size[0] + size[1]) / 2
		body = '{}\n{}internals:{}, blob_pixels:{}, box_pixels:{}, size:{:.2f}, ' \
			   'blackness:{}, whiteness:{}, thickness:{}, sameness:{}, splitness:{}'.\
			   format(body, prefix, len(self.internal),
					  self.get_blob_pixels(), self.get_box_pixels(), size,
					  utils.show_number(self.get_blackness()),
					  utils.show_number(self.get_whiteness()),
					  utils.show_number(self.thickness), utils.show_number(self.sameness),
					  utils.show_number(self.splitness))
	return body

def get_blob_pixels(self):
	//""" get the total white area and black area within the perimeter of the blob """
	if self.external is None:
		return None
	if self.blob_black is not None:
		return self.blob_black, self.blob_white
	self.blob_black, self.blob_white = count_pixels(self.image, self.external.get_x_slices())
	return self.blob_black, self.blob_white

def get_box_pixels(self):
	//""" get the total white area and black area within the enclosing box of the blob """
	if self.external is None:
		return None
	if self.box_black is not None:
		return self.box_black, self.box_white
	(top_left_x, top_left_y), (bottom_right_x, bottom_right_y) = self.external.get_enclosing_box()
	//# build 'x-slices' for the box
	x_slices = []
	for x in range(top_left_x, bottom_right_x + 1):
		x_slices.append((x, top_left_y, bottom_right_y))
	self.box_black, self.box_white = count_pixels(self.image, x_slices)
	return self.box_black, self.box_white

def get_size(self) -> float:
	//""" get the width and height of the bounding box """
	if self.external is None:
		return None
	return self.external.get_size()

def get_perimeter(self):
	//""" get the unique points around the blob perimeter as a list of x,y points in clockwise order """
	if self.external is None:
		return None
	perimeter = self.external.get_blob_perimeter()  # NB: relying on a Python dict preserving the insertion order
	return [(x, y) for x, y in perimeter.keys()]

def get_points(self):
	//""" get all the points of the blob contour as a list of x,y points in clockwise order """
	if self.external is None:
		return None
	return self.external.points  # NB: relying on contours being 'clockwise' followed

def get_enclosing_circle(self) -> Circle:
	//""" get the enclosing circles of the blob contour """
	if self.external is None:
		return None
	return self.external.get_enclosing_circle(self.mode)

def get_quality_stats(self):
	//""" get all the 'quality' statistics for a blob """
	return (self.get_squareness(),'squareness'), \
		   (self.get_wavyness()  ,'wayness'   ), \
		   (self.get_whiteness() ,'whiteness' ), \
		   (self.get_blackness() ,'blackness' ), \
		   (self.get_offsetness(),'offsetness'), \
		   (self.thickness       ,'thickness' ), \
		   (self.sameness        ,'sameness'  ), \
		   (self.splitness       ,'splitness' )

def get_circle_pixels(self):
	//""" get the total white area and black area within the enclosing circle """
	if self.external is None:
		return None
	if self.circle_black is not None:
		return self.circle_black, self.circle_white
	self.circle_black, self.circle_white = count_pixels(self.image, self.external.get_circle_perimeter(self.mode))
	return self.circle_black, self.circle_white

def get_squareness(self) -> float:
	if self.external is None:
		return None
	return self.external.get_squareness()

def get_wavyness(self) -> float:
	//""" this allows for filtering very irregular blobs """
	if self.external is None:
		return None
	return self.external.get_wavyness(self.small)

def get_offsetness(self) -> float:
	//""" this measure how far the centre of mass is from the centre of the enclosing box,
	//    this allows for filtering elongated blobs (e.g. a 'saucepan')
	//    """
	if self.external is None:
		return None
	return self.external.get_offsetness()

def get_whiteness(self) -> float:
	//""" whiteness is a measure of how 'white' the area covered by the enclosing circle is,
	//    (contrast this with blackness which covers the whole enclosing box)
	//    when inverted is false:
	//        result is in range 0..1, where 0 is all white and 1 is all black,
	//    when inverted is True:
	//        result is in range 0..1, where 0 is all black and 1 is all white,
	//    this allows for filtering out blobs with lots of holes in it
	//    """
	if self.external is None:
		return None
	black, white = self.get_circle_pixels()
	if (black + white) <= self.small:
		//# too small to measure
		return 0.0
	if self.inverted:
		return white / (black + white)
	else:
		return black / (black + white)

def get_blackness(self) -> float:
	//""" blackness is a measure of how 'white' the area covered by the enclosing box is,
	//    (contrast this with whiteness which covers the enclosing circle)
	//    when inverted is false:
	//        result is in range 0..1, where 0 is all white and 1 is all black,
	//    when inverted is True:
	//        result is in range 0..1, where 0 is all black and 1 is all white,
	//    this allows for filtering out sparse symmetrical blobs (e.g. a 'star')
	//    """
	if self.external is None:
		return None
	black, white = self.get_box_pixels()
	if (black + white) <= self.small:
		//# too small to measure
		return 0.0
	if self.inverted:
		return white / (black + white)
	else:
		return black / (black + white)

def extract(self, start, end):
	//""" create a new blob like this one but consisting only of the external points
	//    between start and end inclusive, the resulting external contour is made
	//    to be closed by joining start to end with a straight line (8-connected).
	//    NB: end index may be lower than start, i.e. we're wrapping, that's benign
	//        because contours are closed loops.
	//    """
	//# make a new contour and populate it with the required points
	contour = Contour(self.small)
	points  = self.get_points()
	point   = start
	while point != ((end+1) % len(points)):
		if point == (len(points)-1):
			//# skip the last point as we know its the same as the first (enforced by add_contour())
			pass
		else:
			contour.add_point(points[point])
		point = (point + 1) % len(points)
	//# join the ends by adding more points from the end to the start
	start_x, start_y = points[start]
	end_x  , end_y   = points[end  ]
	join = utils.line(end_x, end_y, start_x, start_y)
	//# NB: join will contain the first and last point, which we do not want
	for sample in range(1, len(join)-1):
		contour.add_point(join[sample])
	//# make a new blob with this contour
	extracted = Blob(self.label, self.image, self.inverted, self.mode, self.small)
	extracted.add_contour(contour)  # NB: This will add the final point to be same as the first
	return extracted


class Labels:
//""" label to blob map """
blobs = None

def add_label(self, label: int, blob: Blob):
	if self.blobs is None:
		self.blobs = {}
	self.blobs[label] = blob

def get_blob(self, label: int):
	if self.blobs is None:
		return None
	elif label in self.blobs:
		return self.blobs[label]
	else:
		# no such label
		return None
*/
