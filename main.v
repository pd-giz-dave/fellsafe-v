// History:
// 14/04/23 DCN: Created...ish

module main

// main is the glue for the modules in the system
import os
import canvas

fn test_load_unload() ! {
	in_file := 'media/close-150-257-263-380-436-647-688-710-777.jpg'
	out_file := in_file.all_before_last('.') + '.png'
	buffer := canvas.load(in_file)!
	buffer.unload(out_file)!
	assert os.exists(out_file)
}

fn main() {
	test_load_unload()!
}
