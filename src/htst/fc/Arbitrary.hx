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
        final v = mrng.nextInt();
        return v < 0 ? v * -1 : v;
    }
}