// History:
// 18/04/23 DCN: Created by copying and re-implementing utils.py logger class from the kilo-codes Python prototype

////////////////////////////////////////////////////////
// A simple logger to a file and the console
// Also provides serialisation/de-serialisation via JSON
////////////////////////////////////////////////////////

module logger

import os
import canvas
import json

// allows function calls with a trailing struct to be omitted
[params]
pub struct Context {
mut:
	context string
	folder  string
}

pub struct Logger {
mut:
	is_open    bool
	log_file   string = 'log'
	log_handle os.File
	context    []Context // array of string(context), string(folder)
	prefix     string = '  '
	count      int
}

pub fn (mut l Logger) close() {
	if l.is_open {
		// close the file
		l.log_handle.close()
		l.is_open = false
	}
}

// free auto called when the logger goes out of scope or is explicitly free'd
fn (mut l Logger) free() {
	l.close()
}

pub fn (mut l Logger) log(msg string) ! {
	lines := if msg == '\n' { [''] } else { msg.split('\n') }
	for line, text in lines {
		prefix := if line > 0 { l.prefix } else { '' }
		log_msg := '${l.context[0].context}: ${prefix}${text}'
		l.put(log_msg + '\n')!
	}
}

// just writes what's given, no annotations, no new-line
pub fn (mut l Logger) put(msg string) ! {
	if !l.is_open {
		panic('attempt to put to log before logger is open')
	}
	for chr in msg {
		l.log_handle.write([chr])!
	}
	os.flush()
	print(msg)
}

[params]
pub struct NewLoggerParams {
	file    string = 'logger.log'
	folder  string = '.'
	context ?string
	prefix  string = '  '
}

pub fn new_logger(p NewLoggerParams) !&Logger {
	dest := p.folder
	// make sure destination folder exists
	os.mkdir_all(dest)!
	mut l := &Logger{}
	l.log_file = '${dest}/${p.file}'
	l.context = [Context{p.context or { p.file.split('.')[0] }, dest}] // must add 1st element manually
	l.prefix = p.prefix // when logging multi-line messages prefix all lines except the first with this
	l.count = 0 // incremented for every anonymous draw call and used as a file name suffix
	l.log_handle = os.open_file(l.log_file, 'w')!
	l.is_open = true
	l.log('open ${p.file}')!
	return l
}

pub fn (mut l Logger) push(p Context) ! {
	mut new_context := p
	if new_context.context == '' {
		new_context.context = l.context[0].context
	} else {
		new_context.context = '${l.context[0].context}/${new_context.context}'
	}
	if new_context.folder == '' {
		new_context.folder = l.context[0].folder
	} else {
		new_context.folder = '${l.context[0].folder}/${new_context.folder}'
	}
	l.context.insert(0, new_context)
}

pub fn (mut l Logger) pop() !Context {
	if l.context.len < 2 {
		return error('attempt to pop last context')
	}
	popped := l.context[0]
	l.context.delete(0)
	return popped
}

pub fn (l Logger) depth() int {
	return l.context.len
}

// unload the given image into the given folder and file,
// folder, iff given, is a sub-folder to save it in (its created as required),
// the parent folder is that given when the logger was created,
// all images are saved as a sub-folder of the parent,
// file is the file name to use, blank==invent one
[params]
pub struct DrawParams {
	image  canvas.Buffer [required]
	folder string
	file   string
	ext    string = 'png'
	prefix string
}

pub fn (mut l Logger) draw(p DrawParams) !string {
	filename := l.makepath(p.folder, p.file, p.ext)!

	// save the image
	p.image.unload(filename)!

	l.log(p.prefix + p.file + ': image saved as: ' + filename)!
	return filename
}

// make the required folder and return the fully qualified file name
fn (mut l Logger) makepath(folder ?string, file ?string, ext ?string) !string {
	mut filename := file or { '' }
	if filename == '' {
		filename = 'logger-${l.count}'
		l.count += 1
	}
	mut foldername := folder or { '' }
	if foldername == '' {
		foldername = l.context[0].folder
	}

	// make sure the destination folder exists
	os.mkdir_all(foldername)!

	filename = '${foldername}/${filename}.${ext or { 'png' }}'
	return filename
}

struct SaveParams[T] {
	object T      [required]
	folder string
	file   string
	ext    string = 'object'
}

// save the given object to the given file (so it can be restored later),
// returns the fully qualified file name used
pub fn (mut l Logger) save[T](p SaveParams[T]) !string {
	filename := l.makepath(p.folder, p.file, p.ext)!
	object_text := json.encode(p.object)
	os.write_file(filename, object_text)!
	l.log('${p.file}: object saved as: ${filename}')!
	return filename
}

struct RestoreParams {
	folder   string  // used to re-construct filename iff not given
	file     string  // ..
	ext      string = 'object' // ....
	filename ?string // iff given, folder, file, ext are ignored
}

// restore a previously saved object, returning the object or error if it does not exist
// NB: the logger context must be the same as when the object was saved if no filename is given
pub fn (mut l Logger) restore[T](p RestoreParams) !T {
	filename := p.filename or { l.makepath(p.folder, p.file, p.ext)! }
	object_text := os.read_file(filename)!
	object := json.decode(T, object_text)!
	l.log('Restored object from ${filename}')!
	return object
}
