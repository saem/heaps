package hxd.hmr;

class HotModuleReloadAccess {
	public final hxClasses = js.Syntax.code("$hxClasses;");
	public final hxEnums = js.Syntax.code("$hxEnums;");
	public function new(start: () -> Void) {
		this.start = start;
	}

	public dynamic function start(): Void {
		throw new haxe.Exception("Start is uninitialized");
	}

	public function setCheckHotReload(fn: () -> Bool):Void {
		hxd.System.checkHotReload = fn;
	}
}