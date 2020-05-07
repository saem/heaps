package htst.fc;

/**
    Extra interface infront of Arbitrary<T> so that concepts like
    Exhaustive<T> can be supported.
**/
interface Generator<T> {
    public function generate(mrng: Random): T;
}