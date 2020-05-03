package htst.fc;

interface Generator<T> {
    public function generate(mrng: Random): T;
}