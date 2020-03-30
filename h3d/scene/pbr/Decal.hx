package h3d.scene.pbr;

class Decal extends Mesh {

	@:allow(h3d.scene.Object.createPbrDecal)
	private function new( primitive, ?material, ?parent ) {
		super(primitive, material, parent);
	}

	override function sync( ctx : RenderContext.SyncContext ) {
		super.sync(ctx);

		var shader = material.mainPass.getShader(h3d.shader.pbr.VolumeDecal.DecalPBR);
		if( shader != null )
			syncDecalPBR(shader);
	}

	function syncDecalPBR( shader : h3d.shader.pbr.VolumeDecal.DecalPBR ) {
		shader.normal = getAbsPos().up();
		shader.tangent = getAbsPos().right();
	}



}