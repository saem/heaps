package htst.fc;

import htst.rand.Generator.RandomGenerator;
import htst.rand.Distribution;

class Random {
    private static inline final MIN_INT: Int = 0x80000000 | 0;
    private static inline final MAX_INT: Int = 0x7fffffff | 0;
    private static final DBL_FACTOR: Float = Math.pow(2, 27);
    private static final DBL_DIVISOR: Float = Math.pow(2, -53);
  
    private var internalRng: RandomGenerator;
    /**
     * Create a mutable random number generator
     * @param internalRng Immutable random generator from pure-rand library
     */
    public function new(internalRng: RandomGenerator) {
        this.internalRng = internalRng;
    }
  
    /**
     * Clone the random number generator
     */
    public function clone(): Random {
      return new Random(this.internalRng);
    }
  
    private function uniformIn(rangeMin: Int, rangeMax: Int): Int {
      final g = Distribution.uniformInt(rangeMin, rangeMax, this.internalRng);
      this.internalRng = g.generator;
      return g.result;
    }
  
    /**
     * Generate an integer having `bits` random bits
     * @param bits Number of bits to generate
     */
    public function next(bits: Int): Int {
      return this.uniformIn(0, (1 << bits) - 1);
    }
  
    /**
     * Generate a random boolean
     */
  
     public function nextBoolean(): Bool {
      return this.uniformIn(0, 1) == 1;
    }
  
    /**
     * Generate a random integer (32 bits) between min (included) and max (included)
     * @param min Minimal integer value
     * @param max Maximal integer value
     */
    public function nextInt(?min: Int = Random.MIN_INT, ?max: Int = Random.MAX_INT): Int {
      return this.uniformIn(min, max);
    }
  
    /**
     * Generate a random bigint between min (included) and max (included)
     * @param min Minimal bigint value
     * @param max Maximal bigint value
    //  */
    //  public function nextBigInt(min: bigint, max: bigint): bigint {
    //   const g = prand.uniformBigIntDistribution(min, max, this.internalRng);
    //   this.internalRng = g[1];
    //   return g[0];
    // }
  
    /**
     * Generate a random floating point number between 0.0 (included) and 1.0 (excluded)
     */
    public function nextDouble(): Float {
      final a = this.next(26);
      final b = this.next(27);
      return (a * Random.DBL_FACTOR + b) * Random.DBL_DIVISOR;
    }
  }