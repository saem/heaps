package htst;

import htst.fc.FastCheck;

class RandomTest extends utest.Test {
    function testShowSucceedingProperty() {
        FastCheck.assert(FastCheck.property(FastCheck.uInt(),(i) -> i > 0));
    }

    function testShowFailingProperty() {
        FastCheck.assert(FastCheck.property(FastCheck.int(),(i) -> i > 0));
    }
}