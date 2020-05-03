package htst.fc;

import htst.fc.Property.PropertyGen;
import htst.fc.Property.Predicate;
import htst.fc.Property.Check;

#if macro
import haxe.macro.Expr;
#end

/**
 * Port of https://github.com/dubzzz/fast-check
 */
class FastCheck {
    /**
     * Overall flow is loosely based on runIt, see: https://github.com/dubzzz/fast-check/blob/368563be9e224de0e56016f1b0f5fb8351c480c8/src/check/runner/Runner.ts#L21
     * Seed Generation is a bastardized version of: https://github.com/dubzzz/fast-check/blob/master/src/check/runner/configuration/QualifiedParameters.ts#L51
     */
    public static function check<Ts>(property: Property<Ts>): RunDetails<Ts> {
        // TODO - JS number semantic assumptions and Haxe's lack of specification don't mix
        final seed = Seed.generateDefaultSeed();
        final gen = FastCheckInternal.toss(property, seed);
        final runner = new Runner(gen, property);
        final result = runner.runCheck();
        return (result.isFailure()) ?
            Failure(result.runs, seed, result.value, result.failure) :
            Success(result.runs, seed);
    }

    public static function assert<Ts>(property: Property<Ts>) {
        switch(check(property)) {
            case Failure(r, s, v, m):
                utest.Assert.isTrue(false, 'Run: ${r}, Seed: ${s}, Counter Example: ${v}, Message: ${m}');
            case Success(r,s):
                utest.Assert.isTrue(true);
        }
    }

    /**
     * Eventually m ake code like the following possible:
     *
     * forAll(Gen<A>, (a) => {
     *  return boolean pass/fail
     * });
     * forAll(Gen<A>, Gen<B>, (a,b) => {
     *  return boolean pass/fail
     * });
     * forAll(Gen<A>, Gen<B>, Gen<C>, (a,b,c) => {
     *  return boolean pass/fail
     * });
     * ...
     * 
     * Currently we can only support single value properties
     */
    public static function forAllOld<A>(arb: Arbitrary<A>, predicate: Predicate<A>): Property<A> {
        return new Property.SyncPropertyForAll<A>(arb, predicate);
    }

    public static macro function forAll(es: Array<haxe.macro.Expr>) {
        final types = es.map(e -> haxe.macro.Context.toComplexType(haxe.macro.Context.typeof(e)));
        final expr = ENew({pack: ["htst", "fc"], name: "ForAllExpression", params:[for(t in types) TPType(t)]}, []);
        return {expr: expr, pos: haxe.macro.Context.currentPos()};
    }

    public static function forEach<A>(arb: Arbitrary<A>, check: Check<A>): Property<A>  {
        return new Property.SyncPropertyForEach<A>(arb, check);
    }

    public static function bool() {}
    public static function int(): Arbitrary<Int> {
        return new Arbitrary.IntArbitrary();
    }
    public static function uInt(): Arbitrary<UInt> {
        return new Arbitrary.UIntArbitrary();
    }
    public static function float() {}
}

private class FastCheckInternal {
    /**
     * Think tossing a die -- we just be playin' D&D over here.
     * 
     * based off: https://github.com/dubzzz/fast-check/blob/master/src/check/runner/Tosser.ts#L23
     * 
     * TODO - They use thunks, I think this relates to shrinking and path/seed/rng management
     */
    public static function toss<Ts>(property: Property<Ts>, seed: Seed): PropertyGen<Ts> {
        return new PropertyGen(property, seed, Random.createRandom(seed));
    }
} 

/**
 * Run details in order to handle success and failure
 * 
 * https://github.com/dubzzz/fast-check/blob/master/src/check/runner/reporter/RunDetails.ts
 */
enum RunDetails<Ts> {
    Failure(numRuns: Int, seed: Seed, counterExample: Ts, error: String);
    Success(numRuns: Int, seed: Seed);
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

/**
 * References & Things to look at:
 * 
 * If we need to simulate finally as in try/catch/finally
 *  https://gist.github.com/yvt/fe1b1be6f976f1812a94
 * 
 * This might be an option for arbitrarily wide tuples/predicates/etc...
 *  - Forum post: https://community.haxe.org/t/variadic-type-parameters/2194
 *  - Full gist:  https://gist.github.com/nadako/b086569b9fffb759a1b5
 *      - Check the comments as they contain a key fix
 * 
 * FC is huge and broken up into a lot pieces, this is a map:
 *  https://github.com/dubzzz/fast-check/blob/master/src/fast-check-default.ts
 * 
 * How to use @:genericBuild + expression macros to create new static functions
 *  http://www.kevinresol.com/2016-11-23/genericbuild-function-haxe/
 */