import h3d.prim.Cube;
import h3d.prim.Cylinder;
import h3d.prim.Disc;
import h3d.prim.GeoSphere;
import h3d.prim.Grid;
import h3d.prim.Sphere;
import h3d.scene.CameraController;
import h3d.scene.CameraController.CameraControllerEventHandlerSystem as EventHandlerSystem;
import h3d.scene.Mesh;
import h3d.Vector;
import hxd.Key;

/**
 * Third person camera controller (top view) with arrow keys mapping
 */
class ThirdPersonCameraControllerEventHandlerSystem extends EventHandlerSystem {
	override function rowEventHandler(row: CameraControllerRow, e: hxd.Event): Void {
		super.rowEventHandler(row, e);

		final curPos = row.curPos;
		final target = row.target;
		// Third person camera arrow keys mapping
		if (e.keyCode == Key.UP) {
			final radian = Math.atan2((curPos.y - target.y), (curPos.x - target.x));
			EventHandlerSystem.pan(row, camera, Math.sin(radian), Math.cos(radian));
		}
		if (e.keyCode == Key.LEFT) {
			var radian = Math.atan2((curPos.y - target.y), (curPos.x - target.x));
			radian = radian - Math.PI / 2.0;
			EventHandlerSystem.pan(row, camera, Math.sin(radian), Math.cos(radian));
		}
		if (e.keyCode == Key.DOWN) {
			var radian = Math.atan2((curPos.y - target.y), (curPos.x - target.x));
			radian = radian + Math.PI;
			EventHandlerSystem.pan(row, camera, Math.sin(radian), Math.cos(radian));
		}
		if (e.keyCode == Key.RIGHT) {
			var radian = Math.atan2((curPos.y - target.y), (curPos.x - target.x));
			radian = radian + Math.PI / 2.0;
			EventHandlerSystem.pan(row, camera, Math.sin(radian), Math.cos(radian));
		}
	}
}

class Polygons extends hxd.App {

	var world : h3d.scene.World;
	var shadow : h3d.pass.DefaultShadowMap;
	var cameraCtrl : h3d.scene.CameraController;

	override function init() {
		world = s3d.createWorld(64, 128, s3d);

		// Grid
		var grid = new Grid(64, 64);
		grid.addNormals();
		grid.addUVs();
		var gridMesh = s3d.createMesh(grid, s3d);
		gridMesh.material.color.setColor(0x999999);
		world.addChild(gridMesh);

		// Cube
		var cube = Cube.defaultUnitCube();
		var cubeMesh = s3d.createMesh(cube, s3d);
		cubeMesh.setPosition(16, 32, 0.5);
		cubeMesh.material.color.setColor(0xFFAA15);
		world.addChild(cubeMesh);

		// Cylinder
		var cylinder = new Cylinder(16, 0.5);
		cylinder.addNormals();
		cylinder.addUVs();
		var cylinderMesh = s3d.createMesh(cylinder, s3d);
		cylinderMesh.setPosition(24, 32, 0);
		cylinderMesh.material.color.setColor(0x6FFFB0);
		world.addChild(cylinderMesh);

		// Disc on top of cylinder
		var discTopCylinder = new Disc(0.5, 16);
		discTopCylinder.addNormals();
		discTopCylinder.addUVs();
		var discTopCylinderMesh = s3d.createMesh(discTopCylinder, s3d);
		discTopCylinderMesh.setPosition(24, 32, 1);
		discTopCylinderMesh.material.color.setColor(0x6FFFB0);
		world.addChild(discTopCylinderMesh);

		// Disc
		var disc = new Disc(0.5, 16);
		disc.addNormals();
		disc.addUVs();
		var discMesh = s3d.createMesh(disc, s3d);
		discMesh.setPosition(32, 32, 0.1);
		discMesh.material.color.setColor(0x3D138D);
		world.addChild(discMesh);

		// Geosphere
		var geosphere = new GeoSphere();
		geosphere.addNormals();
		geosphere.addUVs();
		var geosphereMesh = s3d.createMesh(geosphere, s3d);
		geosphereMesh.setPosition(40, 32, 0.6);
		geosphereMesh.material.color.setColor(0x00739D);
		world.addChild(geosphereMesh);

		// Sphere
		var sphere = new Sphere(0.5, 16, 16);
		sphere.addNormals();
		sphere.addUVs();
		var sphereMesh = s3d.createMesh(sphere, s3d);
		sphereMesh.setPosition(48, 32, 0.5);
		sphereMesh.material.color.setColor(0xFF4040);
		world.addChild(sphereMesh);

		world.done();

		// Lights
		var light = s3d.createFwdDirLight(new h3d.Vector( 0.3, -0.4, -0.9), s3d);
		s3d.lightSystem.ambientLight.setColor(0x909090);

		shadow = s3d.renderer.getPass(h3d.pass.DefaultShadowMap);
		shadow.size = 2048;
		shadow.power = 200;
		shadow.blur.radius= 0;
		shadow.bias *= 0.1;
		shadow.color.set(0.7, 0.7, 0.7);

		s3d.camera.target.set(32, 32, 0);
		s3d.camera.pos.set(80, 80, 48);
		cameraCtrl = s3d.createCameraController();
		// TODO - this should be easier to swap, without private access
		cameraCtrl.row.eventHandler = new ThirdPersonCameraControllerEventHandlerSystem(@:privateAccess s3d.events, s3d.camera);
		cameraCtrl.loadFromCamera(s3d.camera);
	}

	static function main() {
		new Polygons();
	}

}