package h3d.scene.fwd;

class DirLight extends FwdLight<h3d.shader.DirLight> {

	@:allow(h3d.scene.Object.createFwdDirLight)
	private function new(?dir: h3d.Vector, ?parent) {
		super(new h3d.shader.DirLight(), parent);
		priority = 100;
		if( dir != null ) setDirection(dir);
	}

	override function getShadowDirection() : h3d.Vector {
		return absPos.front();
	}

	override function emit(ctx) {
		_shader.direction.load(absPos.front());
		_shader.direction.normalize();
		super.emit(ctx);
	}
}