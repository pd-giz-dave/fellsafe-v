// History:
// 14/04/23 DCN: Created...ish

module main

// main is the glue for the modules in the system
import canvas
import consts
import os
import draw

fn test_intersection() ! {
	line1 := consts.Line{consts.Point{10, 10}, consts.Point{20, 20}}
	line2 := consts.Line{consts.Point{10, 20}, consts.Point{20, 10}}
	cross_at := draw.intersection(line1, line2)
	assert cross_at == consts.Point{15, 15}
}

fn main() {
	test_intersection()!
}
