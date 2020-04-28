package htst.rand;

import utest.Assert;
import htst.fc.FastCheck;

class GeneratorTest extends utest.Test {
    function testCongruentialProducesTheRightSequenceForSeedAs42() {
        var g = Generator.congruential(42);
        final data: Array<Int> = [];
        for (_ in 0...10) {
            final result = g.next();
            data.push(result.result);
            g = result.generator;
        }

        // Same values as Visual C++ rand() for srand(42)
        Assert.same(data, [175, 400, 17869, 30056, 16083, 12879, 8016, 7644, 15809, 1769]);
    }

    function testCongruentialTheSameSequenceGivenSameSeeds() {
        FastCheck.assert(FastCheck.forEach(FastCheck.int(), function(i) {
            final gen = 21;
            final skip = 7;
            final seq1 = Generator.generateN(Generator.skipN(Generator.congruential(i), skip), gen).result;
            final seq2 = Generator.generateN(Generator.skipN(Generator.congruential(i), skip), gen).result;
            Assert.same(seq1, seq2);
        }));
    }

    function testCongruentialSameSequencesIfCalledTwice() {
        FastCheck.assert(FastCheck.forEach(FastCheck.int(), function(i) {
            final rng = Generator.skipN(Generator.congruential(i), 31);
            final seq1 = Generator.generateN(rng, 79).result;
            final seq2 = Generator.generateN(rng, 79).result;
            Assert.same(seq1, seq2);
        }));
    }

    function testCongruentialValuesInRange() {
        FastCheck.assert(FastCheck.forEach(FastCheck.int(), function(i) {
            final rng = Generator.congruential(i);
            final value = Generator.skipN(rng, 17).next().result;
            Assert.isTrue(value >= rng.min());
            Assert.isTrue(value <= rng.max());
        }));
    }

    function testCongruential32TheSameSequenceGivenSameSeeds() {
        FastCheck.assert(FastCheck.forEach(FastCheck.int(), function(i) {
            final gen = 21;
            final skip = 7;
            final seq1 = Generator.generateN(Generator.skipN(Generator.congruential32(i), skip), gen).result;
            final seq2 = Generator.generateN(Generator.skipN(Generator.congruential32(i), skip), gen).result;
            Assert.same(seq1, seq2);
        }));
    }

    function testCongruential32SameSequencesIfCalledTwice() {
        FastCheck.assert(FastCheck.forEach(FastCheck.int(), function(i) {
            final rng = Generator.skipN(Generator.congruential32(i), 31);
            final seq1 = Generator.generateN(rng, 79).result;
            final seq2 = Generator.generateN(rng, 79).result;
            Assert.same(seq1, seq2);
        }));
    }

    // Bug: line: 32, Run: 0, Seed: -1327730780, Counter Example: 1879314970, Message: See utest.Assert failure
    function testCongruential32ValuesInRange() {
        FastCheck.assert(FastCheck.forEach(FastCheck.int(), function(i) {
            final rng = Generator.congruential32(i);
            final value = Generator.skipN(rng, 17).next().result;
            Assert.isTrue(value >= rng.min());
            Assert.isTrue(value <= rng.max());
        }));
    }

    // Massive performance issues with this test
    // function testCongruential32EquivalentToUniformDistributionOfCongruentialOver32Bits() {
    //     FastCheck.assert(FastCheck.forAll(FastCheck.int(), function(i) {
    //         var rng = Generator.congruential(i);
    //         var rng32 = Generator.congruential32(i);
    //         final dist = new Distribution(0, 0xffffffff);
    //         for (_ in 0...100) {
    //             final nrng = dist.result(rng);
    //             final nrng32 = dist.result(rng32);
    //             if (nrng.result != nrng32.result)
    //                 return false;
    //             rng = nrng.generator;
    //             rng32 = nrng32.generator;
    //         }
    //         return true;
    //     }));
    // }
}