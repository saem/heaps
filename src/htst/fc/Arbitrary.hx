package htst.fc;

interface Arbitrary<T> extends Generator<T> {}

class IntArbitrary implements Arbitrary<Int> {
    public function new() {}

    public function generate(mrng: Random): Int {
        return mrng.nextInt();
    }
} 

class UIntArbitrary implements Arbitrary<UInt> {
    public function new() {}

    public function generate(mrng: Random): UInt {
        return mrng.nextIntInRange(0);
    }
}

class BoolArbitrary implements Arbitrary<Bool> {
    public function new() {}

    public function generate(mrng: Random): Bool {
        return mrng.nextBool();
    }
} 