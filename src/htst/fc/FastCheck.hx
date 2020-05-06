package htst.fc;

import htst.fc.Property.PropertyGen;
import htst.fc.Property.Predicate;
import htst.fc.Property.Check;

#if macro
import haxe.macro.Context;
import haxe.macro.Expr;
using htst.fc.FCMacroTools;
#end

/**
 * Inspired by Kotest: https://github.com/kotest/kotest/blob/master/doc/property_testing.md
 *
 * Started as a port of https://github.com/dubzzz/fast-check
 * That was abandoned.
 */
class FastCheck {
    /**
        Pass in some number of Generators, a predicate with matching signature
    **/
    public static macro function forAll(es: Array<Expr>) {
        final pos = Context.currentPos();
        final complexTypes = es.map(e -> Context.toComplexType(Context.follow(Context.typeof(e))));

        // TODO - error handling

        final predicateExpr = es[es.length - 1];
        final predicateCall = switch(predicateExpr.expr) {
            case EFunction(_): (macro (predicate));
            case _: predicateExpr;
        }

        final arbitraryExprs = es.slice(0, -1);
        final arbitraryVars:Array<Expr> = [];
        final arbitraryArgs = [];
        final arbValueTemps:Array<Expr> = [];
        final setArbValueTemps:Array<Expr> = [];
        var counterExample:Array<String> = [];
        for(i in 0...arbitraryExprs.length) {
            final varName = 'arb$i';
            final tmpName = '${varName}Tmp';
            counterExample.push('($$$tmpName)');
            arbitraryVars.push({
                expr: EVars([{
                    name: varName,
                    type: complexTypes[i],
                    expr: arbitraryExprs[i],
                    isFinal: true
                }]),
                pos: pos
            });

            arbValueTemps.push(macro var $tmpName);
            setArbValueTemps.push(macro $i{tmpName} = $i{varName}.generate(rng));
            arbitraryArgs.push(macro $i{tmpName});
        }

        final vars = macro {
            final seed = htst.fc.Seed.generateDefaultSeed();
            final rng = htst.fc.Random.createRandom(seed);

            final predicate = ${predicateExpr};
            var success = true; // flag to track test state
        };
        final arbs = {expr: EBlock(arbitraryVars), pos: pos};

        final loopBody = ({expr: EBlock(setArbValueTemps), pos: pos}).concat(macro {
            utest.Assert.isTrue(${predicateCall}($a{arbitraryArgs}), 'Failed for seed ($$seed), on run ($$index), with counter example: ${counterExample.join(', ')}');

            if(!utest.Assert.results.last().match(Success(_))) {
                success = false;
                break; // stop early on failure
            }

            rng.skipN(42);
        });
        final testLoop = macro {
            for(index in 0...1000) ${loopBody}
        };

        final result = vars
            .concat(arbs)
            .concat({expr: EBlock(arbValueTemps), pos:pos})
            .concat(testLoop);
        return result;
    }

    /**
        Pass in some number of Generators, a check function with matching signature.
        Note the check function will need to use utest.Assert independently.
    **/
    public static macro function checkAll(es: Array<Expr>) {
        final pos = Context.currentPos();
        final complexTypes = es.map(e -> Context.toComplexType(Context.follow(Context.typeof(e))));

        // TODO - error handling

        final checkExpr = es[es.length - 1];
        final checkCall = switch(checkExpr.expr) {
            case EFunction(_): (macro (check));
            case _: checkExpr;
        }

        final arbitraryExprs = es.slice(0, -1);
        final arbitraryVars:Array<Expr> = [];
        final arbitraryArgs = [];
        final arbValueTemps:Array<Expr> = [];
        final setArbValueTemps:Array<Expr> = [];
        var counterExample:Array<String> = [];
        for(i in 0...arbitraryExprs.length) {
            final varName = 'arb$i';
            final tmpName = '${varName}Tmp';
            counterExample.push('($$$tmpName)');
            arbitraryVars.push({
                expr: EVars([{
                    name: varName,
                    type: complexTypes[i],
                    expr: arbitraryExprs[i],
                    isFinal: true
                }]),
                pos: pos
            });

            arbValueTemps.push(macro var $tmpName);
            setArbValueTemps.push(macro $i{tmpName} = $i{varName}.generate(rng));
            arbitraryArgs.push(macro $i{tmpName});
        }

        final vars = macro {
            final seed = htst.fc.Seed.generateDefaultSeed();
            final rng = htst.fc.Random.createRandom(seed);

            final check = ${checkExpr};
            var success = true; // flag to track test state
            var resultsCount = utest.Assert.results.length; // in case other things were run already
            var resultsIter = null;
        };
        final arbs = {expr: EBlock(arbitraryVars), pos: pos};

        final loopBody = ({expr: EBlock(setArbValueTemps), pos: pos}).concat(macro {
            ${checkCall}($a{arbitraryArgs});

            // TODO - hack to tie into utest
            final results = utest.Assert.results;
            if(resultsIter == null) { resultsIter = results.iterator(); }
            final newResultsCount = utest.Assert.results.length - resultsCount;
            var r = 0;
            while(r < newResultsCount && success) {
                if(!resultsIter.next().match(Success(_) | Ignore(_))) {
                    success = false;
                    break;
                }
                r++;
            }
            resultsCount = results.length;

            // stop early on failure
            if(!success) {
                utest.Assert.fail('Failed for seed ($$seed), on run ($$index), with counter example: ${counterExample.join(', ')}');
                break;
            }

            rng.skipN(42);
        });
        final testLoop = macro {
            for(index in 0...1000) ${loopBody}
        };

        final result = vars
            .concat(arbs)
            .concat({expr: EBlock(arbValueTemps), pos:pos})
            .concat(testLoop);
        return result;
    }

    public static function bool(): Arbitrary<Bool> {
        return new Arbitrary.BoolArbitrary();
    }
    public static function int(): Arbitrary<Int> {
        return new Arbitrary.IntArbitrary();
    }
    public static function uInt(): Arbitrary<UInt> {
        return new Arbitrary.UIntArbitrary();
    }
    public static function float() {}
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