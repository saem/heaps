package h3d.scene.pbr;

import h3d.scene.Light.State as LightState;

class DirLight extends Light {

	var dirState(get,never): State;
	inline function get_dirState() return this._state;

	@:allow(h3d.scene.Scene.createPbrDirLight)
	private function new(lRowRef: h3d.scene.Light.LightRowRef, ?dir: h3d.Vector, ?parent) {
		State.init(lRowRef.getRow(), this);
		super(lRowRef, parent);
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

	override function emit(ctx:RenderContext.EmitContext) {
		final pbr = this.dirState.shader;
		pbr.lightColor.load(this.dirState.color);
		pbr.lightColor.scale3(power * power);
		pbr.lightDir.load(absPos.front());
		pbr.lightDir.scale3(-1);
		pbr.lightDir.normalize();
		pbr.occlusionFactor = occlusionFactor;
		super.emit(ctx);
	}
}

@:forward(shadows,color)
private abstract State(LightState) to LightState from LightState {
	public var shader(get,never): h3d.shader.pbr.Light.DirLight;
	inline function get_shader() return cast this.shader;

	private function new(s) { this = s; }

	public static inline function init(s: LightState, l: DirLight) {
		s.shadows = new h3d.pass.DirShadowMap(l);

		return s;
	}
}