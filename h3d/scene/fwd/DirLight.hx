package h3d.scene.fwd;

import h3d.scene.SceneStorage.EntityId;
import h3d.scene.Light.State as LightState;

class DirLight extends FwdLight {

	var dirState(get,never): State;
	inline function get_dirState() { return this._state; }

	@:allow(h3d.scene.Scene.createFwdDirLight)
	private function new(eid: EntityId, lRowRef: h3d.scene.Light.LightRowRef, ?dir: h3d.Vector, ?parent) {
		State.init(lRowRef.getRow());
		super(eid, lRowRef, parent);
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

	public static inline function init(s: LightState) {
		s.priority = 100;
		return s;
	}
}