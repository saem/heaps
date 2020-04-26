package htst.rand;

import htst.rand.Generator.Result;
import htst.rand.Generator.RandomGenerator;

class Distribution {
	public final from:Int;
	public final to:Int;

	public inline function new(from, to) {
    this.from = from;
    this.to = to;
	}

	public inline function result(rng:RandomGenerator):Result {
    	final diff = to - from + 1;
		return uniformIntInternal(from, diff, rng);
	}

	public static function uniformIntDistribution(from:Int, to:Int): Distribution {
		return new Distribution(from, to);
	}

	public static function uniformInt(from:Int, to:Int, rng:RandomGenerator):Result {
		final diff = to - from + 1;
		return uniformIntInternal(from, diff, rng);
	}

	static function uniformIntInternal(from:Int, diff:Int, rng:RandomGenerator):Result {
		final MinRng = rng.min();
		final NumValues = rng.max() - rng.min() + 1;

		// Range provided by the RandomGenerator is large enough
		if (diff <= NumValues) {
			var nrng = rng;
			final MaxAllowed = NumValues - (NumValues % diff);
			while (true) {
				final out = nrng.next();
				final deltaV = out.result - MinRng;
				nrng = out.generator;
				if (deltaV < MaxAllowed) {
					return new Result((deltaV % diff) + from, nrng);
				}
			}
		}

		// Compute number of iterations required to have enough random
		// to build uniform entries in the asked range
		var FinalNumValues = 1;
		var NumIterations = 0;
		while (FinalNumValues < diff) {
			FinalNumValues *= NumValues;
			++NumIterations;
		}
		final MaxAcceptedRandom = diff * Math.floor((1 * FinalNumValues) / diff);

		var nrng = rng;
		while (true) {
			// Aggregate mutiple calls to next() into a single random value
			var value = 0;
			for (_ in 0...NumIterations) {
				final out = nrng.next();
				value = NumValues * value + (out.result - MinRng);
				nrng = out.generator;
			}
			if (value < MaxAcceptedRandom) {
				final inDiff = value - diff * Math.floor((1 * value) / diff);
				return new Result(inDiff + from, nrng);
			}
		}
	}
}
