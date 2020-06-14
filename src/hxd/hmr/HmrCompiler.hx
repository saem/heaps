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
	static var reloadHandlers = new ReloadHandlerSet();

	static function register():Void {
		Context.onGenerate(registerHcrHandlers, false);
		// Context.onAfterGenerate()
	}

	static function registerHcrHandlers(types:Array<Type>):Void {
		for (t in types) switch (t) {
			case TInst(_.get() => {pack:['hxd','hmr']}, _):
				null;
			case TInst(_.get() => t, params) if (!t.isExtern):
				for (fn in t.statics.get()) switch(fn) {
					case {name:name, kind:FieldKind.FMethod(_), pos:pos} if (!fn.isExtern && fn.meta.has(BeforeReload)):
						if (!reloadHandlers.add(BeforeHandler(t.name, name, t.pack)))
							Context.fatalError("Only one function can be marked with @:beforeCodeReload", pos);
					default:
				}
			case _:
		}

		for(h in reloadHandlers)
			trace(switch(h) {
				case BeforeHandler(type, fn, pkg): '$pkg.$type.$fn';
			}
		);
	}
	#end
}

enum ReloadHandlerData {
	BeforeHandler(type:String,fn:String,pkg:Array<String>);
}

enum abstract LifeCycleHandler(String) to String {
	var BeforeReload = ":beforeCodeReload";
	var AfterReload = ":afterCodeReload";
}

class ReloadHandlerSet {
	private final map:hds.Map<String, ReloadHandlerData>;

	public inline function new() {
		this.map = new hds.Map<String, ReloadHandlerData>();
	}

	public inline function add(handler: ReloadHandlerData):Bool {
		final key = handlerToKey(handler);

		if (this.map.exists(key))
			return false;
		
		this.map.set(key, handler);
		return true;
	}

	public inline function contains(handler: ReloadHandlerData):Bool {
		return this.map.exists(handlerToKey(handler));
	}

	public inline function iterator():Iterator<ReloadHandlerData> {
		return this.map.iterator();
	}

	inline function handlerToKey(handler: ReloadHandlerData):String {
		return switch(handler) {
			case BeforeHandler(t,_,p): '$p.$t';
		}
	}
}