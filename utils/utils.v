module utils

import logger
import canvas

[params]
struct PrepareParams {
	src    string
	width  int
	logger ?&logger.Logger
}

// prepare - load and downsize an image
pub fn prepare(p PrepareParams) !canvas.Buffer {
	if mut log_fn := p.logger {
		log_fn.log('Preparing image to width ${p.width} from ${p.src}')!
	}
	// load the image
	source := canvas.load(p.src) or {
		if mut log_fn := p.logger {
			log_fn.log('Cannot load ${p.src}')!
		}
		return error('Cannot load ${p.src}')
	}
	// downsize it (to simulate low quality smartphone cameras)
	downsized := source.downsize(p.width)!
	if mut log_fn := p.logger {
		log_fn.log('Original size ${source.size()} reduced to ${downsized.size()}')!
		log_fn.draw(image: downsized, file: 'downsized')!
	}
	return downsized
}
