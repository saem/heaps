package h3d.scene.fwd;

import h3d.scene.Light.State as LightState;

class DirLight extends FwdLight {

	var dirState(get,never): State;
	inline function get_dirState() { return this._state; }

	@:allow(h3d.scene.Object.createFwdDirLight)
	private function new(?dir: h3d.Vector, ?parent) {
		super(State.init(), parent);
		if( dir != null ) setDirection(dir);
	}

	override function getShadowDirection() : h3d.Vector {
		return absPos.front();
	}

	override function emit(ctx) {
		this.dirState.shader.direction.load(absPos.front());
		this.dirState.shader.direction.normalize();
		super.emit(ctx);
	}
}

private abstract State(LightState) from LightState {
	public var shader(get,never): h3d.shader.DirLight;
	inline function get_shader() return cast this.shader;

	public function new(s) { this = s; }

	public static inline function init() {
		final s = new LightState(h3d.scene.Light.Type.FwdDir, new h3d.shader.DirLight());
		s.priority = 100;
		return s;
	}
}