package;

import utest.Runner;
import htst.RandomTest;
import haxe.ds.Either;
#if macro
import haxe.macro.Context;
import haxe.macro.Expr;
import haxe.io.Path;

using sys.FileSystem;
using StringTools;
using haxe.macro.Tools;
#end

class TestAll {
	public static function main() {
		utest.UTest.run([new RandomTest(), new htst.rand.GeneratorTest()]);
	}
}
