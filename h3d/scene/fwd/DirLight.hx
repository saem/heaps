package h3d.scene.fwd;

import h3d.scene.SceneStorage.EntityId;
import h3d.scene.Light.State as LightState;

class DirLight extends FwdLight {

	@:allow(h3d.scene.Scene)
	var dirState(get,never): State;
	inline function get_dirState() { return this._state; }

	@:allow(h3d.scene.Scene.createFwdDirLight)
	private function new(eid: EntityId, lRowRef: h3d.scene.Light.LightRowRef, ?dir: h3d.Vector, ?parent) {
		State.init(lRowRef.getRow());
		super(eid, lRowRef, parent);
		this.objectType = h3d.scene.Object.ObjectType.TFwdDirLight;
		if( dir != null ) setDirection(dir);
	}

	override function getShadowDirection() : h3d.Vector {
		return absPos.front();
	}

	public static function syncShader(state: State, absPos: h3d.Matrix): Void {
		state.shader.direction.load(absPos.front());
		state.shader.direction.normalize();
	}
}

private abstract State(LightState) from LightState {
	public var shader(get,never): h3d.shader.DirLight;
	inline function get_shader() return cast this.shader;

	public function new(s) { this = s; }

	public static inline function init(s: LightState) {
		s.priority = 100;
		return s;
	}
}