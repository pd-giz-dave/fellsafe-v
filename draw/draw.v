module draw

// draw - provides primitives for drawing lines and circles by providing x,y co-ordinate lists
import math
import consts

// translate and scale a circle or a point (caller just ignores radius when translating a point),
// if origin is +ve map from a full-image to a sub-image (an extraction from the full image),
// if origin is -ve map from a sub-image to a full-image,
// relative to (0,0) to be relative to origin and scale it by scale
pub fn translate(centre consts.Point, radius f32, origin consts.Point, scale f32) !(consts.Point, f32) {
	mut x, mut y, mut rad := f32(0), f32(0), radius
	if origin.x < 0 && origin.y < 0 {
		// map from a sub-image to a full-image
		x = (centre.x / scale) - origin.x
		y = (centre.y / scale) - origin.y
		rad /= scale
	} else if origin.x >= 0 && origin.y >= 0 {
		// map from full-image to a sub-image
		x = (centre.x - origin.x) * scale
		y = (centre.y - origin.y) * scale
		rad *= scale
	} else {
		return error('Origin must be (-ve,-ve) or (+ve,+ve) not a mixture ${origin}')
	}
	return consts.Point{x, y}, radius
}

// line - return a list of points that represent all pixels between x0,y0 and x1,y1 in the order x0,x0 -> x1,y1
pub fn line(x0 f32, y0 f32, x1 f32, y1 f32) []consts.Point {
	// see https://en.wikipedia.org/wiki/Bresenham%27s_line_algorithm for the algorithm implemented here

	line_low := fn (x0 int, y0 int, x1 int, y1 int) []consts.Point {
		mut points := []consts.Point{}
		// x0 <= x1 and slope <=1 guaranteed to get here
		dx := x1 - x0
		mut dy := y1 - y0
		mut yi := 1
		if dy < 0 {
			yi = -1
			dy = -dy
		}
		mut d := (2 * dy) - dx
		mut y := y0
		for x in x0 .. x1 + 1 {
			points << consts.Point{x, y}
			if d > 0 {
				y = y + yi
				d = d + (2 * (dy - dx))
			} else {
				d = d + 2 * dy
			}
		}
		return points
	}

	line_high := fn (x0 int, y0 int, x1 int, y1 int) []consts.Point {
		mut points := []consts.Point{}
		// y0 <= y1 and slope <=1 guaranteed to get here
		mut dx := x1 - x0
		dy := y1 - y0
		mut xi := 1
		if dx < 0 {
			xi = -1
			dx = -dx
		}
		mut d := (2 * dx) - dy
		mut x := x0
		for y in y0 .. y1 + 1 {
			points << consts.Point{x, y}
			if d > 0 {
				x = x + xi
				d = d + (2 * (dx - dy))
			} else {
				d = d + 2 * dx
			}
		}
		return points
	}

	mut points := []consts.Point{}
	if math.abs(y1 - y0) < math.abs(x1 - x0) {
		if x0 > x1 {
			points = line_low(int(x1), int(y1), int(x0), int(y0))
			points.reverse_in_place()
		} else {
			points = line_low(int(x0), int(y0), int(x1), int(y1))
		}
	} else {
		if y0 > y1 {
			points = line_high(int(x1), int(y1), int(x0), int(y0))
			points.reverse_in_place()
		} else {
			points = line_high(int(x0), int(y0), int(x1), int(y1))
		}
	}
	return points
}

// circumference - return a list of co-ordinates of a circle centred on x,y of radius r,
// x,y,r do not need to be integer but the returned co-ordinates will be integers,
// the co-ordinates returned are suitable for drawing the circle,
// co-ordinates returned are unique but in a random order,
// the algorithm here was inspired by: https://www.cs.helsinki.fi/group/goa/mallinnus/ympyrat/ymp1.html
pub fn circumference(centre_x_in f32, centre_y_in f32, r f32) []consts.Point {
	centre_x := int(math.round(centre_x_in))
	centre_y := int(math.round(centre_y_in))

	mut points := &[]consts.Point{} // list of x,y tuples for a circle of radius r centred on centre_x,centre_y

	plot := fn [mut points, centre_x, centre_y] (x_offset int, y_offset int) {
		// add the circle point for the given x,y offsets from the centre
		points << consts.Point{centre_x + x_offset, centre_y + y_offset}
	}

	circle_points := fn [plot] (x int, y int) {
		// make all 8 quadrant points from the one point given
		//    from https://www.cs.helsinki.fi/group/goa/mallinnus/ympyrat/ymp1.html
		//        Procedure Circle_Points(x,y: Integer);
		//        Begin
		//            Plot(x,y);
		//            Plot(y,x);
		//            Plot(y,-x);
		//            Plot(x,-y);
		//            Plot(-x,-y);
		//            Plot(-y,-x);
		//            Plot(-y,x);
		//            Plot(-x,y)
		//        End

		// NB: when a co-ord is 0, x and -x are the same, ditto for y

		if x == 0 && y == 0 {
			plot(0, 0)
		} else if x == 0 {
			plot(0, y)
			plot(y, 0)
			plot(0, -y)
			plot(-y, 0)
		} else if y == 0 {
			plot(x, 0)
			plot(0, x)
			plot(0, -x)
			plot(-x, 0)
		} else if x == y {
			plot(x, x)
			plot(x, -x)
			plot(-x, -x)
			plot(-x, x)
		} else if x == -y {
			plot(x, -x)
			plot(-x, x)
			plot(-x, -x)
			plot(x, x)
		} else {
			plot(x, y)
			plot(y, x)
			plot(y, -x)
			plot(x, -y)
			plot(-x, -y)
			plot(-y, -x)
			plot(-y, x)
			plot(-x, y)
		}
	}
	// from https://www.cs.helsinki.fi/group/goa/mallinnus/ympyrat/ymp1.html
	//    Begin {Circle}
	//    x := r;
	//    y := 0;
	//    d := 1 - r;
	//    Repeat
	//        Circle_Points(x,y);
	//        y := y + 1;
	//        if d < 0 Then
	//            d := d + 2*y + 1
	//        Else Begin
	//            x := x - 1;
	//            d := d + 2*(y-x) + 1
	//        End
	//    Until x < y
	//    End; {Circle}

	mut x := int(math.round(r))
	if x == 0 {
		// special case
		plot(0, 0)
	} else {
		mut y := 0
		mut d := 1 - x
		for {
			circle_points(x, y)
			y += 1
			if d < 0 {
				d += (2 * y + 1)
			} else {
				x -= 1
				d += (2 * (y - x) + 1)
			}
			if x < y {
				break
			}
		}
	}
	return *points
}

// intersection - find the intersection point between two lines, each line is a tuple pair of start/end points
// the cells are at the crossing points of the grid lines, we know where each line starts and end, so we can
// use determinants to find each intersection (see https://en.wikipedia.org/wiki/Line-line_intersection)
// intersection (Px,Py) between two non-parallel lines (x1,y1 -> x2,y2) and (x3,y3 -> x4,y4) is:
//   Px = (x1y2 - y1x2)(x3-x4) - (x1-x2)(x3y4 - y3x4)
//        -------------------------------------------
//              (x1-x2)(y3-y4) - (y1-y2)(x3-x4)
//
//   Py = (x1y2 - y1x2)(y3-y4) - (y1-y2)(x3y4 - y3x4)
//        -------------------------------------------
//              (x1-x2)(y3-y4) - (y1-y2)(x3-x4)
pub fn intersection(line1 consts.Line, line2 consts.Line) consts.Point {
	x1 := line1.start.x
	y1 := line1.start.y
	x2 := line1.end.x
	y2 := line1.end.y
	x3 := line2.start.x
	y3 := line2.start.y
	x4 := line2.end.x
	y4 := line2.end.y
	x1y2 := x1 * y2
	y1x2 := y1 * x2
	x3y4 := x3 * y4
	y3x4 := y3 * x4
	x3_x4 := x3 - x4
	x1_x2 := x1 - x2
	y3_y4 := y3 - y4
	y1_y2 := y1 - y2
	x1y2_y1x2 := x1y2 - y1x2
	x3y4_y3x4 := x3y4 - y3x4
	divisor := (x1_x2 * y3_y4) - (y1_y2 * x3_x4)
	px := ((x1y2_y1x2 * x3_x4) - (x1_x2 * x3y4_y3x4)) / divisor
	py := ((x1y2_y1x2 * y3_y4) - (y1_y2 * x3y4_y3x4)) / divisor
	return consts.Point{px, py}
}

// extend - extend the given line such that its ends meet the box walls
pub fn extend(line consts.Line, box consts.Box) !consts.Line {
	xmin := box.top_left.x
	ymin := box.top_left.y
	xmax := box.bottom_right.x
	ymax := box.bottom_right.y
	x1 := line.start.x
	y1 := line.start.y
	x2 := line.end.x
	y2 := line.end.y

	// sanity check
	if math.min(x1, x2) < xmin || math.max(x1, x2) > xmax || math.min(y1, y2) < ymin
		|| math.max(y1, y2) > ymax {
		return error('line: ${line} not within box: ${box}')
	}

	// deal with vertical and horizontal
	if x1 == x2 {
		// vertical line
		if y1 < y2 {
			// heading to the bottom
			return consts.Line{consts.Point{x1, ymin}, consts.Point{x2, ymax}}
		} else if y1 > y2 {
			// heading to the top
			return consts.Line{consts.Point{x1, ymax}, consts.Point{x2, ymin}}
		}
	} else if y1 == y2 {
		// horizontal line
		if x1 < x2 {
			// heading to the right
			return consts.Line{consts.Point{xmin, y1}, consts.Point{xmax, y2}}
		} else {
			// heading to the left
			return consts.Line{consts.Point{xmax, y1}, consts.Point{xmin, y2}}
		}
	}

	extend_down := fn [xmin, ymin, xmax, ymax] (x1 f32, y1 f32, x2 f32, y2 f32) (consts.Point, consts.Point) {
		// heading towards bottom-right
		// we use similar triangles to work it out, like so:
		//  _____
		//  ^ ^ *                               Line segment is x--x
		//  | | |\                              Extending upwards to X-min and downwards to X-max reaches *
		//  D'| | \                             By similar triangles A/B = E/F = E'/F' = C/D = C'/D'
		//  | | |C'\           X-max
		//  v | +---\------------+    Y-min
		//    D |    \           |
		//    | |  C  \  A       |
		//    v +------X--+      |
		//      |       \ | B    |
		//      |        \|      |
		//      |         X------+ ^
		//      |          \  E  | |
		//      |           \    | F
		//      +------------\---+ | ^ Y-max
		//    X-min           \E'| | |
		//                     \ | | F'
		//                      \| | |
		//                       * v v
		//                       _____
		dx := x2 - x1
		dy := y2 - y1
		slope := dx / dy
		// dx = A, dy = B, E = xmax-x2, so A/B = E/F, slope = A/B, F * slope = E, F = E / slope
		y_at_xmax := y2 + ((xmax - x2) / slope)
		end := if y_at_xmax > ymax {
			// overshot, so back up to ymax, F' = (y2 + F) - ymax, E'/F' = A/B, E' = (A/B)*F'
			x_at_ymax := xmax - slope * (y_at_xmax - ymax)
			consts.Point{x_at_ymax, ymax}
		} else {
			consts.Point{xmax, y_at_xmax}
		}
		// C = x1-xmin, A/B = C/D, D = C / (A/b)
		y_at_xmin := y1 - ((x1 - xmin) / slope)
		start := if y_at_xmin < xmin {
			// overshot, so back up to ymin (NB: y_at_xmin may go -ve, hence the abs() below)
			x_at_ymin := xmin + (slope * math.abs(y_at_xmin - xmin)) // A/B = C'/D', D'= D - X-min, so C' = (A/B) * D'
			consts.Point{x_at_ymin, ymin}
		} else {
			consts.Point{xmin, y_at_xmin}
		}
		return start, end
	}
	extend_up := fn [xmin, ymin, xmax, ymax] (x1 f32, y1 f32, x2 f32, y2 f32) (consts.Point, consts.Point) {
		// heading towards top-right
		// we use similar triangles to work it out, like so:
		//  Line segment is x--x
		//  Extending upwards to X-min and downwards to X-max reaches *
		//  By similar triangles A/B = C/D = C'/D' = E/F = E'/F'
		//                              _____
		//                              * ^ ^
		//                             /| | |
		//                            / | | D'
		//         X-min             /  | D |
		//    Y-min  +--------------/---+ | v
		//           |             / C' | |
		//           |            /     | |
		//           |           /  C   | |
		//           |          X-------+ V
		//           |         /|       |
		//           |        / | B     |
		//           |  E    /  |       |
		//         ^ +------X---+       |
		//         | |     /  A         |
		//         | | E' /             |
		//       ^ | +---/--------------+  Y-max
		//       | F |  /             X-max
		//       F'| | /
		//       | | |/
		//       v v *
		//       -----
		dx := x2 - x1
		dy := y1 - y2
		slope := dx / dy
		// dx = A, dy = B, C = X-max - x2, A/B = C/D, slope = A/B, slope * D = C, D = C / slope
		y_at_xmax := y2 - ((xmax - x2) / slope)
		end := if y_at_xmax < ymin { // NB: y_at_xmax may go -ve, hence the abs() below
			// overshot, back up to ymin, D' = y_at_xmax - ymin, C'/D' = A/B, C' = (A/B)*D'
			x_at_ymin := xmax - (slope * math.abs(y_at_xmax - ymin))
			consts.Point{x_at_ymin, ymin}
		} else {
			consts.Point{xmax, y_at_xmax}
		}
		// E = x1 - xmin, E/F = A/B, F * (A/B) = E, F = E / (A/B)
		y_at_xmin := y1 + ((x1 - xmin) / slope)
		start := if y_at_xmin > ymax {
			// overshot, back up to ymax, F' = F - ymax, E'/F' = A/B, E' = (A/B) * F'
			x_at_ymax := xmin + (slope * (y_at_xmin - ymax))
			consts.Point{x_at_ymax, ymax}
		} else {
			consts.Point{xmin, y_at_xmin}
		}
		return start, end
	}

	// which corner is the line heading towards?
	dx := x2 - x1
	dy := y2 - y1
	if dx > 0 && dy > 0 {
		// heading towards bottom-right
		start, end := extend_down(x1, y1, x2, y2)
		return consts.Line{start, end}
	} else if dx < 0 && dy < 0 {
		// heading towards top-left - same as bottom-right with start,end reversed
		start, end := extend_down(x2, y2, x1, y1)
		return consts.Line{end, start}
	} else if dx < 0 && dy > 0 {
		// heading towards bottom-left - same as top-right with start,end reversed
		start, end := extend_up(x2, y2, x1, y1)
		return consts.Line{end, start}
	} else { // dx > 0 and dy < 0
		// heading towards top-right
		start, end := extend_up(x1, y1, x2, y2)
		return consts.Line{start, end}
	}
}
