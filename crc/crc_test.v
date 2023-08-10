module crc

import logger
import consts
import arrays

fn test_bit_width() {
	if width_small := bit_width(0) {
		assert false, 'bit_width for 0 is ${width_small} when expect error'
	} else {
		// OK expect error
	}
	if width_big := bit_width(1 << 25) {
		assert false, 'bit_width for ${1 << 25} is ${width_big} when expect error'
	} else {
		// OK expect error
	}
	assert bit_width(1)! == 1
	assert bit_width(2)! == 2
	assert bit_width(4)! == 3
	assert bit_width(8)! == 4
	assert bit_width(16)! == 5
	assert bit_width(32)! == 6
	assert bit_width(64)! == 7
	assert bit_width(128)! == 8
	assert bit_width(256)! == 9
	assert bit_width(257)! == 9
	assert bit_width(1 << 23)! == 24
}

fn test_count_bits() {
	assert count_bits(0) == 0
	assert count_bits(1) == 1
	assert count_bits(0xFFFF) == 16
	assert count_bits(0x555555) == 12
}

// analyse_synonyms - diagnostic aid to verify synonym table is usable,
// returns a list of payloads for each distance and a list of codewords for each payload
fn analyse_synonyms(mut c Crc) ([][]int, [][]int) {
	mut distances := [][]int{len: c.code_bits + 1}
	mut payloads := [][]int{len: c.payload_range}
	for codeword, synonym in c.synonyms {
		payload, distance := c.unmake_synonym(synonym)
		if payload == 0 {
			// these are not valid
			continue
		}
		distances[distance] << payload
		payloads[payload] << codeword
	}
	return distances, payloads
}

[params]
struct FindBestPolyParams {
	poly_bits    int            [required]
	payload_bits int            [required]
	logger       &logger.Logger
}

struct Poly {
	poly     int
	distance int
}

// find_best_poly - find best CRC polynomial (by doing an exhaustive search of all possible polynomials),
// returns a list of the best polynomials and their Hamming distance
fn find_best_poly(p FindBestPolyParams) ![]Poly {
	poly_bits := p.poly_bits
	poly_max := 1 << poly_bits
	poly_msb := poly_max >> 1
	payload_bits := p.payload_bits
	mut log := p.logger
	log.log('Searching for best ${poly_bits}-bit polynomial in range ' +
		'${poly_msb}..${poly_max} for a ${payload_bits}-bit payload (this may take some time!):...')!
	mut best_distance := 0
	mut best_poly := -1
	mut candidates := []Poly{}
	for poly in poly_msb .. poly_max {
		mut codec := new_crc(payload_bits: payload_bits, poly: poly)!
		distance, _ := codec.build_codewords_table()!
		if distance > best_distance {
			// got a new best
			best_distance = distance
			best_poly = poly
			candidates = [Poly{best_poly, best_distance}]
			log.log('  new best so far: [(${poly},${best_distance})]')!
		} else if distance == best_distance {
			// got another just as good
			candidates << Poly{poly, distance}
			msg := arrays.fold[Poly, string](candidates, '', fn (acc string, elem Poly) string {
				return acc + ',(${elem.poly},${elem.distance})'
			})
			log.log('  another at same best so far: [${msg.all_after_first(',')}]')!
		}
	}
	msg := arrays.fold[Poly, string](candidates, '', fn (acc string, elem Poly) string {
		return acc + ',(${elem.poly},${elem.distance})'
	})
	log.log('  best overall: [${msg.all_after_first(',')}]')!

	return candidates
}

struct Err {
mut:
	correct int
	total   int
}

// test_crc - test harness (this is not in V style - its a translation of the Python version)
fn test_crc() {
	mut log := logger.new_logger(file: 'crc.log')!
	log.log('CRC test harness')!
	payload_bits := consts.payload_bits
	payload_range := consts.payload_range
	// find best CRC polynomial (by doing an exhaustive search of all poly-bit polynomials)
	// best_candidates := find_best_poly(poly_bits: consts.poly_bits, payload_bits: payload_bits, logger: log)!
	// polynomial := best_candidates[0].poly
	polynomial := consts.polynomial

	mut codec := new_crc(payload_bits: payload_bits, poly: polynomial, logger: log)!
	log.log('CRC spec: payload bits: ${payload_bits}, crc bits: ${codec.crc_bits}, ' +
		'polynomial: ${polynomial:b}, payload range: 1..${payload_range - 1}, ' +
		'code range 0..${codec.code_range - 1}')!
	codec.build_synonyms_table()!
	distances, payloads := analyse_synonyms(mut codec)
	log.log('Analysis:')!
	for distance, synonyms in distances {
		if synonyms.len == 0 {
			// nothing here
			continue
		}
		log.log('  distance:${distance} payloads=${synonyms.len}')!
	}
	mut min_synonyms := codec.code_range + 1
	mut max_synonyms := 0
	mut avg_synonyms := 0
	mut samples := 0
	for payload, synonyms in payloads {
		if payload == 0 {
			// not allowed
			continue
		}
		if synonyms.len == 0 {
			// nothing here
			continue
		}
		avg_synonyms += synonyms.len
		samples += 1
		if synonyms.len < min_synonyms {
			min_synonyms = synonyms.len
		}
		if synonyms.len > max_synonyms {
			max_synonyms = synonyms.len
		}
	}
	avg_synonyms /= samples
	log.log('  synonyms: min=${min_synonyms}, max=${max_synonyms}, average=${avg_synonyms}')!
	log.log('Detection: all payloads for zero error case:')!
	mut passes := []int{}
	mut fails := []int{}
	mut encoded := []int{len: payload_range}
	for code in 1 .. payload_range {
		encoded[code] = codec.encode(code)!
		decoded, errors := codec.decode(encoded[code])!
		if errors == 0 && decoded == code {
			passes << code
		} else {
			fails << encoded
		}
	}
	log.log('  passes: ${passes.len}')!
	log.log('  fails: ${fails.len}')!
	if fails.len == 0 {
		log.log('  all codes pass encode->decode')!
	} else {
		log.log('  encode->decode not symmetrical - find out what went wrong!')!
	}
	log.log('Detection: All codeword cases:')!
	mut passes2 := 0
	mut fails2 := 0
	mut good := map[int]int{}
	for code in 1 .. codec.code_range {
		decoded, errors := codec.decode(code)!
		if decoded > 0 && errors == 0 {
			passes2 += 1
			good[decoded] += 1
		} else {
			fails2 += 1
		}
	}
	log.log('  passes: ${passes2}')!
	log.log('  fails: ${fails2}')!
	if good.len == (payload_range - 1) {
		log.log('  all, and only, expected codes detected (${good.len})')!
	} else {
		log.log('  got ${good.len} unique codes when expecting ${payload_range - 1} - find out why')!
	}
	log.log('Error recovery for every possible code word: ${codec.code_range - 1}')!
	mut passes3 := 0
	mut fails3 := 0
	for code in 1 .. codec.code_range {
		payload, _ := codec.decode(code)!
		if payload == 0 {
			fails3 += 1
		} else {
			passes3 += 1
		}
	}
	total := passes3 + fails3
	log.log('  passes: ${passes3} (${ratio(passes3, total)}%), fails: ${fails3} (${ratio(fails3,
		total)}%)')!
	log.log('Error recovery for every possible N-bit flip for every possible codeword: 1..${codec.error_bits} bit flips in ${codec.code_bits} code-bits')!
	mut errs := []Err{len: codec.error_bits + 1} // correct, total for each N
	for payload in 1 .. payload_range { // every possible payload
		code := codec.encode(payload)!
		for n in 1 .. errs.len {
			for err in codec.flips(n: n)! {
				bad_code := code ^ err // flip N bits
				decode, _ := codec.decode(bad_code)!
				if decode == payload {
					// correct
					errs[n].correct += 1
				}
				errs[n].total += 1
			}
		}
	}
	for n, err in errs {
		all := err.total
		ok := err.correct
		if all == 0 {
			// nothing here
			continue
		}
		bad := all - ok
		log.log('  ${n}-bit flips: ${ok} good (${ratio(ok, all)}%), ${bad} bad (${ratio(bad,
			all)}%)')!
	}
	log.log('Done')!
	log.close()
}

// ratio - determine the ratio a/b as a percentage 0..100
fn ratio(a int, b int) int {
	return int(f64(a) / f64(b) * 100.0)
}
