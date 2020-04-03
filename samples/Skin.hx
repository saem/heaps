import h3d.scene.*;
import h3d.scene.fwd.*;

class Skin extends SampleApp {

	var cache : h3d.prim.ModelCache;
	var obj: h3d.scene.Object;
	var sword: h3d.scene.Object;
	var skeleton: h3d.scene.Object;

	override function init() {
		super.init();

		cache = new h3d.prim.ModelCache();

		obj = cache.loadModel(hxd.Res.Model);
		obj.scale(0.1);
		this.sword = obj.getObjectByName("Sword01");
		this.skeleton = obj.getObjectByName("Skeleton01");
		s3d.addChild(obj);
		s3d.camera.pos.set( -3, -5, 3);
		s3d.camera.target.z += 1;

		final animation = cache.loadAnimation(hxd.Res.Model);
		obj.playAnimation(animation);

		// add lights and setup materials
		var dir = h3d.scene.Object.createFwdDirLight(new h3d.Vector( -1, 3, -10), s3d);
		for( m in obj.getMaterials() ) {
			var t = m.mainPass.getShader(h3d.shader.Texture);
			if( t != null ) t.killAlpha = true;
			m.mainPass.culling = None;
			m.getPass("shadow").culling = None;
		}
		s3d.lightSystem.ambientLight.set(0.4, 0.4, 0.4);

		var shadow = s3d.renderer.getPass(h3d.pass.DefaultShadowMap);
		shadow.power = 20;
		shadow.color.setColor(0x301030);
		dir.enableSpecular = true;

		this.s3d.createCameraController().loadFromCamera(this.s3d.camera);

		var showJoints = false;
		final skins = s3d.findAll((o) -> Std.downcast(o, h3d.scene.Skin));
		final meshes = s3d.findAll(o -> Std.downcast(o, h3d.scene.Mesh));
		addCheck("Show Joints", () -> showJoints, (b) -> {
			showJoints = b;
			skins.map(s -> s.showJoints = showJoints);
			meshes.map(m -> m.material.mainPass.wireframe = b);
		});

		var pauseAnimation = false;
		addCheck("Pause Animation", () -> pauseAnimation, b -> {
			pauseAnimation = b;
			if (pauseAnimation) obj.stopAnimation(); else obj.playAnimation(animation);
		});
	}

	static function main() {
		hxd.Res.initEmbed();
		new Skin();
	}
}
