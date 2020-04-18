package h3d.scene.pbr;

class DirLight extends Light<h3d.shader.pbr.Light.DirLight> {

	@:allow(h3d.scene.Object.createPbrDirLight)
	private function new(?dir: h3d.Vector, ?parent) {
		shadows = new h3d.pass.DirShadowMap(this);
		super(new h3d.shader.pbr.Light.DirLight() ,parent);
		if( dir != null ) setDirection(dir);
	}

	public override function clone( ?o : h3d.scene.Object ) : h3d.scene.Object {
		var dl = o == null ? h3d.scene.Object.createPbrDirLight(null) : cast o;
		super.clone(dl);
		return dl;
	}

	override function getShadowDirection() : h3d.Vector {
		return absPos.front();
	}

	override function emit(ctx:RenderContext.EmitContext) {
		pbr.lightColor.load(_color);
		pbr.lightColor.scale3(power * power);
		pbr.lightDir.load(absPos.front());
		pbr.lightDir.scale3(-1);
		pbr.lightDir.normalize();
		pbr.occlusionFactor = occlusionFactor;
		super.emit(ctx);
	}

}