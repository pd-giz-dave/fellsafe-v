module logger

import canvas
import os

fn test_new_logger() {
	println('Start test new_logger...')
	mut logger := new_logger(
		file: 'test_logger.log'
		folder: 'test_folder/nested'
		context: 'context'
		prefix: '##'
	)!
	dump(logger)
	println('...end test new_logger')
}

fn test_logger() {
	println('Start test logger...')
	mut logger := new_logger(file: 'test_logger.log', folder: 'test_folder', prefix: '##')!
	logger.log('initial 2-line message\nLine 2')!
	logger.push(context: 'pushed context', folder: 'pushed folder')!
	logger.log('after first push')!
	logger.push(context: 'second push')!
	logger.log('after second push')!
	logger.push()!
	logger.log('after third push')!
	dump(logger)
	assert logger.depth() == 4
	logger.pop()!
	logger.log('after first pop')!
	logger.pop()!
	logger.log('after second pop')!
	logger.pop()!
	logger.log('after third pop')!
	dump(logger)
	failed := false
	if popped := logger.pop() {
		assert true, 'Got ${popped} when expected error on excess pop'
	} else {
		logger.log('Got expected error on excess pop: ${err.msg()}')!
	}
	assert logger.depth() == 1
	println('...end test logger')
}

fn test_draw() {
	println('Start test draw...')
	mut logger := new_logger(file: 'test_logger.log', folder: 'test_folder')!
	image_file := 'media/close-150-257-263-380-436-647-688-710-777.jpg'
	buffer := canvas.load(image_file)!
	filename := logger.draw(image: buffer, folder: 'media', file: 'image')!
	dump(logger)
	assert filename == 'media/image.png'
	assert os.exists(filename)
	println('...end test draw')
}

struct SaveObject {
	s1 string = 'a string'
	n1 int    = 42
	f1 f64    = 3.14157
	a1 []int  = [1, 2, 3]
}

fn test_save() {
	println('Start test save...')
	mut logger := new_logger(file: 'test_logger.log', folder: 'test_folder')!
	to_save := SaveObject{}
	saved_file := logger.save(object: to_save, folder: 'objects', file: 'saveobject')!
	assert saved_file == 'objects/saveobject.object'
	assert os.exists(saved_file)
	from_save := logger.restore[SaveObject](folder: 'objects', file: 'saveobject')!
	assert to_save == from_save
	dump(from_save)
	println('...end test save')
}
