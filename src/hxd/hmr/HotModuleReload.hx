package hxd.hmr;

class HotModuleReload {
	public static inline final propertyName = "appHotModuleReload";

    private var hmrCheck:() -> Bool;
	private var olderModule: HotModuleReloadAccess = null;
	private var newerModule: HotModuleReloadAccess = null;

    @:allow(HmrApp.main)
	private function new(hmrCheck:() -> Bool) {
        this.hmrCheck = hmrCheck;
    }

	public static function register(selfModule: HotModuleReloadAccess):Void {
		(js.Syntax.field(js.Browser.window, propertyName))(selfModule);			
	}

	/**
	 * Replace this with a function that will update the existing module's code
	 */
	public function handleLatestModule(newModule: HotModuleReloadAccess):Void {
		if(this.olderModule == null) {
			trace('First time module');
			this.olderModule = newModule;
			this.olderModule.setCheckHotReload(this.hmrCheck);
			this.olderModule.start();
			return;
		}

		trace('Replacement module');
		this.newerModule = newModule;
		// TODO - handle merge and handover

		js.Browser.console.group('Classes');
		for(name in js.lib.Object.getOwnPropertyNames(newModule.hxClasses)) {
			final klass = Type.resolveClass(name);
			for(field in Type.getClassFields(klass)) {
				// TODO - Lookup and copy over data
			}
		}
		js.Browser.console.groupEnd();
		// js.Browser.console.group('Enums');
		// for(i in js.lib.Object.getOwnPropertyNames(newModule.hxEnums)) {
		// 	trace(i);
		// }
		// js.Browser.console.groupEnd();
	}
}