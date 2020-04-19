package h3d.scene.pbr;

import h3d.scene.SceneStorage.EntityId;

typedef LightState = h3d.scene.Light.State;

/**
	Don't extend this class, instead extend PbrLight, this is here
	to hide the type parameter and make things happy.
**/
class Light extends h3d.scene.Light {

	var pbrState(get,never):State;
	inline function get_pbrState() return this._state;

	@:s public var power(get,set) : Float;
	public var shadows(get,set) : h3d.pass.Shadows;
	public var occlusionFactor(get,set) : Float;
	public var primitive(get,never) : h3d.prim.Primitive;

	private function new(eid: EntityId, lRowRef: h3d.scene.Light.LightRowRef, ?parent: h3d.scene.Object = null) {
		State.init(lRowRef.getRow(), this);
		super(eid, lRowRef, parent);
	}

	inline function get_power() return this.pbrState.power;
	inline function set_power(p) return this.pbrState.power = p;
	inline function get_shadows() return this.pbrState.shadows;
	inline function set_shadows(s) return this.pbrState.shadows = s;
	inline function get_occlusionFactor() return this.pbrState.occlusionFactor;
	inline function set_occlusionFactor(o) return this.pbrState.occlusionFactor = o;
	inline function get_primitive() return this.pbrState.primitive;

	override function onRemove() {
		super.onRemove();
		if( shadows != null ) shadows.dispose();
	}

	override function get_color() {
		return this.pbrState.color;
	}

	override function set_color(v:h3d.Vector) {
		return this.pbrState.color = v;
	}

	override function get_enableSpecular() {
		return true;
	}

	override function set_enableSpecular(b) {
		if( !b ) throw "Not implemented for this light";
		return true;
	}

}

@:forward(power, color, shadows, occlusionFactor, primitive)
private abstract State(LightState) from LightState to LightState {
	public inline function new(ls) { this = ls; }

	public static inline function init(s: LightState, l: Light) {
		if( s.shadows == null ) s.shadows = new h3d.pass.Shadows(l);

		return s;
	}
}