package htst.fc;

interface Arbitrary<T> extends Generator<T> {
    public function getEdgeCases(): Array<T>;
}

class IntArbitrary implements Arbitrary<Int> {
    public function new() {}

    public function generate(mrng: Random): Int {
        return mrng.nextInt();
    }
    public function getEdgeCases(): Array<Int> {
        return [0,1,-1, 0x80000000, 0x7fffffff];
    }
} 

class UIntArbitrary implements Arbitrary<UInt> {
    public function new() {}

    public function generate(mrng: Random): UInt {
        return mrng.nextIntInRange(0);
    }

    public function getEdgeCases(): Array<UInt> {
        return [0, 1, 0x7fffffff];
    }
}

class BoolArbitrary implements Arbitrary<Bool> {
    public function new() {}

    public function generate(mrng: Random): Bool {
        return mrng.nextBool();
    }

    public function getEdgeCases(): Array<Bool> {
        return [true, false];
    }
}

class FloatArbitrary implements Arbitrary<Float> {
    public function new() {}

    public function generate(mrng: Random): Float {
        return mrng.nextFloat();
    }

    public function getEdgeCases(): Array<Float> {
        return [0.0, 1.0, -1.0, 1e300, Math.NEGATIVE_INFINITY, Math.NaN, Math.POSITIVE_INFINITY];
    }
}