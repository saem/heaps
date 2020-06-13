package hxd.hmr;

#if macro
import haxe.macro.Expr;
import haxe.macro.ExprTools;
import haxe.macro.Compiler;
import haxe.macro.Context;
import haxe.macro.Type;
import sys.io.File;
import sys.FileSystem;

using haxe.io.Path;
using StringTools;
#end

/**
	Need to make changes to the compiled code to support hot code reloading

	How to use:
	1. Register via `--macro hxd.hmr.HmrComipler.register()` in .hxml

	How it works:
	* Types are updated to include hot code reload metadata
	* This metadata is used during reload to handle state transfer
	* Registers hcr life cycle handlers
	
	Hot Code Reload (hcr) life cycle handlers
	* beforeCodeReload
	* afterCodeReload
	
	TODO
	* Support full DCE:
		* Use @:ifFeature("pkg.Type.*") on hcr handlers
**/
class HmrCompiler {
	#if macro
	@:persistent static var beforeReload = new Set<ReloadHandler>();
	@:persistent static var afterReload = new Set();

	static function register():Void {
		Context.onGenerate(updateOptimizedTypesForHcr, false);
		// Context.onAfterGenerate()
	}

	static function updateOptimizedTypesForHcr(types:Array<Type>):Void {
		for (t in types) switch (t) {
			case TInst(_.get() => t, params) if (!t.isExtern):
				for (fn in t.statics.get()) switch(fn) {
					case {name:BeforeReload, kind:FMethod} if (!fn.isExtern):
						beforeReload.add()
				}
			case _:
		}
	}
	#end
}

enum ReloadHandlerData {
	BeforeHandler(name:String,pkg:String);
}

enum abstract LifeCycleHandler(String) to String {
	var BeforeReload = "beforeReload";
	var AfterReload = "afterReload";
}