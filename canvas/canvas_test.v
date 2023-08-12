module canvas

import consts
import os

fn test_load_unload() {
	in_file := 'media/close-150-257-263-380-436-647-688-710-777.jpg'
	out_file := in_file.all_before_last('.') + '.png'
	buffer := load(in_file)!
	assert buffer.width == 4032
	assert buffer.height == 3024
	assert buffer.channels == 3
	buffer.unload(out_file)!
	assert os.exists(out_file)
}

fn test_greyscale() {
	in_path := 'media/close-150-257-263-380-436-647-688-710-777.jpg'
	out_path := in_path.all_before_last('.') + '-grey.png'
	image := load(in_path)!
	greyscale := image.greyscale()
	greyscale.unload(out_path)!
	new_image := load(out_path)!
	width, height := image.size()
	new_width, new_height := new_image.size()
	assert width == new_width && height == new_height
	assert new_image.channels == 1
}

fn test_integrate() {
	width, height := 4000, 2000
	mut image := new_grey(width, height)
	for x in 0 .. width {
		for y in 0 .. height {
			image.put_pixel(x, y, consts.Colour(consts.MonochromePixel{1}))!
		}
	}
	integrated := image.integrate()
	assert integrated.last().last() == width * height
}

fn test_downsize() {
	in_path := 'media/close-150-257-263-380-436-647-688-710-777.jpg'
	out_path := in_path.all_before_last('.') + '-small-grey.png'
	image := load(in_path)!
	greyscale := image.greyscale()
	downsized := greyscale.downsize(1568)!
	downsized.unload(out_path)!
	assert greyscale.width == 4032
	assert downsized.width == 1568
}

fn test_blur() {
	in_path := 'media/close-150-257-263-380-436-647-688-710-777.jpg'
	out_path := in_path.all_before_last('.') + '-blur-grey.png'
	image := load(in_path)!
	greyscale := image.greyscale()
	blurred := greyscale.blur(9)!
	blurred.unload(out_path)!
}

fn test_binarize() {
	in_path := 'media/close-150-257-263-380-436-647-688-710-777.jpg'
	out_path := in_path.all_before_last('.') + '-binary.png'
	image := load(in_path)!
	greyscale := image.greyscale()
	binarized := greyscale.binarize()!
	binarized.unload(out_path)!
}

fn test_extract() {
	pixel_value := fn (x f32, y f32) consts.Colour {
		return consts.MonochromePixel{u8((int(x) * 16) + int(y))}
	}
	full_width, full_height := 8, 8 // product must be <256, each must be power of 2
	box_width, box_height := full_width / 2, full_height / 2
	box_x, box_y := full_width / 4, full_height / 4
	box := consts.Box{consts.Point{box_x, box_y}, consts.Point{box_x + box_width - 1, box_y +
		box_height - 1}}
	mut full_image := new_grey(full_width, full_height)
	for x in 0 .. full_width {
		for y in 0 .. full_height {
			full_image.put_pixel(x, y, pixel_value(x, y))!
		}
	}
	extracted := full_image.extract(box)!
	assert extracted.get_pixel(0, 0) == pixel_value(box.top_left.x, box.top_left.y)
	assert extracted.get_pixel(box_width - 1, box_height - 1) == pixel_value(box.bottom_right.x,
		box.bottom_right.y)
}

fn test_upsize() {
	in_path := 'media/close-150-257-263-380-436-647-688-710-777.jpg'
	out_path := in_path.all_before_last('.') + '-big-grey.png'
	out_path2 := in_path.all_before_last('.') + '-tiny-grey.png'
	image := load(in_path)!
	greyscale := image.greyscale()
	downsized := greyscale.downsize(greyscale.width / 8)!
	downsized.unload(out_path2)!
	upsized := downsized.upsize(8)!
	upsized.unload(out_path)!
	assert greyscale.width == 4032
	assert downsized.width == 4032 / 8
	assert upsized.width == 4032
}

fn test_drawing() {
	out_file := 'drawing.png'
	greyscale := new_grey(500, 500)
	step1 := greyscale.set_text('The quick brown fox jumps over the lazy dog! - 0.123456789',
		consts.Point{10, 10}, consts.red)!
	step2 := step1.line(consts.Point{10, 20}, consts.Point{90, 30}, consts.green)!
	step3 := step2.circle(consts.Point{40, 40}, 24, consts.blue)!
	step4 := step3.circle(consts.Point{40, 40}, 8, consts.blue)!
	step5 := step4.circle(consts.Point{40, 40}, 4, consts.blue)!
	step6 := step5.rectangle(consts.Box{consts.Point{100, 100}, consts.Point{120, 120}},
		consts.magenta)!
	step6.unload(out_file)!
	assert os.exists(out_file)
	println('Written ${out_file}')
}
