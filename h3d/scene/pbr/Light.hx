package h3d.scene.pbr;

/**
	Don't extend this class, instead extend PbrLight, this is here
	to hide the type parameter and make things happy.
**/
class Light extends h3d.scene.Light {

	var _color : h3d.Vector;
	var primitive : h3d.prim.Primitive;
	@:s public var power : Float = 1.;
	public var shadows : h3d.pass.Shadows;
	public var occlusionFactor : Float;

	private function new(shader,?shadows: h3d.pass.Shadows = null,?parent: h3d.scene.Object = null) {
		this.shadows = ( shadows == null ) ?new h3d.pass.Shadows(this) : shadows;
		super(shader,parent);
		_color = new h3d.Vector(1,1,1,1);
	}

	override function onRemove() {
		super.onRemove();
		if( shadows != null ) shadows.dispose();
	}

	override function get_color() {
		return _color;
	}

	override function set_color(v:h3d.Vector) {
		return _color = v;
	}

	override function get_enableSpecular() {
		return true;
	}

	override function set_enableSpecular(b) {
		if( !b ) throw "Not implemented for this light";
		return true;
	}

}

class PbrLight<S:h3d.shader.pbr.Light> extends Light {
	var pbr(get,set): S;
    inline function get_pbr():S return cast this.shader;
	inline function set_pbr(s: S):S return cast this.shader = cast s;

	private function new(shader,?shadows: h3d.pass.Shadows = null,?parent: h3d.scene.Object = null) {
		super(shader, shadows, parent);
	}
}
