package h3d.scene;

class CameraController {

	public var entityId(default, null): h3d.scene.SceneStorage.EntityId;
	public final id: CameraControllerId = new CameraControllerId(1);

	public var distance(get, never) : Float;
	public var theta(get, never) : Float;
	public var phi(get, never) : Float;
	public var fovY(get, never) : Float;
	public var target(get, never) : h3d.col.Point;

	public var friction = 0.4;
	public var rotateSpeed = 1.;
	public var zoomAmount = 1.15;
	public var fovZoomAmount = 1.1;
	public var panSpeed = 1.;
	public var smooth = 0.6;

	public var lockZPlanes = false;

	var scene : h3d.scene.Scene;
	var pushing = -1;
	var pushX = 0.;
	var pushY = 0.;
	var moveX = 0.;
	var moveY = 0.;
	var curPos = new h3d.Vector();
	var curOffset = new h3d.Vector();
	var targetPos = new h3d.Vector(10. / 25., Math.PI / 4, Math.PI * 5 / 13);
	var targetOffset = new h3d.Vector(0, 0, 0, 0);

	private function new(entityId: h3d.scene.SceneStorage.EntityId, scene:h3d.scene.Scene, ?distance: Float) {
		this.entityId = entityId;
		this.scene = scene;
		set(distance);
		toTarget();
	}

	inline function get_distance() return curPos.x / curOffset.w;
	inline function get_theta() return curPos.y;
	inline function get_phi() return curPos.z;
	inline function get_fovY() return curOffset.w;
	inline function get_target() return curOffset.toPoint();

	/**
		Set the controller parameters.
		Distance is ray distance from target.
		Theta and Phi are the two spherical angles
		Target is the target position
	**/
	public function set(?distance:Float, ?theta:Float, ?phi:Float, ?target:h3d.col.Point, ?fovY:Float) {
		if( theta != null )
			targetPos.y = theta;
		if( phi != null )
			targetPos.z = phi;
		if( target != null )
			targetOffset.set(target.x, target.y, target.z, targetOffset.w);
		if( fovY != null )
			targetOffset.w = fovY;
		if( distance != null )
			targetPos.x = distance * (targetOffset.w == 0 ? 1 : targetOffset.w);
	}

	/**
		Load current position from current camera position and target.
		Call if you want to modify manually the camera.
	**/
	public function loadFromCamera( camera : h3d.Camera, animate = false ) {
		targetOffset.load(camera.target);
		targetOffset.w = camera.fovY;

		var pos = camera.pos.sub(camera.target);
		var r = pos.length();
		targetPos.set(r, Math.atan2(pos.y, pos.x), Math.acos(pos.z / r));
		targetPos.x *= targetOffset.w;

		curOffset.w = camera.fovY;

		if( !animate )
			toTarget();
		else
			syncCamera(camera); // reset camera to current
	}

	/**
		Initialize to look at the bounds.
	**/
	public function initFromBounds( camera : h3d.Camera, bounds : h3d.col.Bounds ) {
		var center = bounds.getCenter();
		camera.target.load(center.toVector());
		var d = bounds.getMax().sub(center);
		d.scale(5);
		d.z *= 0.5;
		d = d.add(center);
		camera.pos.load(d.toVector());
		loadFromCamera(camera);
	}

	/**
		Stop animation by directly moving to end position.
		Call after set() if you don't want to animate the change
	**/
	public function toTarget() {
		curPos.load(targetPos);
		curOffset.load(targetOffset);
	}

	public function onAdd( scene : h3d.scene.Scene, camera : h3d.Camera) {
		scene.addEventListener(onEvent);
		if( curOffset.w == 0 )
			curPos.x *= camera.fovY;
		curOffset.w = camera.fovY; // load
		targetPos.load(curPos);
		targetOffset.load(curOffset);
	}

	public function onRemove( scene : h3d.scene.Scene ) {
		scene.removeEventListener(onEvent);
	}

	function onEvent( e : hxd.Event ) {

		switch( e.kind ) {
		case EWheel:
			if( hxd.Key.isDown(hxd.Key.CTRL) )
				fov(e.wheelDelta * fovZoomAmount * 2);
			else
				zoom(e.wheelDelta);
		case EPush:
			@:privateAccess scene.events.startDrag(onEvent, function() pushing = -1, e);
			pushing = e.button;
			pushX = e.relX;
			pushY = e.relY;
		case ERelease, EReleaseOutside:
			if( pushing == e.button ) {
				pushing = -1;
				@:privateAccess scene.events.stopDrag();
			}
		case EMove:
			switch( pushing ) {
			case 0:
				if( hxd.Key.isDown(hxd.Key.ALT) )
					zoom(-((e.relX - pushX) +  (e.relY - pushY)) * 0.03);
				else
					rot(e.relX - pushX, e.relY - pushY);
				pushX = e.relX;
				pushY = e.relY;
			case 1:
				var m = 0.001 * curPos.x * panSpeed / 25;
				pan(-(e.relX - pushX) * m, (e.relY - pushY) * m);
				pushX = e.relX;
				pushY = e.relY;
			case 2:
				rot(e.relX - pushX, e.relY - pushY);
				pushX = e.relX;
				pushY = e.relY;
			default:
			}
		default:
		}
	}

	function fov(delta) {
		targetOffset.w += delta;
		if( targetOffset.w >= 179 )
			targetOffset.w = 179;
		if( targetOffset.w < 1 )
			targetOffset.w = 1;
	}

	function zoom(delta) {
		targetPos.x *= Math.pow(zoomAmount, delta);
	}

	function rot(dx, dy) {
		moveX += dx;
		moveY += dy;
	}

	function pan(dx, dy) {
		var v = new h3d.Vector(dx, dy);
		scene.camera.update();
		v.transform3x3(scene.camera.getInverseView());
		v.w = 0;
		targetOffset = targetOffset.add(v);
	}

	function syncCamera( cam : h3d.Camera ) {
		cam.target.load(curOffset);
		cam.target.w = 1;
		cam.pos.set( distance * Math.cos(theta) * Math.sin(phi) + cam.target.x, distance * Math.sin(theta) * Math.sin(phi) + cam.target.y, distance * Math.cos(phi) + cam.target.z );
		if( !lockZPlanes ) {
			cam.zNear = distance * 0.01;
			cam.zFar = distance * 100;
		}
		cam.fovY = curOffset.w;
	}

	public static function sync( controller: h3d.scene.CameraController, camera : h3d.Camera, elapsedTime: Float) {

		final targetPos = controller.targetPos;
		if( controller.moveX != 0 ) {
			targetPos.y += controller.moveX * 0.003 * controller.rotateSpeed;
			controller.moveX *= 1 - controller.friction;
			if( Math.abs(controller.moveX) < 1 ) controller.moveX = 0;
		}

		if( controller.moveY != 0 ) {
			targetPos.z -= controller.moveY * 0.003 * controller.rotateSpeed;
			var E = 2e-5;
			var bound = Math.PI - E;
			if( targetPos.z < E ) targetPos.z = E;
			if( targetPos.z > bound ) targetPos.z = bound;
			controller.moveY *= 1 - controller.friction;
			if( Math.abs(controller.moveY) < 1 ) controller.moveY = 0;
		}

		var dt = hxd.Math.min(1, 1 - Math.pow(controller.smooth, elapsedTime * 60));
		controller.curOffset.lerp(controller.curOffset, controller.targetOffset, dt);
		controller.curPos.lerp(controller.curPos, targetPos, dt );

		controller.syncCamera( camera );
	}

}

abstract CameraControllerId(Int) to Int {
	public inline function new(i: Int) { this = i; }

	public inline function nullOut() { this *= -1; }
	public inline function isNull() { return this <= 0; }
	public inline function isNotNull() { return !isNull(); }

	public static inline function nullRef() { return new CameraControllerId(0); }
}

/**
	Went overboard with the checks here, especially with the static id
**/
class CameraControllerStorage {
	var row: CameraController = null;

	public function new() {}

	public function allocateRow(entityId: h3d.scene.SceneStorage.EntityId, scene:h3d.scene.Scene, ?distance: Float) {
		if( row != null ) {
			throw "CameraController already allocated, must be singleton";
		}

		this.row = @:privateAccess new CameraController(entityId, scene, distance);

		return this.row.id;
	}

	public function fetchRow(id: CameraControllerId) {
		return row != null && row.id == id ? row : null;
	}

	public function deallocateRow(id: CameraControllerId) {
		if(row.id == id) { row = null; }
	}
}