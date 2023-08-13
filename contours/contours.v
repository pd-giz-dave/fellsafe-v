module contours

// contours - Find contours of 4-connected components.
//    This module is a re-implementation of blob.h from https://github.com/BlockoS/blob
//    Which is a C implementation of:
//        "A linear-time component-labeling algorithm using contour tracing technique"
//        by Fu Chang, Chun-Jen Chen, and Chi-Jen Lu.
//    It has been tweaked to reduce the connectivity searched from 8 to 4 (i.e. direct neighbours only).
//    It is also extended to compute the area of the components found and various other properties.
//    Blame the original for any weird looking logic in here!

// History:
// 10/08/23 DCN: Created by copying and re-implementing contours.py from the kilo-codes Python prototype
//
import canvas
import consts
import shapes

// co-ordinates of pixel neighbours relative to that pixel, clockwise from 'east':
//   [5][6][7]
//   [4][-][0]
//   [3][2][1]
const (
	dx = [1, 1, 0, -1, -1, -1, 0, 1] // x-offset
	dy = [0, 1, 1, 1, 0, -1, -1, -1] // .. y-offset
)

// Params - a holder for the parameters required by find_targets and its result
[params]
pub struct Params {
pub mut:
	source_file        string // file name of originating source image (for diagnostic naming purposes only)
	source             canvas.Buffer [required] // the source greyscale image buffer
	blurred            canvas.Buffer // the blurred greyscale image buffer
	binary             canvas.Buffer // the binarized blurred image buffer
	box                consts.Box    // when not 'empty'' the box within the image to process, else all of it
	inverted           bool = False // if True look for black blobs, else white blobs
	blur_kernel_size   int  = 3 // blur kernel size to apply, 0 == do not blur
	small              int  = 4 // contour perimeter small threshold
	mode               int  = consts.radius_mode_mean // what type of circle radius mode to use
	integration_width  int  = 48 // width of integration area as fraction of image width
	integration_height int  = 0 // height of integration area as fraction of image height (0==same as width)
	black_threshold    f64  = 0.01 // make +ve to get more white, -ve to get more black, range +100%..-100%
	// NB: Make a small +ve number to ensure totally white stays white
	white_threshold   f64  = 0 // grey/white threshold, 0 == same as black (i.e. binary)
	direct_neighbours bool = true // true == 4-connected, false == 8-connected
	blobs             []shapes.Blob // all detected contours
	contours          shapes.Blob // the contours buffer
	labels            shapes.Labels // the label to blob map for all the contours detected
}

/*
def contour_trace(image, buffer, label: int, x: int, y: int,
                  external: bool = True, direct: bool = True, inverted: bool=False) -> shapes.Contour:
    """ follow the contour at x,y in image giving it label in buffer,
        if external is True follow an external contour, else internal,
        if direct is True use 4-connected neighbours else 8,
        if inverted is True follow black contours, else white,
        both image and buffer must be the same shape, have an 'outside' border and x,y must never be in it,
        """
    if inverted:
        follow = BLACK
    else:
        follow = WHITE
    if external:
        i: int = 7
    else:
        i: int = 3
    if direct:
        offset: int = 1
        i = (i + 1) & 7
    else:
        offset: int = 0
    x0: int = x
    y0: int = y
    xx: int = -1  # 2nd white pixel visited is saved here
    yy: int = -1  # ..
    buffer[y, x] = label
    contour: shapes.Contour = shapes.Contour()
    done: bool = False
    while not done:
        contour.add_point((x0, y0))
        # scan around current pixel in clockwise order starting after last white hit
        j: int = 0
        while j < 8:
            x1: int = x0 + dx[i]
            y1: int = y0 + dy[i]
            if image[y1, x1] == follow:
                buffer[y1, x1] = label
                if xx < 0 and yy < 0:
                    xx = x1  # note 2nd white pixel visited
                    yy = y1  # ..
                else:
                    # we are done if we crossed the first 2 contour points again
                    done = (x == x0) and (y == y0) and (xx == x1) and (yy == y1)
                x0 = x1
                y0 = y1
                break
            else:
                buffer[y1, x1] = -1
            j += (1 + offset)
            i = (i + 1 + offset) & 7
        if j == 8:
            # isolated point
            done = True
        else:
            # compute next start position
            previous: int = (i + 4) & 7
            i = (previous + 2) & 7
    return contour

def find_blobs(image, direct=True, inverted=False, mode=const.RADIUS_MODE_MEAN, small=4) -> [shapes.Blob]:
    """ find blobs in the given image,
        if inverted is True look for black blobs, else white
        returns a list of Blob's or None if failed
    """
    if inverted:
        find_outside = WHITE  # the colour *outside* the blob we look for
    else:
        find_outside = BLACK  # the colour *outside* the blob we look for
    width = image.shape[1]
    height = image.shape[0]
    if width < 3 or height < 3:
        return None
    # allocate a label buffer
    buffer = np.zeros((height, width), np.int32)  # NB: must be signed values, 0==background
    # put a 'follow' border around the image edge 1 pixel wide
    # put a -1 border around the buffer edges 1 pixel wide
    # this means we can scan from 1,1 to max-1,max-1 and not need to bother about the edges
    for x in range(width):
        image[0, x] = find_outside
        image[height-1, x] = find_outside
        buffer[0, x] = -1
        buffer[height - 1, x] = -1
    for y in range(height):
        image[y, 0] = find_outside
        image[y, width-1] = find_outside
        buffer[y, 0] = -1
        buffer[y, width - 1] = -1
    # scan for start points and follow each
    blobs = []                           # blob list is built in here
    labels = shapes.Labels()             # label to blob map is in here
    label = 0                            # current label (0=background)
    for y in range(1, height-1):         # ignore first and last row (don't care about image edge)
        for x in range(1, width-1):      # ..ditto for first and last column
            # find a start point as the next non-zero pixel
            here_in = image[y, x]
            if here_in == find_outside:
                continue
            above_in = image[y-1, x]
            below_in = image[y+1, x]
            here_label = buffer[y, x]
            above_label = buffer[y-1, x]
            before_label = buffer[y, x-1]
            below_label = buffer[y+1, x]
            if here_label == 0 and above_in == find_outside:
                # found a new start
                label += 1               # assign next label
                blob = shapes.Blob(label, image, inverted, mode, small)
                blob.add_contour(contour_trace(image, buffer, label, x, y,
                                               external=True, direct=direct, inverted=inverted))
                blobs.append(blob)
                labels.add_label(label, blob)
            elif below_label == 0 and below_in == find_outside:
                # found a new internal contour (a hole)
                if before_label < 1:
                    # this means its a hole in 'here'
                    if here_label == 0:
                        before_label = above_label
                    else:
                        before_label = here_label
                current_blob = labels.get_blob(before_label)
                if current_blob is None:
                    raise Exception('Cannot find current blob when before label is {} at {}x{}y'.
                                    format(before_label, x, y))
                current_blob.add_contour(contour_trace(image, buffer, before_label, x, y,
                                                       external=False, direct=direct, inverted=inverted))
            elif here_label == 0:
                # found an internal element of an external contour
                buffer[y, x] = before_label

    return blobs, buffer, labels

def find_contours(source, params: Params, logger=None):
    """ given a greyscale image find all contours according to the given params,
        returns a list of targets where each is a tuple of x:float, y:float, radius:float, label:int
        x,y is the pixel address of the centre of the target and radius is its radius in pixels,
        all may be fractional,
        label is the label number assigned to the blob the target was detected within,
        although the ideal target consists of square blobs, we report them as if they are circles,
        this is so we do not have to deal with shape rotation, we are only interested in relative
        distances not shapes, so this is fine,
        NB: The presence of a logger implies we are debugging
        """
    if logger is not None:
        logger.push("find_contours")
        logger.log('')
    params.source  = source
    params.blurred = canvas.blur(source, params.blur_kernel_size)
    params.binary  = canvas.binarize(params.blurred,
                                     params.box,
                                     params.integration_width,
                                     params.integration_height,
                                     params.black_threshold,
                                     params.white_threshold)
    blobs, buffer, labels = find_blobs(params.binary, params.direct_neighbours, mode=params.mode,
                                       inverted=params.inverted, small=params.small)
    params.blobs    = blobs
    params.contours = buffer
    params.labels   = labels
    if logger is not None:
        # show what happened
        show_results(params, logger)
        logger.pop()
    return params

def show_results(params, logger):
    # show what happened

    if params.blur_kernel_size is not None and params.blur_kernel_size >= 3:
        logger.draw(params.blurred, file='blurred')
    logger.draw(params.binary, file='binary')
    if params.box is not None:
        source_part = canvas.extract(params.source, params.box)
    else:
        source_part = params.source
    logger.draw(source_part, file='grayscale')

    colours = (const.OLIVE, const.GREEN, const.BLUE, const.YELLOW, const.PURPLE, const.CYAN, const.ORANGE, const.PINK)
    draw = canvas.colourize(source_part)
    for blob in params.blobs:
        for internal in blob.internal:
            for (x, y) in internal.points:
                draw[y, x] = const.RED
        colour = colours[random.randrange(0, len(colours))]
        for (x, y) in blob.external.points:
            draw[y, x] = colour
    logger.draw(draw, file='contours')

    logger.log('')
    logger.log("Detected contours: {}".format(len(params.blobs)))
    logger.log('  Red contours are internals, externals are shown in a random colour')

def set_params(src, proximity, black, inverted, blur, mode, params=None):
    if params is None:
        params = Params()
    params.source_file = src
    params.integration_width = proximity
    params.black_threshold = black
    params.inverted = inverted
    params.blur_kernel_size = blur
    params.mode = mode
    return params
*/
