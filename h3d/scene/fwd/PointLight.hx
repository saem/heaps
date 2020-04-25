package h3d.scene.fwd;

import h3d.scene.SceneStorage.EntityId;
import h3d.scene.Light.State as LightState;

class PointLight extends FwdLight {

	@:allow(h3d.scene.Scene)
	var pointState(get,never): State;
	inline function get_pointState() return this._state;
	public var params(get, set) : h3d.Vector;

	@:allow(h3d.scene.Scene.createFwdPointLight)
	private function new(eid: EntityId, lRowRef: h3d.scene.Light.LightRowRef, ?parent) {
		State.init(lRowRef.getRow());
		super(eid, lRowRef, parent);
		this.objectType = h3d.scene.Object.ObjectType.TFwdPointLight;
	}

	inline function get_params() {
		return this.pointState.shader.params;
	}

	inline function set_params(p) {
		return this.pointState.shader.params = p;
	}

	public static function updateCullingDistance(state: State) {
		final color = state.color;
		final lum = hxd.Math.max(hxd.Math.max(color.r, color.g), color.b);
		final p = state.shader.params;
		// solve lum / (x + y.d + z.d²) < 1/128
		if( p.z == 0 ) {
			state.cullingDistance = (lum * 128 - p.x) / p.y;
		} else {
			final delta = p.y * p.y - 4 * p.z * (p.x - lum * 128);
			state.cullingDistance = (p.y + Math.sqrt(delta)) / (2 * p.z);
		}
	}

	public static function syncShader(state: State, absPos: h3d.Matrix) {
		state.shader.lightPosition.set(absPos._41, absPos._42, absPos._43);
	}
}

@:forward(color, cullingDistance)
private abstract State(LightState) from LightState {
	public var shader(get,never): h3d.shader.PointLight;
	inline function get_shader() return cast this.shader;

	public function new(s) { this = s; }

	public static inline function init(s: LightState) {
		return s;
	}
}