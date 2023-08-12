module shapes

import consts
import math
import draw

fn test_circle() {
	origin := 20
	radius := f32(8)
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

fn test_get_enclosing_box() {
}
