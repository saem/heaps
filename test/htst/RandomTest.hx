package htst;

import htst.fc.Arbitrary;
import htst.fc.FastCheck;

typedef UIntArb = Arbitrary<UInt>;

class RandomTest extends utest.Test {
    function testShowSucceedingProperty() {
        FastCheck.assert(FastCheck.forAllOld(FastCheck.uInt(),(i) -> i > 0));
        final bool = FastCheck.bool();
        final uInt: UIntArb = FastCheck.uInt();

        FastCheck.forAll(FastCheck.int(), uInt, bool, function(a,b,c) { return true; });
    }

    // function testShowFailingProperty() {
    //     FastCheck.assert(FastCheck.forAll(FastCheck.int(),(i) -> i > 0));
    // }
}