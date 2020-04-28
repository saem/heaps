package htst;

import htst.fc.FastCheck;

class RandomTest extends utest.Test {
    function testShowSucceedingProperty() {
        FastCheck.assert(FastCheck.forAll(FastCheck.uInt(),(i) -> i > 0));
    }

    // function testShowFailingProperty() {
    //     FastCheck.assert(FastCheck.forAll(FastCheck.int(),(i) -> i > 0));
    // }
}