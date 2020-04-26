package htst.fc;

class FastCheck {
    public static function assert<Ts>(property: Property<Ts>) {
        final out = check(property);
        throwIfFailed(out);
    }
    public static function check<Ts>(property: Property<Ts>): RunDetails<Ts> {
        return null;
    }

    public static function property() {
        
    }

    public static function bool() {}
    public static function float() {}
    public static function float64array() {}

    /**
     * Blindly ported from FC, until I've figured out uTest integrations
     *
     * @param out 
     */
    public static function throwIfFailed(out) {
        trace(out);
    }
}

class Property<Ts> implements Property<Ts> {
    final arb: Arbitrary<Ts>;
    final predicate: (t: Ts) -> Bool;

    public function new(arb: Arbitrary<Ts>, predicate: (t: Ts) -> Bool) {
        this.arb = arb;
        this.predicate = predicate;
    }

    public function generate(mrng: Random): Ts {
        return this.arb.generate(mrng);
    }
}

interface Arbitrary<T> {
    public function generate(mrng: Random): T;
}

class BaseParameters {
    var seed: Int;
    var randomType: (seed: Int) -> Random;
    var numRuns: Int;
    var maxSkipsPerRun: Int;
    var unbiased: Bool;

    public function new(seed, randomType, numRuns, maxSkipsPerRun) {
        this.seed = seed;
        this.randomType = randomType;
        this.numRuns = numRuns;
        this.maxSkipsPerRun = maxSkipsPerRun;
    }
}

class GlobalParameters extends BaseParameters {}
class Parameters<T> extends BaseParameters {
    var examples: Array<T>;
    var path: String;

    override function new(path, examples, seed, randomType, numRuns, maxSkipsPerRun) {
        super(seed, randomType, numRuns, maxSkipsPerRun);
        this.examples = examples;
        this.path = path;
    }
}

enum RunDetails<Ts> {
    Failed( numRuns: Int, seed: Int, counterExample: Ts, error: String);
    Success(numRuns: Int, seed: Int);
}