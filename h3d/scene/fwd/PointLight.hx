package h3d.scene.fwd;

class PointLight extends FwdLight<h3d.shader.PointLight> {

	public var params(get, set) : h3d.Vector;

	@:allow(h3d.scene.Object.createFwdPointLight)
	private function new(?parent) {
		super(new h3d.shader.PointLight(), parent);
	}

	inline function get_params() {
		return _shader.params;
	}

	inline function set_params(p) {
		return _shader.params = p;
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
		_shader.lightPosition.set(absPos._41, absPos._42, absPos._43);
		super.emit(ctx);
	}

}