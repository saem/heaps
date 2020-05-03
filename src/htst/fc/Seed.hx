package htst.fc;

abstract Seed(Int) to Int from Int {
    public static inline function generateDefaultSeed(): Int {
        return Math.floor(Date.now().getTime()) ^ (Math.floor(Math.random() * 0x10000000));
    }
}