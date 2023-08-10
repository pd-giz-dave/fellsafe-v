module draw

import consts

[assert_continues]
fn test_line() {
	check_line := fn (x0 f32, y0 f32, x1 f32, y1 f32, name string) {
		points := line(x0, y0, x1, y1)
		print('Test_line for ${name}: ')
		assert points.first() == consts.Point{x0, y0} && points.last() == consts.Point{x1, y1}
	}
	check_line(0, 0, 0, -10, 'N')
	check_line(0, 0, 3, -10, 'NNE')
	check_line(0, 0, 10, -10, 'NE')
	check_line(0, 0, 10, -3, 'ENE')
	check_line(0, 0, 10, 0, 'E')
	check_line(0, 0, 10, 3, 'ESE')
	check_line(0, 0, 10, 10, 'SE')
	check_line(0, 0, 3, 10, 'SSE')
	check_line(0, 0, 0, 10, 'S')
	check_line(0, 0, -3, 10, 'SSW')
	check_line(0, 0, -10, -10, 'SW')
	check_line(0, 0, -10, -3, 'WSW')
	check_line(0, 0, -10, 0, 'W')
	check_line(0, 0, -10, -3, 'WNW')
	check_line(0, 0, -10, -10, 'NW')
	check_line(0, 0, -3, -10, 'NNW')
	// points1 := line(0, 0, 10, 10)
	// points2 := line(0, 10, 10, 0)
	// points3 := line(0, 0, 10, 9)
	// points4 := line(10, 10, 0, 9)
	// print(points1)
	// print(points2)
	// print(points3)
	// print(points4)
}

fn test_circumference() {
	points := circumference(20, 20, 10)
	// print('${points.len} ${points.first()} ${points.last()}')
	assert points.len == 56 && points.first() == consts.Point{30, 20}
		&& points.last() == consts.Point{13, 27}
	// print('Circumference points: ${points}')
}

fn test_translate() {
	centre := consts.Point{10, 10}
	radius := 10
	full_origin := consts.Point{10, 10}
	sub_origin := consts.Point{-10, -10}
	scale := 2
	reduced_centre, reduced_radius := translate(centre, radius, full_origin, scale)!
	increased_centre, increased_radius := translate(reduced_centre, reduced_radius, sub_origin,
		scale)!
	assert increased_centre == centre && increased_radius == radius
}

fn test_intersection() {
	line1 := consts.Line{consts.Point{10, 10}, consts.Point{20, 20}}
	line2 := consts.Line{consts.Point{10, 20}, consts.Point{20, 10}}
	cross_at := intersection(line1, line2)
	assert cross_at == consts.Point{15, 15}, 'Intersects at ${cross_at} when expect ${consts.Point{15, 15}}'
}

[assert_continues]
fn test_extend() {
	check_extend := fn (start consts.Point, end consts.Point, box consts.Box, name string, expect_start consts.Point, expect_end consts.Point) ! {
		error_allowed_squared := f32(1) // max squared error tolerated
		extended := extend(consts.Line{start, end}, box)!
		mut error_start_x := extended.start.x - expect_start.x
		error_start_x *= error_start_x
		mut error_start_y := extended.start.y - expect_start.y
		error_start_y *= error_start_y
		mut error_end_x := extended.end.x - expect_end.x
		error_end_x *= error_end_x
		mut error_end_y := extended.end.y - expect_end.y
		error_end_y *= error_end_y
		print('Test_extend for ${name}: ')
		assert error_start_x <= error_allowed_squared && error_end_x <= error_allowed_squared
			&& error_start_y <= error_allowed_squared && error_end_y <= error_allowed_squared,
			'${name}: ${start} -> ${end} extends to ${extended.start} -> ${extended.end} when expected ${expect_start} -> ${expect_end}' +
			'(${error_start_x}, ${error_start_y}; ${error_end_x}, ${error_end_y}; > ${error_allowed_squared})'
	}
	tl := consts.Point{5, 5}
	tr := consts.Point{14, 5}
	br := consts.Point{14, 14}
	bl := consts.Point{5, 14}
	box := consts.Box{tl, br}
	check_extend(consts.Point{6, 6}, consts.Point{7, 7}, box, 'diagonal++', tl, br)!
	check_extend(consts.Point{7, 7}, consts.Point{6, 6}, box, 'diagonal--', br, tl)!
	check_extend(consts.Point{12, 7}, consts.Point{13, 6}, box, 'diagonal+-', bl, tr)!
	check_extend(consts.Point{13, 6}, consts.Point{12, 7}, box, 'diagonal-+', tr, bl)!
	check_extend(consts.Point{6, 9}, consts.Point{6, 10}, box, 'vertical+', consts.Point{6, 5},
		consts.Point{6, 14})!
	check_extend(consts.Point{6, 10}, consts.Point{6, 9}, box, 'vertical-', consts.Point{6, 14},
		consts.Point{6, 5})!
	check_extend(consts.Point{9, 10}, consts.Point{11, 10}, box, 'horizontal+', consts.Point{5, 10},
		consts.Point{14, 10})!
	check_extend(consts.Point{11, 10}, consts.Point{9, 10}, box, 'horizontal-', consts.Point{14, 10},
		consts.Point{5, 10})!
	check_extend(consts.Point{6, 12}, consts.Point{8, 13}, box, 'shallow slope++low',
		consts.Point{5, 11}, consts.Point{9, 14})!
	check_extend(consts.Point{8, 13}, consts.Point{6, 12}, box, 'shallow slope--low',
		consts.Point{9, 14}, consts.Point{5, 11})!
	check_extend(consts.Point{6, 13}, consts.Point{8, 12}, box, 'shallow slope+-low',
		consts.Point{5, 13}, consts.Point{14, 9})!
	check_extend(consts.Point{6, 7}, consts.Point{8, 8}, box, 'shallow slope++high', consts.Point{5, 6},
		consts.Point{14, 11})!
	check_extend(consts.Point{8, 8}, consts.Point{6, 7}, box, 'shallow slope--high', consts.Point{14, 11},
		consts.Point{5, 6})!
	check_extend(consts.Point{6, 7}, consts.Point{7, 10}, box, 'steep slope++high', consts.Point{5, 5},
		consts.Point{8, 14})!
	check_extend(consts.Point{13, 7}, consts.Point{12, 5}, box, 'steep slope--high', consts.Point{14, 9},
		consts.Point{12, 5})!
	check_extend(consts.Point{6, 7}, consts.Point{7, 5}, box, 'steep slope+-high', consts.Point{5, 9},
		consts.Point{7, 5})!
	check_extend(consts.Point{7, 5}, consts.Point{6, 7}, box, 'steep slope-+high', consts.Point{7, 5},
		consts.Point{5, 9})!
}
