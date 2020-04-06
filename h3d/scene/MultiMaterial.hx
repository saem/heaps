package h3d.scene;

class MultiMaterial extends Mesh {
	@:allow(h3d.scene.Object.createMultiMaterial)
	private function new( prim, ?mats = null, ?parent = null ) {
		super(prim, mats, parent);
	}
}