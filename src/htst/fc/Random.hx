package htst.fc;

import seedyrng.Random as Rand;
import seedyrng.Xorshift64Plus;

/**
	Wrapper around rng (seedyrng) which generates random bits mostly.

	This makes that more useful by providing key types:
	- Int
	- Float
	- Bool
	- ...
**/
class Random {
	private static inline final MIN_INT = 0x80000000;
	private static inline final MAX_INT = 0x7fffffff;

	private var internalRng:Rand;
	
	/**
	 * Create a mutable random number generator
	 * @param internalRng Immutable random generator from pure-rand library
	 */
	public function new(internalRng:Rand) {
		this.internalRng = internalRng;
	}

	public static function createRandom(seed: Seed): Random {
		return new Random(new Rand(seed, new Xorshift64Plus()));
	}

	/**
	 * Clone the random number generator
	 */
	public function clone():Random {
		final newInternal = new Rand(this.internalRng.seed, new Xorshift64Plus());
		newInternal.state = this.internalRng.state;
		return new Random(newInternal);
	}

	public function skipN(n:UInt):Void {
		for (_ in 0...n) {
			this.internalRng.nextInt();
		}
	}

	/**
		Generate an integer having `bits` random bits
		@param bits Number of bits to generate
	**/
	public function nextBits(bits:OneTo32):Int {
		return switch (bits) {
			case ThirtyTwo: this.internalRng.nextFullInt();
			case(_ - 1) => 1 << _ => abs: this.internalRng.randomInt(abs * -1, abs - 1);
		}
	}

	/**
		Generate a random boolean
	**/
	public function nextBool():Bool {
		final num = this.internalRng.nextInt();
		// preturb MSB and LSB in case there is weakness then even test
		return ((num >>> 16) ^ num) & 1 == 0;
	}

	/**
		Generate a random integer (32 bits)
	**/
	public function nextInt():Int {
		return this.internalRng.nextInt();
	}

	/**
		Generate a random integer (32 bits) between min (included) and max (included)
		@param min Minimal integer value
		@param max Maximal integer value
	**/
	public function nextIntInRange(min:Int = Random.MIN_INT, max:Int = Random.MAX_INT):Int {
		return this.internalRng.randomInt(min, max);
	}

	/**
	 * Generate a random floating point number between 0.0 (included) and 1.0 (excluded)
	 */
	public function nextFloat():Float {
		return this.internalRng.random();
	}

	public function nextDoubleInRange(min:Float, max: Float): Float {
		final size = max - min;
        final r = if (!Math.isFinite(size) && Math.isFinite(min) && Math.isFinite(max)) {
            final r1 = nextFloat() * (max / 2 - min / 2);
            min + r1 + r1;
        } else {
            min + nextFloat() * size;
        }
        return if (r >= max) FloatTools.nextDown(max) else r;
	}
}

class FloatTools {
	public static function nextDown(f: Float): Float {
		return switch(f) {
			case Math.isNaN(_) || !Math.isFinite(_) => true: f;
			case 0.0: 5e-324; // assume IEEE Double
			case haxe.io.FPHelper.doubleToI64(_) => (f < 0 ? _ + 1 : _ - 1) => i:  haxe.io.FPHelper.i64ToDouble(i.high, i.low);
		}
	}
}

enum abstract OneTo32(Int) to Int {
	var One = 1;
	var Two;
	var Three;
	var Four;
	var Five;
	var Six;
	var Seven;
	var Eight;
	var Nine;
	var Ten;
	var Eleven;
	var Twelve;
	var Thirteen;
	var Fourteen;
	var Fifteen;
	var Sixteen;
	var Seventeen;
	var Eightteen;
	var Nineteen;
	var Twenty;
	var TwentyOne;
	var TwentyTwo;
	var TwentyThree;
	var TwentyFour;
	var TwentyFive;
	var TwentySix;
	var TwentySeven;
	var TwentyEight;
	var TwentyNine;
	var Thirty;
	var ThirtyOne;
	var ThirtyTwo;

	@:from
	public static function fromInt(v:Int):OneTo32 {
		if (v > 0 && v < 32)
			return cast v;
		else
			throw '${v} is out or range for OneTo32';
	}
}
