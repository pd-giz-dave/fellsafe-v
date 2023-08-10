module codes

import rand
import crc
import logger
import canvas
import consts

const (
	cell_width         = 42 // creates an image that fits on A5
	cell_height        = 42 // ..

	test_pattern       = i32(0b010_01010_10101_01010_010)
	test_codes         = 10 // how many test codes to make

	test_pattern_name  = 'test-alt-bits'
	test_pattern_label = 'Alt zero and one'
)

fn test_draw_codeword() {
	mut log := logger.new_logger(file: 'codes.log', folder: 'codes')!
	log.log('Creating ${codes.test_codes} codes and the test pattern with cells ${codes.cell_width} x ${codes.cell_height}')!

	mut codec := crc.make_codec(logger: log)!

	draw_code := fn [mut log] (code int, label string, name string) ! {
		log.log('')!
		log.log('Creating code ${code:21b}...')!
		mut image := canvas.new_grey((max_x_cell + 1) * codes.cell_width, (max_y_cell + 1) * codes.cell_height,
			consts.min_luminance)
		mut kode := new_code(image)
		kode.draw_codeword(code, label)!
		log.draw(image: image, file: name)!
	}

	draw_code(codes.test_pattern, codes.test_pattern_label, codes.test_pattern_name)!

	for code in [266, 273, 814] { // these are what our test pattern can look like with 3+ errors
		codeword := codec.encode(code)!
		draw_code(codeword, '${code:03d}', 'test-code-${code:03d}')!
	}

	for test in 0 .. codes.test_codes {
		code := rand.int_in_range(101, 999)!
		codeword := codec.encode(code)!
		draw_code(codeword, '${code:03d}', 'test-code-${code:03d}')!
	}

	log.log('')!
	log.log('Done')!
}
