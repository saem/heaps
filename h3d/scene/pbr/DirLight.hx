package h3d.scene.pbr;

import h3d.scene.SceneStorage.EntityId;
import h3d.scene.Light.State as LightState;

class DirLight extends Light {

	@:allow(h3d.scene.Scene)
	var dirState(get,never): State;
	inline function get_dirState() return this._state;

	@:allow(h3d.scene.Scene.createPbrDirLight)
	private function new(eid: EntityId, lRowRef: h3d.scene.Light.LightRowRef, ?dir: h3d.Vector, ?parent) {
		State.init(lRowRef.getRow(), this);
		super(eid, lRowRef, parent);
		this.objectType = h3d.scene.Object.ObjectType.TPbrDirLight;
		if( dir != null ) setDirection(dir);
	}

	public override function clone( ?o : h3d.scene.Cloneable ) : h3d.scene.Cloneable {
		var dl = o == null ? this.getScene().createPbrDirLight(null) : cast o;
		super.clone(dl);
		return dl;
	}

	override function getShadowDirection() : h3d.Vector {
		return absPos.front();
	}

	public static function syncShader(state: State, absPos: h3d.Matrix): Void {
		final pbr = state.shader;
		pbr.lightColor.load(state.color);
		pbr.lightColor.scale3(state.power * state.power);
		pbr.lightDir.load(absPos.front());
		pbr.lightDir.scale3(-1);
		pbr.lightDir.normalize();
		pbr.occlusionFactor = state.occlusionFactor;
	}
}

@:forward(shadows,color,power,occlusionFactor)
private abstract State(LightState) to LightState from LightState {
	public var shader(get,never): h3d.shader.pbr.Light.DirLight;
	inline function get_shader() return cast this.shader;

	private function new(s) { this = s; }

	public static inline function init(s: LightState, l: DirLight) {
		s.shadows = new h3d.pass.DirShadowMap(l);

		return s;
	}
}