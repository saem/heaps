package htst.rand;

/**
 * All generators were ported from: https://github.com/dubzzz/pure-rand/tree/master/src/generator
 * 
 * This relies on JavaScript semantics in terms of bitwise and other operations.
 */
class Generator {
	public static function generateN(rng:RandomGenerator, size:Int):Results {
		var cur:RandomGenerator = rng;
		final out = new Array<Int>();
		out.resize(size);

		for (idx in 0...size) {
			final nextOut = cur.next();
			out[idx] = nextOut.result;
			cur = nextOut.generator;
		}
		return new Results(out, cur);
	}

	public static function skipN(rng:RandomGenerator, num:Int):RandomGenerator {
		return generateN(rng, num).generator;
	}

	public static function congruential(seed:Int):RandomGenerator {
		return new LinearCongruential(seed);
	}

	public static function congruential32(seed:Int):RandomGenerator {
		return new LinearCongruential32(seed);
	}

	public static function xoroshiro128plus(seed:Int):RandomGenerator {
		return new XoroShiro128Plus(-1, ~seed, seed | 0, 0);
	}

	public static function xorshift128plus(seed:Int):RandomGenerator {
		return new XorShift128Plus(-1, ~seed, seed | 0, 0);
	}

	public static function mersenneTwister(seed:Int):RandomGenerator {
		return MersenneTwister.from(seed);
	}
}

interface RandomGenerator {
	function next():Result;
	// function jump():RandomGenerator;
	function min():Int; // Inclusive
	function max():Int; // Inclusive
}

class Result {
	public final result:Int;
	public final generator:RandomGenerator;

	public inline function new(result, generator) {
		this.result = result;
		this.generator = generator;
	}
}

class Results {
	public final result:Array<Int>;
	public final generator:RandomGenerator;

	public inline function new(result, generator) {
		this.result = result;
		this.generator = generator;
	}
}

class LinearCongruential implements RandomGenerator {
	// Inspired from java.util.Random implementation
	// http://grepcode.com/file/repository.grepcode.com/java/root/jdk/openjdk/6-b14/java/util/Random.java#Random.next%28int%29
	// Updated with values from: https://en.wikipedia.org/wiki/Linear_congruential_generator
	public static final MULTIPLIER:Int = 0x000343fd;
	public static final INCREMENT:Int = 0x00269ec3;
	public static final MASK:Int = 0xffffffff;
	public static final MASK_2:Int = (1 << 31) - 1;

	public static function computeNextSeed(seed:Int) {
		return (seed * MULTIPLIER + INCREMENT) & MASK;
	};

	public static function computeValueFromNextSeed(nextseed:Int) {
		return (nextseed & MASK_2) >> 16;
	};

	// Should produce exactly the same values
	// as the following C++ code compiled with Visual Studio:
	//  * constructor = srand(seed);
	//  * next        = rand();
	public static final MIN:Int = 0;
	public static final MAX:Int = Std.int(Math.pow(2, 15)) - 1;

	public final seed:Int;

	public function new(seed:Int) {
		this.seed = seed;
	}

	public function min():Int {
		return LinearCongruential.MIN;
	}

	public function max():Int {
		return LinearCongruential.MAX;
	}

	public function next():Result {
		final nextseed = computeNextSeed(this.seed);
		return new Result(computeValueFromNextSeed(nextseed), new LinearCongruential(nextseed));
	}
}

class LinearCongruential32 implements RandomGenerator {
	public static final MIN:Int = 0;
	public static final MAX:Int = 0xffffffff;

	public final seed:Int;

	public function new(seed:Int) {
		this.seed = seed;
	}

	public function min():Int {
		return LinearCongruential32.MIN;
	}

	public function max():Int {
		return LinearCongruential32.MAX;
	}

	public function next():Result {
		final s1 = LinearCongruential.computeNextSeed(this.seed);
		final v1 = LinearCongruential.computeValueFromNextSeed(s1);
		final s2 = LinearCongruential.computeNextSeed(s1);
		final v2 = LinearCongruential.computeValueFromNextSeed(s2);
		final s3 = LinearCongruential.computeNextSeed(s2);
		final v3 = LinearCongruential.computeValueFromNextSeed(s3);

		// value between: -0x80000000 and 0x7fffffff
		// in theory it should have been: v1 & 3 instead of v1 alone
		// but as binary operations truncate between -0x80000000 and 0x7fffffff in JavaScript
		// we can get rid of this operation
		final vnext = v3 + ((v2 + (v1 << 15)) << 15);
		return new Result(((vnext + 0x80000000) | 0) + 0x80000000, new LinearCongruential32(s3));
	}
}

class MersenneTwister implements RandomGenerator {
	static final MIN:Int = 0;
	static final MAX:Int = 0xffffffff;

	static final N = 624;
	static final M = 397;
	static final R = 31;
	static final A = 0x9908b0df;
	static final F = 1812433253;
	static final U = 11;
	static final S = 7;
	static final B = 0x9d2c5680;
	static final T = 15;
	static final C = 0xefc60000;
	static final L = 18;
	static final MASK_LOWER = Std.int(Math.pow(2, MersenneTwister.R)) - 1;
	static final MASK_UPPER = Std.int(Math.pow(2, MersenneTwister.R));

	private static function twist(prev:Array<Int>):Array<Int> {
		final mt = prev.slice(0);
		for (idx in 0...(MersenneTwister.N - MersenneTwister.M)) {
			final y = (mt[idx] & MersenneTwister.MASK_UPPER) + (mt[idx + 1] & MersenneTwister.MASK_LOWER);
			mt[idx] = mt[idx + MersenneTwister.M] ^ (y >>> 1) ^ (-(y & 1) & MersenneTwister.A);
		}
		for (idx in (MersenneTwister.N - MersenneTwister.M)...(MersenneTwister.N - 1)) {
			final y = (mt[idx] & MersenneTwister.MASK_UPPER) + (mt[idx + 1] & MersenneTwister.MASK_LOWER);
			mt[idx] = mt[idx + MersenneTwister.M - MersenneTwister.N] ^ (y >>> 1) ^ (-(y & 1) & MersenneTwister.A);
		}
		final y = (mt[MersenneTwister.N - 1] & MersenneTwister.MASK_UPPER) + (mt[0] & MersenneTwister.MASK_LOWER);
		mt[MersenneTwister.N - 1] = mt[MersenneTwister.M - 1] ^ (y >>> 1) ^ (-(y & 1) & MersenneTwister.A);
		return mt;
	}

	private static function seeded(seed:Int):Array<Int> {
		final out = new Array();
		out.resize(MersenneTwister.N);
		out[0] = seed;
		for (idx in 1...(MersenneTwister.N - 1)) {
			final xored = out[idx - 1] ^ (out[idx - 1] >>> 30);
			out[idx] = (product32bits(MersenneTwister.F, xored) + idx) | 0;
		}
		return out;
	}

	final index:Int;
	final states:Array<Int>; // between -0x80000000 and 0x7fffffff

	private function new(states:Array<Int>, index:Int) {
		if (index >= MersenneTwister.N) {
			this.states = MersenneTwister.twist(states);
			this.index = 0;
		} else {
			this.states = states;
			this.index = index;
		}
	}

	public static function from(seed:Int):MersenneTwister {
		return new MersenneTwister(MersenneTwister.seeded(seed), MersenneTwister.N);
	}

	public function min():Int {
		return MersenneTwister.MIN;
	}

	public function max():Int {
		return MersenneTwister.MAX;
	}

	public function next():Result {
		var y = this.states[this.index];
		y ^= this.states[this.index] >>> MersenneTwister.U;
		y ^= (y << MersenneTwister.S) & MersenneTwister.B;
		y ^= (y << MersenneTwister.T) & MersenneTwister.C;
		y ^= y >>> MersenneTwister.L;
		return new Result(y >>> 0, new MersenneTwister(this.states, this.index + 1));
	}

	static function product32bits(a:Int, b:Int) {
		final alo = a & 0xffff;
		final ahi = (a >>> 16) & 0xffff;
		final blo = b & 0xffff;
		final bhi = (b >>> 16) & 0xffff;
		return alo * blo + ((alo * bhi + ahi * blo) << 16);
	}
}

/**
 * XoroShiro128+ with a=24, b=16, c=37,
 * - https://en.wikipedia.org/wiki/Xoroshiro128%2B
 * - http://prng.di.unimi.it/xoroshiro128plus.c
 */
class XoroShiro128Plus implements RandomGenerator {
	final s01:Int;
	final s00:Int;
	final s11:Int;
	final s10:Int;

	public function new(s01:Int, s00:Int, s11:Int, s10:Int) {
		this.s01 = s01;
		this.s00 = s00;
		this.s11 = s11;
		this.s10 = s10;
	}

	public function min():Int {
		return -0x80000000;
	}

	public function max():Int {
		return 0x7fffffff;
	}

	public function next():Result {
		// a = s0[n] ^ s1[n]
		final a0 = this.s10 ^ this.s00;
		final a1 = this.s11 ^ this.s01;
		// s0[n+1] = rotl(s0[n], 24) ^ a ^ (a << 16)
		final ns00 = (this.s00 << 24) ^ (this.s01 >>> 8) ^ a0 ^ (a0 << 16);
		final ns01 = (this.s01 << 24) ^ (this.s00 >>> 8) ^ a1 ^ ((a1 << 16) | (a0 >>> 16));
		// s1[n+1] = rotl(a, 37)
		final ns10 = (a1 << 5) ^ (a0 >>> 27);
		final ns11 = (a0 << 5) ^ (a1 >>> 27);
		return new Result((this.s00 + this.s10) | 0, new XoroShiro128Plus(ns01, ns00, ns11, ns10));
	}

	public function jump():XoroShiro128Plus {
		// equivalent to 2^64 calls to next()
		// can be used to generate 2^64 non-overlapping subsequences
		var rngRunner:XoroShiro128Plus = this;
		var ns01 = 0;
		var ns00 = 0;
		var ns11 = 0;
		var ns10 = 0;
		final jump = [0xd8f554a5, 0xdf900294, 0x4b3201fc, 0x170865df];
		for (i in 0...3) {
			var mask = 1;
			while (mask != 0) {
			  // Because: (1 << 31) << 1 === 0
			  if (jump[i] & mask != 0) {
				ns01 ^= rngRunner.s01;
				ns00 ^= rngRunner.s00;
				ns11 ^= rngRunner.s11;
				ns10 ^= rngRunner.s10;
			  }
			  rngRunner = cast rngRunner.next().generator;
			  mask <<= 1;
			}
		  }
		return new XoroShiro128Plus(ns01, ns00, ns11, ns10);
	}
}


/**
 * XorShift128+ with a=23, b=18, c=5
 * - http://vigna.di.unimi.it/ftp/papers/xorshiftplus.pdf
 * - http://vigna.di.unimi.it/xorshift/xorshift128plus.c
 * - https://docs.rs/crate/xorshift/0.1.3/source/src/xorshift128.rs
 * 
 * NOTE: Math.random() of V8 uses XorShift128+ with a=23, b=17, c=26,
 * 	See https://github.com/v8/v8/blob/4b9b23521e6fd42373ebbcb20ebe03bf445494f9/src/base/utils/random-number-generator.h#L119-L128
 */
class XorShift128Plus implements RandomGenerator {
	final s01:Int;
	final s00:Int;
	final s11:Int;
	final s10:Int;

	public function new(s01:Int, s00:Int, s11:Int, s10:Int) {
		this.s01 = s01;
		this.s00 = s00;
		this.s11 = s11;
		this.s10 = s10;
	}

	public function min():Int {
		return -0x80000000;
	}

	public function max():Int {
		return 0x7fffffff;
	}

	public function next():Result {
		final a0 = this.s00 ^ (this.s00 << 23);
		final a1 = this.s01 ^ ((this.s01 << 23) | (this.s00 >>> 9));
		final b0 = a0 ^ this.s10 ^ ((a0 >>> 18) | (a1 << 14)) ^ ((this.s10 >>> 5) | (this.s11 << 27));
		final b1 = a1 ^ this.s11 ^ (a1 >>> 18) ^ (this.s11 >>> 5);
		return new Result((this.s00 + this.s10) | 0, new XorShift128Plus(this.s11, this.s10, b1, b0));
	}

	public function jump():XorShift128Plus {
		// equivalent to 2^64 calls to next()
		// can be used to generate 2^64 non-overlapping subsequences
		var rngRunner:XorShift128Plus = this;
		var ns01 = 0;
		var ns00 = 0;
		var ns11 = 0;
		var ns10 = 0;
		final jump = [0x635d2dff, 0x8a5cd789, 0x5c472f96, 0x121fd215];
		for (i in 0...3) {
			var mask = 1;
			while (mask != 0) {
				// Because: (1 << 31) << 1 === 0
				if (jump[i] & mask != 0) {
					ns01 ^= rngRunner.s01;
					ns00 ^= rngRunner.s00;
					ns11 ^= rngRunner.s11;
					ns10 ^= rngRunner.s10;
				}
				rngRunner = cast rngRunner.next().generator;
				mask <<= 1;
			}
		}
		return new XorShift128Plus(ns01, ns00, ns11, ns10);
	}
}