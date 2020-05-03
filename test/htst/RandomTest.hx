package htst;

import htst.fc.FastCheck;

class RandomTest extends utest.Test {
    function testShowSucceedingProperty() {
        FastCheck.assert(FastCheck.forAllOld(FastCheck.uInt(),(i) -> i > 0));
        FastCheck.macroTest("foo", "bar");
    }

    // function testShowFailingProperty() {
    //     FastCheck.assert(FastCheck.forAll(FastCheck.int(),(i) -> i > 0));
    // }
}