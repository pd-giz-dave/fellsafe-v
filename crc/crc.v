// History:
// 12/06/23 DCN: Created by copying and re-implementing the crc.py module from the kilo-codes Python prototype

// CRC coding/decoding functions
// See https://en.wikipedia.org/wiki/Cyclic_redundancy_check for the encoding algorithm.
// The functions here are only suitable for single integer based payloads and CRC's (i.e. up 32 bits).

module crc

// crc module constructs and de-constructs codewords based on a Crc with error correction
import rand
import consts
import logger
import math

// bit_width - get the minimum number of bits required to hold the given value (min is at least 1)
fn bit_width(val int) !int {
	if val > ((1 << 24) - 1) || val < 1 {
		return error('only positive 24 bit numbers allowed, not ${val}')
	}
	mut mask := val
	mut k := 0
	if mask > 0x0000FFFF {
		mask >>= 16
		k = 16
	}
	if mask > 0x000000FF {
		mask >>= 8
		k |= 8
	}
	if mask > 0x0000000F {
		mask >>= 4
		k |= 4
	}
	if mask > 0x00000003 {
		mask >>= 2
		k |= 2
	}
	k |= (mask & 2) >> 1
	return k + 1
}

// count_bits - count number of 1 bits in the given mask
fn count_bits(mask int) int {
	// there are probably faster more 'clever' ways of doing this, but its not a critical function, so who cares?
	mut bits := 0
	mut residue := mask
	for residue != 0 {
		if residue & 1 == 1 {
			bits += 1
		}
		residue >>= 1
	}
	return bits
}

// Synonym is the payload and error bits decoded from a codeword
struct Synonym {
mut:
	payload int
	errors  int
}

// Codeword is the code and its minimum (hamming) distance to any other code
struct Codeword {
mut:
	code     int
	distance int
}

// Crc holds the parameters for the polynomial and the lookup tables for constructing/de-constructing codewords
struct Crc {
	max_payload_bits int = 15 // limits max lookup table size, but is otherwise arbitrary
	max_poly_bits    int = 15 // ..
	payload_bits     int // parameter
	poly             int // parameter - the polynomial to use
	logger           ?&logger.Logger // parameter - iff not 'none' a logging function
mut:
	poly_bits        int // number of bits in poly
	crc_bits         int // one less than poly_bits (MS poly_bits is always 1)
	crc_mask         int // AND a code word with this to isolate its CRC
	payload_range    int // derived from payload_bits
	payload_mask     int // AND synonym with this to isolate its payload
	code_bits        int // total bits in the code
	code_range       int // max code value (payload + crc)
	unique           int // number if unique synonyms in synonyms lookup table
	hamming_distance int // the Hamming distance of the polynomial
	error_bits       int // max error correction capability (==(hamming_distance-1)/2
	// these are constant and lazily evaluated, an array length of 0 indicates they have not been evaluated yet
	synonyms  []int      // codeword lookup table for every synonym (its huge)
	masks     [][]int    // list of bit flip masks for every N bits in the code range (lazy evaluation)
	codewords []Codeword // list of all codewords (CRCs) for every payload
}

[params]
struct NewCrcParams {
	payload_bits int
	poly         int
	logger       ?&logger.Logger
}

// new_crc - create a Crc object, save and validate the spec
fn new_crc(p NewCrcParams) !Crc {
	mut crc := Crc{
		payload_bits: p.payload_bits
		poly: p.poly
		logger: p.logger
	}
	// crc.logger = p.logger
	// crc.payload_bits = p.payload_bits
	// crc.poly = p.poly
	crc.poly_bits = bit_width(crc.poly)!
	crc.crc_bits = crc.poly_bits - 1
	if crc.payload_bits > crc.max_payload_bits {
		return error('max payload bits is ${crc.max_payload_bits}, given ${crc.payload_bits}')
	}
	if crc.poly_bits > crc.max_poly_bits {
		return error('max polynomial bits is ${crc.max_poly_bits}, given polynomial (${crc.poly:b}) has ${crc.poly_bits}')
	}
	crc.crc_mask = (1 << crc.crc_bits) - 1 // AND a code word with this to isolate its CRC
	crc.payload_range = (1 << crc.payload_bits)
	crc.payload_mask = crc.payload_range - 1 // AND synonym with this to isolate its payload
	crc.code_bits = crc.payload_bits + crc.crc_bits // total bits in the code
	crc.code_range = 1 << crc.code_bits // max code value (payload + crc)
	return crc
}

// wrappers around logging functions 'cos I can't work out how to deal with an optional function

// logging - test if we have a logger, returns true iff we have got one
[inline]
fn (mut c Crc) logging() bool {
	if _ := c.logger {
		return true
	}
	return false
}

fn (mut c Crc) log(msg string) ! {
	if mut log_fn := c.logger {
		log_fn.log(msg)!
	}
}

fn (mut c Crc) push(p logger.Context) ! {
	if mut log_fn := c.logger {
		log_fn.push(p)!
	}
}

fn (mut c Crc) pop() ! {
	if mut log_fn := c.logger {
		log_fn.pop()!
	}
}

// prepare - initialise lookup tables (preempts what encode and decode would do)
fn (mut c Crc) prepare() ! {
	test_code := rand.int_in_range(1, c.payload_range)!
	codeword := c.encode(test_code)!
	result, err := c.decode(codeword)!
	if result != test_code {
		return error('Encode of ${test_code} decoded as ${result} when should be ${Synonym{test_code, 0}}')
	}
	if err != 0 {
		return error('Encode of ${test_code} decoded with error ${err} when should be 0')
	}
}

// code - create the full code from the given parts
fn (c Crc) code(payload int, syndrome int) int {
	return (payload << c.crc_bits) | (syndrome & c.crc_mask)
}

// uncode - undo what code did, de-construct a codeword into its payload and syndrome
fn (c Crc) uncode(codeword int) (int, int) {
	return codeword >> c.crc_bits, codeword & c.crc_mask
}

// encode - return the CRC encoded code word for the given value
pub fn (mut c Crc) encode(payload int) !int {
	if c.codewords.len == 0 {
		// we have not calculated all the codewords yet, do it now
		c.build_codewords_table()!
	}
	return c.codewords[payload].code
}

// unencode - decode the code word into its value and its syndrome for the code
// this is the slow version of decode() (which uses a lookup table)
fn (c Crc) unencode(codeword int) !(int, int) {
	payload, syndrome := c.uncode(codeword)
	return payload, c.calculate(val: payload, pad: syndrome)!
}

[params]
struct CalculateParams {
	val int [required] // the value to be encoded as a Crc
	pad int // iff given, use this initial syndrome, else 0
}

// calculate the CRC for the given value and pad
fn (c Crc) calculate(p CalculateParams) !int {
	if p.val >= (1 << c.payload_bits) {
		return error('${p.val} is beyond the range of payload bits ${c.payload_bits}')
	}
	if (p.val + p.pad) < 1 {
		return error('value+pad must be positive, not ${p.val}+${p.pad}')
	}
	mut crc := c.code(p.val, p.pad)
	for crc > 0 {
		poly_ms_shift := bit_width(crc)! - c.poly_bits
		if poly_ms_shift < 0 {
			break
		}
		poly := c.poly << poly_ms_shift // put poly in MS position
		crc ^= poly
	}
	return crc & c.crc_mask
}

// decode given codeword with error correction by a lookup table (so fast),
// returns the payload and the number of bit errors
pub fn (mut c Crc) decode(codeword int) !(int, int) {
	if c.synonyms.len == 0 {
		// not built the synonym table yet, do it now
		c.build_synonyms_table()!
	}
	synonym := c.synonyms[codeword]
	return c.unmake_synonym(synonym)
}

// make_synonym - make a synonym from its parts, a synonym is a code value and its distance
fn (c Crc) make_synonym(payload int, distance int) int {
	return (distance << c.payload_bits) | payload
}

// unmake_synonym - undo what make_synonym did
fn (c Crc) unmake_synonym(synonym int) (int, int) {
	payload := synonym & c.payload_mask
	distance := synonym >> c.payload_bits
	return payload, distance
}

[params]
struct FlipsParams {
	n int
}

// flips - return a list of all possible bit flips of N bits within code-bits
fn (mut c Crc) flips(p FlipsParams) ![]int {
	if p.n > c.code_bits {
		return error('flips limit is ${c.code_bits}, cannot do ${p.n}')
	}
	if c.masks.len == 0 {
		// not built masks table yet, do it now
		c.log('Build bit flip mask table for ${c.code_bits} code-bits...')!
		c.masks = [][]int{len: c.code_bits + 1}
		for bits in 0 .. c.code_range {
			count := count_bits(bits)
			c.masks[count] << bits
		}
		if c.logging() {
			mut total := 0
			for count in 1 .. c.masks.len {
				c.log('  N:${count}=${c.masks[count].len} flips')!
				total += c.masks[count].len
			}
			c.log('  total possible flips: ${total}')!
		}
	}
	return c.masks[p.n]
}

// build_codewords_table - build the codewords for each payload and their minimum Hamming distance
// between each codeword and every other codeword,
// returns the Hamming distance and error correction bits
fn (mut c Crc) build_codewords_table() !(int, int) {
	if c.codewords.len == 0 {
		// not built codewords table yet, do it now
		if c.logging() {
			c.push(context: 'crc')!
			c.log('Build codewords table for polynomial ${c.poly:b}:...')!
		}
		c.codewords = []Codeword{len: c.payload_range} // make full size
		c.codewords[0].code = 0 // illegal code for 0
		c.codewords[0].distance = c.code_bits + 1 // set to huge distance so 0 is never used
		// build initial code table
		for payload in 1 .. c.payload_range { // NB: start at 1 'cos 0 is illegal
			c.codewords[payload].code = c.code(payload, c.calculate(val: payload)!) // NB: do NOT use encode() here!
			c.codewords[payload].distance = c.code_bits + 1 // init to huge distance
		}
		// find min distance for each codeword
		// NB: this is a slow O(N^2) loop, but its only run once so we don't care
		for ref_payload in 1 .. c.payload_range {
			for payload in 1 .. c.payload_range {
				if payload == ref_payload {
					// ignore self
					continue
				}
				ref_codeword := c.codewords[ref_payload].code
				codeword := c.codewords[payload].code
				distance := count_bits(ref_codeword ^ codeword)
				if distance < c.codewords[ref_payload].distance {
					// found a closer code
					c.codewords[ref_payload].distance = distance
				}
			}
		}
		// find overall minimum Hamming distance
		c.hamming_distance = c.code_bits + 1 // initially set very big minimum
		for codeword in c.codewords {
			if codeword.distance < c.hamming_distance {
				c.hamming_distance = codeword.distance
			}
		}
		c.error_bits = math.max((c.hamming_distance - 1) >> 1, 0)
		if c.logging() {
			c.log('  hamming distance is ${c.hamming_distance}, max error-bits is ${c.error_bits}')!
			c.pop()!
		}
	}
	return c.hamming_distance, c.error_bits
}

// build_synonyms_table - build a lookup table for every possible codeword with its decoded value and its distance,
// the 'distance' is how far from correct the synonym is (i.e. its error bits),
// a synonym of 0 indicates an invalid code word,
// returns the number of unique synonyms
fn (mut c Crc) build_synonyms_table() !int {
	if c.synonyms.len == 0 {
		// not built yet, build it now
		if c.logging() {
			c.push(context: 'crc')!
			c.log('Build synonyms table (this may take some time!)...')!
		}
		// make all possible codewords (and their distances)
		c.build_codewords_table()!
		// make all possible bit flips
		c.flips()!
		// make all possible synonyms
		mut possible := 0
		mut synonyms := [][]int{len: c.code_range}
		for payload in 1 .. c.payload_range {
			codeword := c.codewords[payload]
			n_limit := (codeword.distance - 1) >> 1
			for n in 0 .. c.masks.len {
				if n > n_limit {
					// too far for this payload
					break
				}
				for mask in c.masks[n] {
					synonym := codeword.code ^ mask
					if synonym == 0 {
						// not allowed
						continue
					}
					synonyms[synonym] << c.make_synonym(payload, n)
					possible += 1
				}
			}
		}
		if c.logging() {
			c.log('  all possible synonyms = ${possible}')!
		}
		// build unique synonym table
		c.unique = 0
		c.synonyms = []int{len: c.code_range} // set all invalid initially (==0)
		for codeword, candidates in synonyms {
			if candidates.len == 0 {
				// this one is illegal (NB: codeword 0 is guaranteed to be invalid)
				continue
			} else if candidates.len == 1 {
				// no ambiguity here, so keep it
				c.synonyms[codeword] = candidates[0]
				c.unique += 1
			} else {
				// got ambiguity, keep lowest distance if its unique
				mut best_candidate := -1
				for candidate, synonym in candidates {
					if best_candidate < 0 {
						best_candidate = candidate
						continue
					}
					_, best_distance := c.unmake_synonym(candidates[best_candidate])
					_, distance := c.unmake_synonym(synonym)
					if distance < best_distance {
						// found a better candidate
						best_candidate = candidate
					} else if distance == best_distance {
						// ambiguous, do not use this candidate
						best_candidate = -1
					}
				}
				if best_candidate == -1 {
					// nothing suitable here
					continue
				}
				// keep the best choice we found
				c.synonyms[codeword] = candidates[best_candidate]
				c.unique += 1
			}
		}
		if c.logging() {
			c.log('  unique synonyms = ${c.unique}')!
			c.pop()!
		}
	}
	return c.unique
}

[params]
pub struct MakeCodecParams {
	payload_bits int = consts.payload_bits
	polynomial   int = consts.polynomial
	logger       ?&logger.Logger
}

// make_codec - make a codec for encoding/decoding bits
pub fn make_codec(p MakeCodecParams) !Crc {
	if mut log_fn := p.logger {
		log_fn.log('Preparing codec...')!
	}
	mut codec := new_crc(
		payload_bits: p.payload_bits
		poly: p.polynomial
		logger: p.logger
	)!
	codec.prepare()!
	return codec
}
