// History:
// 18/08/23 DCN: Created by copying and re-implementing the codes.py module from the kilo-codes Python prototype

// Draw/metric codewords primitives
/*
Codewords are characterised by a detection/orientation pattern and a data area.
    The detection/orientation pattern is implicit knowledge in this class.
    The data area structure is implicit knowledge, its contents come from outside
    or are delivered to outside.
    Structure overview:
    0____1____2____3____4____  5____  6____  7____  8____9____10___11___12___
    _________________________  _____  _____  _____  _________________________
    1____xxxxxxxxxxxxxxx_____  _____  _____  _____  _____xxxxxxxxxxxxxxx_____
    _____xxxxxxxxxxxxxxx_____  _____  _____  _____  _____xxxxxxxxxxxxxxx_____
    2____xxxxxxxxxxxxxxx_____  *****  _____  *****  _____xxxxxxxxxxxxxxx_____  <-- column markers
    _____xxxxxxxxxxxxxxx_____  *****  _____  *****  _____xxxxxxxxxxxxxxx_____  <--
    3____xxxxxxxxxxxxxxx_____  _____  _____  _____  _____xxxxxxxxxxxxxxx_____
    _____xxxxxxxxxxxxxxx_____  _____  _____  _____  _____xxxxxxxxxxxxxxx_____

    4         -----     _____  .....  .....  .....  _____     _____
              -----     _____  . A .  . B .  . C .  _____     _____
              -----     _____  .....  .....  .....  _____     _____

    5         *****_____.....  .....  .....  .....  ....._____*****
              *****_____. H .  . G .  . F .  . E .  . D ._____*****
              *****_____.....  .....  .....  .....  ....._____*****

    6         -----     .....  .....  .....  .....  .....     _____
              -----     . I .  . J .  . K .  . L .  . M .     _____
              -----     .....  .....  .....  .....  .....     _____

    7         *****_____.....  .....  .....  .....  ....._____*****
              *****_____. R .  . Q .  . P .  . O .  . N ._____*****
              *****_____.....  .....  .....  .....  ....._____*****

    8         _____     _____  .....  .....  .....  _____     _____
              _____     _____  . S .  . T .  . U .  _____     _____
              _____     _____  .....  .....  .....  _____     _____

    9____xxxxxxxxxxxxxxx_____  _____  _____  _____  _________________________
    _____xxxxxxxxxxxxxxx_____  _____  _____  _____  _________________________
    10___xxxxxxxxxxxxxxx_____  *****  _____  *****  __________mmmmm__________  <-- column markers
    _____xxxxxxxxxxxxxxx_____  *****  _____  *****  __________mmmmm__________  <--
    11___xxxxxxxxxxxxxxx_____  _____  _____  _____  _________________________
    _____xxxxxxxxxxxxxxx_____  _____  _____  _____  _________________________
    12_______________________  _____  _____  _____  _________________________
    0____1____2____3____4____  5____  6____  7____  8____9____10___11___12___
              ^^^^^                                           ^^^^^
              |||||                                           |||||
              +++++--------------- row markers ---------------+++++

    xx..xx are the 'major locator' blobs, top-left is the 'primary' locator,
    mm..mm is the 'minor locator' blob that is the same size as a marker blob
    **** are the row/column 'marker' blobs
    all locator and marker blobs are detected by their contour
    ....   is a 'bit box' that can be either a '1' (white) or a '0' (black)
    a '1' is white area (detected by its relative luminance)
    a '0' is black area (detected by its relative luminance)
    the background (____) is white (paper) and the blobs are black holes in it
    A..U are the bits of the codeword (21)
    their centre co-ordinates and size are calculated from the marker blobs
    numbers in the margins are 'cell' addresses (in units of the width of a marker blob)
    only cell addresses 2,2..10,10 are 'active' in the sense they are detected and processed
    Note: The bottom-right 'minor locator' is much smaller than the others but its centre
          still aligns with bottom-left and top-right 'major locator' blobs
*/

module codes

import consts
import canvas
import math

pub struct Cell { // co-ordinates of a cell
	x int
	y int
}

// join_lists - make a joined copy of the given two lists
fn join_lists(list1 []Cell, list2 []Cell) []Cell {
	mut joined := list1.clone()
	joined << list2
	return joined
}

const ( // geometry
	// all drawing co-ordinates are in units of a 'cell' where a 'cell' is the minimum width between
	// luminance transitions, cell 0,0 is the top left of the canvas
	// the major locator blobs are 3x3 cells starting at 1,1
	// the minor locator blob is 1x1 cells
	// the marker blobs and data blobs are 1x1 cells, marker blobs are separated by at least 1 cell
	// NB: these co-ords are relative to the canvas
	locators    = [Cell{1, 1}, Cell{1, 2}, Cell{1, 3}, Cell{9, 1},
		Cell{10, 1}, Cell{11, 1}, Cell{2, 1}, Cell{2, 2}, Cell{2, 3},
		Cell{9, 2}, Cell{10, 2}, Cell{11, 2}, Cell{3, 1}, Cell{3, 2},
		Cell{3, 3}, Cell{9, 3}, Cell{10, 3}, Cell{11, 3}, Cell{1, 9},
		Cell{2, 9}, Cell{3, 9}, Cell{1, 10}, Cell{2, 10}, Cell{3, 10},
		Cell{10, 10}, Cell{1, 11}, Cell{2, 11}, Cell{3, 11}]
	markers     = [Cell{5, 2}, Cell{7, 2}, Cell{2, 5}, Cell{10, 5},
		Cell{2, 7}, Cell{10, 7}, Cell{5, 10}, Cell{7, 10}]
	structure   = join_lists(locators, markers) // NB: this runs at compile time
	data_offset = Cell{2, 2}
	data_bits   = [Cell{3, 2}, Cell{4, 2}, Cell{5, 2}, Cell{6, 3},
		Cell{5, 3}, Cell{4, 3}, Cell{3, 3}, Cell{2, 3}, Cell{2, 4},
		Cell{3, 4}, Cell{4, 4}, Cell{5, 4}, Cell{6, 4}, Cell{6, 5},
		Cell{5, 5}, Cell{4, 5}, Cell{3, 5}, Cell{2, 5}, Cell{3, 6},
		Cell{4, 6}, Cell{5, 6}]
	name_cell   = Cell{9, 12} // canvas co-ordinate of the bottom-left of the text label
	max_x_cell  = 12 // canvas size
	max_y_cell  = 12 // ..
)

pub const (
	locators_per_code = 3 // how many 'major' locators there are per code
	timing_per_code   = 9 // how many 'timing' marks there are per code (including the 'minor' locator)
	locator_scale     = 3 // size of major locators relative to markers (so radius of enclosing circle is half this)
	locator_span      = 8 // distance between locator centres in units of *marker width*
	locator_spacing   = locator_span / (locator_scale / 2) // locator spacing in units of *locator radius*
	// These cell positions are relative to the 'active' area of the code (see visualisation above)
	timing_cells      = [3, 5] // timing mark cell positions along a line between locators (all 4 sides)
	data_cells        = data_bits // public face of the data bits (same as internal as it happens)
	black_cells       = [Cell{0, 0}, Cell{3, 0}, Cell{5, 0}, Cell{8, 0}, // active cell areas guaranteed to be black
		Cell{0, 3}, Cell{8, 3}, Cell{0, 5}, Cell{8, 5}, Cell{0, 8},
		Cell{3, 8}, Cell{5, 8}, Cell{8, 8}]
	white_cells       = [Cell{2, 0}, Cell{4, 0}, Cell{6, 0}, // active cell areas guaranteed to be white
		Cell{0, 2}, Cell{8, 2}, Cell{0, 4}, Cell{8, 4}, Cell{0, 6},
		Cell{8, 6}, Cell{2, 8}, Cell{4, 8}, Cell{6, 8}]
)

pub struct Codes {
	max_x       int // canvas size in pixels
	max_y       int // ..
	code_span   int // max size of the code drawing surface in pixels
	cell_width  int // width of a 'cell' in pixels
	cell_height int // height of a 'cell' in pixels (same as width)
mut:
	surface canvas.Buffer [required] // where we do our drawing (it should be square)
}

pub fn new_code(image_buffer canvas.Buffer) Codes {
	max_x, max_y := image_buffer.size()
	span := math.min(max_x, max_y)
	width := int(math.round(span / (codes.max_x_cell + 1)))
	codes := Codes{max_x, max_y, span, width, width, image_buffer}
	return codes
}

// cell2pixel - convert a cell in marker units to one in pixel units
fn (c Codes) cell2pixel(cell Cell) consts.Point {
	x := int(math.round(cell.x * c.cell_width))
	y := int(math.round(cell.y * c.cell_height))
	return consts.Point{x, y}
}

// draw_cell - make the Cell at position the given colour, the given cell is a 'marker' unit cell
fn (mut c Codes) draw_cell(position Cell, colour consts.MonochromePixel) ! {
	pixel_cell := c.cell2pixel(position)
	end_x := pixel_cell.x + c.cell_width
	end_y := pixel_cell.y + c.cell_height
	for x in int(pixel_cell.x) .. int(end_x) {
		for y in int(pixel_cell.y) .. int(end_y) {
			c.surface.put_pixel(x, y, colour)!
		}
	}
}

// clear_canvas - make the entire codeword structure white
fn (mut c Codes) clear_canvas() ! {
	for x in 0 .. codes.max_x_cell + 1 {
		for y in 0 .. codes.max_y_cell + 1 {
			c.draw_cell(Cell{x, y}, consts.white)!
		}
	}
}

// draw_structure - draw the given structure (==a list of black cell addresses)
fn (mut c Codes) draw_structure(structure []Cell) ! {
	for cell in structure {
		c.draw_cell(cell, consts.black)!
	}
}

// draw_name - draw the codeword name
fn (mut c Codes) draw_name(position Cell, name string) ! {
	c.surface.set_text(name, c.cell2pixel(position), consts.black)!
}

// draw_codeword - codeword is the A..P data bits,
//                 name is the readable version of the codeword and is drawn alongside the codeword,
//                 the codeword is drawn as large as possible within the canvas
pub fn (mut c Codes) draw_codeword(codeword int, name string) ! {
	c.clear_canvas()!
	c.draw_structure(codes.structure)!
	mut bit := 0
	for cell in codes.data_bits {
		data_cell := Cell{cell.x + codes.data_offset.x, cell.y + codes.data_offset.y} // map from active area to canvas
		mask := 1 << bit
		if codeword & mask == 0 {
			c.draw_cell(data_cell, consts.black)!
		}
		bit += 1
		c.draw_name(codes.name_cell, name)!
	}
}
