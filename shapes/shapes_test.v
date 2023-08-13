module shapes

import consts
import math
import draw

fn test_circle() {
	origin := 20
	radius := f64(8)
	mut circle := new_circle(consts.Point{origin, origin}, radius)
	print('test_circle: area: ')
	assert circle.area() == math.pi * radius * radius
	println('test_circle: str: ${circle}')
	points := draw.circumference(origin, origin, radius)
	println('test_circle: circumference: ${points}')
	mut perimeter := circle.perimeter()
	perimeter.sort(a.xy < b.xy)
	println('test_circle: perimeter: ${perimeter}')
	assert perimeter.first().min_yx == perimeter.last().min_yx
		&& perimeter.first().max_yx == perimeter.last().max_yx, 'perimeter first ${perimeter.first()} not same as last ${perimeter.last()}'
}

// build_contour_points - build a contour point set for testing Contour shape properties
fn build_contour_points(width int, height int, offset int) []consts.Point {
	// build a simple rectangle as directed (in clockwise order as if detected as a contour)
	min_x := offset
	max_x := min_x + width - 1
	min_y := offset
	max_y := min_y + height - 1
	mut points := []consts.Point{}
	for x in min_x .. max_x + 1 {
		points << consts.Point{x, min_y} // top edge
	}
	for y in min_y + 1 .. max_y + 1 {
		points << consts.Point{max_x, y} // right edge
	}
	for x := max_x - 1; x >= min_x; x-- {
		points << consts.Point{x, max_y} // bottom edge
	}
	for y := max_y - 1; y >= min_y; y-- {
		points << consts.Point{min_x, y} // left edge
	}
	return points
}

fn test_contour() {
	width, height, offset := 10, 5, 10 // a simple 2:1 rectangle
	mut contour := new_contour(4)
	points := build_contour_points(width, height, offset)
	for point in points {
		contour.add_point(point)
	}
	println('test_contour: points (${contour.points.len}): ${contour.points}')
	print('test_contour: points: ')
	expected_len := (2 * width) + (2 * (height - 2)) + 1
	assert contour.points.len == expected_len
	println('test_contour: contour: ${contour}')
	box := contour.get_enclosing_box()
	print('test_contour: box: ')
	assert box == consts.Box{consts.Point{offset, offset}, consts.Point{width + offset - 1,
		height + offset - 1}}
	print('test_contour: size: ')
	box_width, box_height := contour.get_size()
	assert box_width == f64(width) && box_height == f64(height)
	squareness := contour.get_squareness()
	print('test_contour: squareness: ${squareness} ')
	assert squareness == f64(height) / f64(width)
	perimeter := contour.get_blob_perimeter()
	println('test_contour: perimeter (${perimeter.len}): ${perimeter}')
	print('test_contour: perimeter: ')
	assert perimeter.len == contour.points.len - 1
	wavyness := contour.get_wavyness(0)
	print('test_contour: wavyness: ${wavyness}: ')
	assert wavyness == 1.0 - (f64(expected_len - 1) / f64(expected_len))
	x_slices := contour.get_x_slices()
	println('test_contour: x_slices (${x_slices.len}): ${x_slices}')
	print('test_contour: x_slices: ')
	assert x_slices.len == width && x_slices.first() == Slice{offset, offset, offset + height - 1}
	y_slices := contour.get_y_slices()
	println('test_contour: y_slices (${y_slices.len}): ${y_slices}')
	print('test_contour: y_slices: ')
	assert y_slices.len == height && y_slices.first() == Slice{offset, offset, offset + width - 1}
	centroid := contour.get_centroid()
	print('test_contour: centroid: ${centroid}: ')
	assert centroid.x == (f64(width) / 2) + f64(offset)
		&& centroid.y == (f64(height) / 2) + f64(offset)
	offsetness := contour.get_offsetness()
	print('test_contour: offsetness: ${offsetness}: ')
	assert offsetness == 0.0
	println('test_contour: show: ${contour.show(verbose: true, prefix: 'test_contour: show: ')}')
	blob_radius_mean := contour.get_blob_radius(consts.radius_mode_mean)
	print('test_contour: blob_radius: ${contour.radius}: ')
	assert contour.radius[consts.radius_mode_inside] < contour.radius[consts.radius_mode_mean]
		&& contour.radius[consts.radius_mode_mean] < contour.radius[consts.radius_mode_outside]
	enclosing_circle := contour.get_enclosing_circle(consts.radius_mode_outside)
	println('test_contour: enclosing_circle: ${enclosing_circle}')
	circle_perimeter := contour.get_circle_perimeter(consts.radius_mode_outside)
	println('test_contour: circle_perimeter: ${circle_perimeter}')
}
