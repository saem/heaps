package h3d.scene.fwd;

import h3d.scene.Light.State as LightState;

class PointLight extends FwdLight {

	var pointState(get,never): State;
	inline function get_pointState() return this._state;
	public var params(get, set) : h3d.Vector;

	@:allow(h3d.scene.Scene.createFwdPointLight)
	private function new(lRowRef: h3d.scene.Light.LightRowRef, ?parent) {
		State.init(lRowRef.getRow());
		super(lRowRef, parent);
	}

	inline function get_params() {
		return this.pointState.shader.params;
	}

	inline function set_params(p) {
		return this.pointState.shader.params = p;
	}

	override function emit(ctx) {
		var lum = hxd.Math.max(hxd.Math.max(color.r, color.g), color.b);
		var p = params;
		// solve lum / (x + y.d + z.d²) < 1/128
		if( p.z == 0 ) {
			cullingDistance = (lum * 128 - p.x) / p.y;
		} else {
			var delta = p.y * p.y - 4 * p.z * (p.x - lum * 128);
			cullingDistance = (p.y + Math.sqrt(delta)) / (2 * p.z);
		}
		this.pointState.shader.lightPosition.set(absPos._41, absPos._42, absPos._43);
		super.emit(ctx);
	}
}

typedef LightState = h3d.scene.Light.State;

private abstract State(LightState) from LightState {
	public var shader(get,never): h3d.shader.PointLight;
	inline function get_shader() return cast this.shader;

	public function new(s) { this = s; }

	public static inline function init(s: LightState) {
		return s;
	}
}