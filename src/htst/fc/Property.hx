package htst.fc;

import htst.rand.Generator;
import htst.rand.Generator.RandomGenerator;
import htst.fc.FastCheck.Arbitrary;
import haxe.CallStack;

typedef Predicate<A> = (a: A) -> Bool;

/**
 * A property is the combination of:
 * - Arbitraries: how to generate the inputs for the algorithm
 * - Predicate: how to confirm the algorithm succeeded?
 * 
 * https://github.com/dubzzz/fast-check/blob/master/src/check/property/IRawProperty.ts
 */
interface Property<Ts> extends Gen<Ts> extends Run<Ts> {}
interface Gen<Ts> { function generate(mrng: Random): Ts; }
interface Run<Ts> { function run(v: Ts): RunResult; }

/**
 * Based on: https://github.com/dubzzz/fast-check/blob/master/src/check/property/Property.generic.ts
 * 
 * Check out how they do before and after hooks in the above link for preconditions
 */
class SyncProperty<Ts> implements Property<Ts> {
    final arb: Arbitrary<Ts>;
    final predicate: Predicate<Ts>;

    public function new(arb: Arbitrary<Ts>, predicate: Predicate<Ts>) {
        this.arb = arb;
        this.predicate = predicate;
    }

    public function generate(mrng: Random): Ts {
        return this.arb.generate(mrng);
    }

    /**
     * Determines how to interpret the result
     * 
     * TODO - this should use the current result and accumulated state for control flow
     * 
     * Based on: https://github.com/dubzzz/fast-check/blob/368563be9e224de0e56016f1b0f5fb8351c480c8/src/check/runner/RunnerIterator.ts#L43
     */
    public function run(v: Ts): RunResult {
        var output: Null<RunResult> = null;
        try {
            output = switch(this.predicate(v)) {
                case true: Success;
                case false: Failure("Property failed by returning false");
            }
        } catch(e: RunResult) {
            return switch(e) {
                case PreconditionFailure: e;
                case _: Failure(CallStack.toString(CallStack.exceptionStack()));
            }
        }
        return switch(output) {
            case null: Failure("Failededededed");
            case _: output;
        }
    }
}

/**
 * N.B. Didn't implement lazy generation, might do that later
 *
 * https://github.com/dubzzz/fast-check/blob/master/src/check/runner/Tosser.ts
 */
class PropertyGen<Ts> {
    final property: Gen<Ts>;
    final seed: Int;
    var rng: RandomGenerator;
    var index = 0;

    public inline function new(property: Gen<Ts>, seed: Int, rng: RandomGenerator) {
        this.property = property;
        this.seed = seed;
        this.rng = rng;
    }

    public function hasNext(): Bool { 
        // this will change once skipping and other things are implemented
        return this.index < 10000;
    }

    public function next(): Ts {
        this.index++;
        // not entirely sure why we skipN or jump (not implemented)
        // see: https://github.com/dubzzz/fast-check/blob/master/src/check/runner/Tosser.ts#L23
        this.rng = Generator.skipN(this.rng, 42);
        return this.property.generate(new Random(this.rng));
    }
}

/**
 * PreconditionFailure concept is not implemented, rough idea:
 *  - one can have preconditions to skip tests/inputs
 *  - this tracks that
 *  - skipping isn't always possible, of course
 */
enum RunResult {
    Success;
    Failure(message:String);
    PreconditionFailure;
}