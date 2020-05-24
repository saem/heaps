package h3d.scene;

class CameraController {
	public final row: CameraControllerRow;

	@:allow(h3d.scene.Scene.createCameraController)
	private function new(row: CameraControllerRow) {
		this.row = row;
	}

	public static function onAdd( row : CameraControllerRow, scene : h3d.scene.Scene, camera : h3d.Camera) {
		scene.addEventListener(row.onEvent);

		final curOffset = row.curOffset;
		final curPos = row.curPos;
		if( curOffset.w == 0 )
			curPos.x *= camera.fovY;
		curOffset.w = camera.fovY; // load
		row.targetPos.load(curPos);
		row.targetOffset.load(curOffset);
	}

	/**
		TODO - tie into deletion/removal code, which currently doesn't exist.
	**/
	public static function onRemove( row : CameraControllerRow, scene : h3d.scene.Scene ) {
		scene.removeEventListener(row.onEvent);
	}

	/**
		Set the controller parameters.
		Distance is ray distance from target.
		Theta and Phi are the two spherical angles
		Target is the target position
	**/
	public function set(?distance:Float, ?theta:Float, ?phi:Float, ?target:h3d.col.Point, ?fovY:Float) {
		final targetPos = this.row.targetPos;
		final targetOffset = this.row.targetOffset;
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
		final targetOffset = this.row.targetOffset;
		final targetPos = this.row.targetPos;
		targetOffset.load(camera.target);
		targetOffset.w = camera.fovY;

		var pos = camera.pos.sub(camera.target);
		var r = pos.length();
		targetPos.set(r, Math.atan2(pos.y, pos.x), Math.acos(pos.z / r));
		targetPos.x *= targetOffset.w;

		this.row.curOffset.w = camera.fovY;

		if( !animate )
			toTarget();
		else
			CameraController.syncCamera(this.row, camera); // reset camera to current
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
		this.row.curPos.load(this.row.targetPos);
		this.row.curOffset.load(this.row.targetOffset);
	}

	public static function sync( row : CameraControllerRow, camera : h3d.Camera, elapsedTime: Float) {
		final targetPos = row.targetPos;
		if( row.moveX != 0 ) {
			targetPos.y += row.moveX * 0.003 * row.rotateSpeed;
			row.moveX *= 1 - row.friction;
			if( Math.abs(row.moveX) < 1 ) row.moveX = 0;
		}

		if( row.moveY != 0 ) {
			targetPos.z -= row.moveY * 0.003 * row.rotateSpeed;
			var E = 2e-5;
			var bound = Math.PI - E;
			if( targetPos.z < E ) targetPos.z = E;
			if( targetPos.z > bound ) targetPos.z = bound;
			row.moveY *= 1 - row.friction;
			if( Math.abs(row.moveY) < 1 ) row.moveY = 0;
		}

		var dt = hxd.Math.min(1, 1 - Math.pow(row.smooth, elapsedTime * 60));
		row.curOffset.lerp(row.curOffset, row.targetOffset, dt);
		row.curPos.lerp(row.curPos, targetPos, dt );

		CameraController.syncCamera( row , camera );
	}

	static function syncCamera( row : CameraControllerRow, cam : h3d.Camera ) {
		cam.target.load(row.curOffset);
		cam.target.w = 1;
		cam.pos.set( row.distance * Math.cos(row.theta) * Math.sin(row.phi) + cam.target.x, row.distance * Math.sin(row.theta) * Math.sin(row.phi) + cam.target.y, row.distance * Math.cos(row.phi) + cam.target.z );
		if( !row.lockZPlanes ) {
			cam.zNear = row.distance * 0.01;
			cam.zFar = row.distance * 100;
		}
		cam.fovY = row.curOffset.w;
	}
}

abstract CameraControllerEventHandler(CameraControllerEventHandlerSystem) {
	private inline function new(c:CameraControllerEventHandlerSystem) {
		this = c;
	}

	public inline function onEvent(row:CameraControllerRow,e:hxd.Event):Void {
		this.rowEventHandler(row, e);
	}

	@:from
	static inline function fromCameraControllerEventHandlerSystem(c:CameraControllerEventHandlerSystem): CameraControllerEventHandler {
		return cast c;
	}
}

class CameraControllerEventHandlerSystem {
	final camera: h3d.Camera;
	final sceneEvents: hxd.SceneEvents;
	
	public function new(sceneEvents: hxd.SceneEvents, camera: h3d.Camera) {
		this.sceneEvents = sceneEvents;
		this.camera = camera;
	}

	public function rowEventHandler(row: CameraControllerRow, e: hxd.Event): Void {	
		switch( e.kind ) {
		case EWheel:
			if( hxd.Key.isDown(hxd.Key.CTRL) )
				fov(row, e.wheelDelta * row.fovZoomAmount * 2);
			else
				zoom(row, e.wheelDelta);
		case EPush:
			sceneEvents.startDrag(row.onEvent, function() row.pushing = -1, e);
			row.pushing = e.button;
			push(row, e.relX, e.relY);
		case ERelease, EReleaseOutside:
			if( row.pushing == e.button ) {
				row.pushing = -1;
				sceneEvents.stopDrag();
				final clickDelay = haxe.Timer.stamp() - row.pushTime;
				final pointerDrift = hxd.Math.distance(e.relX - row.pushStartX, e.relY - row.pushStartY);
				// TODO - move threshold constants to tuneables
				if(e.kind == ERelease && clickDelay < 0.2 && pointerDrift < 5) {
					row.onClick(e);
				}
			}
		case EMove:
			switch( row.pushing ) {
			case 0:
				if( hxd.Key.isDown(hxd.Key.ALT) )
					zoom(row, -((e.relX - row.pushX) +  (e.relY - row.pushY)) * 0.03);
				else
					rot(row, e.relX - row.pushX, e.relY - row.pushY);
				push(row, e.relX, e.relY);
			case 1:
				var m = 0.001 * row.curPos.x * row.panSpeed / 25;
				pan(row, camera, -(e.relX - row.pushX) * m, (e.relY - row.pushY) * m);
				push(row, e.relX, e.relY);
			case 2:
				rot(row, e.relX - row.pushX, e.relY - row.pushY);
				push(row, e.relX, e.relY);
			default:
			}
		default:
		}
	}

	static inline function push(row:CameraControllerRow, pushX:Float, pushY:Float) {
		row.pushTime = haxe.Timer.stamp();
		row.pushStartX = row.pushX = pushX;
		row.pushStartY = row.pushY = pushY;
	}

	static function fov(row:CameraControllerRow, delta:Float) {
		final targetOffset = row.targetOffset;
		targetOffset.w += delta;
		if( targetOffset.w >= 179 )
			targetOffset.w = 179;
		if( targetOffset.w < 1 )
			targetOffset.w = 1;
	}

	static function zoom(row:CameraControllerRow, delta:Float) {
		row.targetPos.x *= Math.pow(row.zoomAmount, delta);
	}

	static function rot(row:CameraControllerRow, dx:Float, dy:Float) {
		row.moveX += dx;
		row.moveY += dy;
	}

	static function pan(row:CameraControllerRow, camera:h3d.Camera, dx:Float, dy:Float) {
		var v = new h3d.Vector(dx, dy);
		camera.update();
		v.transform3x3(camera.getInverseView());
		v.w = 0;
		row.targetOffset = row.targetOffset.add(v);
	}
}

abstract CameraControllerId(Int) {
	public inline function new(i: Int) { this = i; }
	public inline function nullOut() { this *= -1; }
	public inline function isNull() { return this <= 0; }
	public inline function isNotNull() { return !isNull(); }

	public static inline function nullRef() { return new CameraControllerId(0); }
}

private abstract CameraControllerInternalId(Int) to Int from Int {
	public inline function new(i: Int) { this = i; }

	public inline function increment() {
		if(this < 0) this *= -1;
		++this;
	}

	@:to
	public inline function toCameraControllerId(): CameraControllerId {
		return cast this;
	}

	@:from
	public static inline function fromCameraControllerId(id: CameraControllerId): CameraControllerInternalId {
		return cast id;
	}
}

typedef CameraEventHandler = (e: hxd.Event) -> Void;

class CameraControllerRow {
	public var id: CameraControllerId;

	public var distance(get, never) : Float;
	public var theta(get, never) : Float;
	public var phi(get, never) : Float;
	public var fovY(get, never) : Float;

	public var targetFovY(get,set) : Float;
	inline function get_targetFovY() return targetOffset.w;
	inline function set_targetFovY(f) return targetOffset.w = Math.min(Math.max(f, 1.), 179);

	public var friction = 0.4;
	public var rotateSpeed = 1.;
	public var zoomAmount = 1.15;
	public var fovZoomAmount = 1.1;
	public var panSpeed = 1.;
	public var smooth = 0.6;

	public var lockZPlanes = false;

	public var pushing = -1;
	public var pushX = 0.;
	public var pushY = 0.;
	public var pushStartX = 0.;
	public var pushStartY = 0.;
	public var moveX = 0.;
	public var moveY = 0.;
	public var pushTime = 0.;
	public var curPos = new h3d.Vector();
	public var curOffset = new h3d.Vector();
	public var targetPos = new h3d.Vector(10. / 25., Math.PI / 4, Math.PI * 5 / 13);
	public var targetOffset = new h3d.Vector(0, 0, 0, 0);

	public var eventHandler: CameraControllerEventHandler;

	inline function get_distance() return curPos.x / curOffset.w;
	inline function get_theta() return curPos.y;
	inline function get_phi() return curPos.z;
	inline function get_fovY() return curOffset.w;
	inline function get_target() return curOffset.toPoint();

	public function new(id:CameraControllerId, rowEventHandler:CameraControllerEventHandler, ?distance: Float) {
		this.id = id;
		this.targetPos.x = distance;
		this.eventHandler = rowEventHandler;
		this.curPos.load(this.targetPos);
		this.curOffset.load(this.targetOffset);
	}

	public function onEvent(e:hxd.Event):Void {
		this.eventHandler.onEvent(this, e);
	}

	/**
		Set this to register an onClick handler
	**/
	public dynamic function onClick(e:hxd.Event) {}
}

/**
	Went overboard with the checks here, especially with the static id
**/
class CameraControllerStorage {
	var currentId: CameraControllerInternalId = CameraControllerId.nullRef();
	var row: CameraControllerRow = null;

	public function new() {}

	public function allocateRow(eventHandler: CameraControllerEventHandler, ?distance: Float):CameraControllerId {
		if( row != null ) {
			throw "CameraController already allocated, must be singleton";
		}
		this.currentId.increment();
		this.row = new CameraControllerRow(this.currentId, eventHandler, distance);

		return this.row.id;
	}

	public function fetchRow(id: CameraControllerId) {
		return row != null && row.id == id ? row : null;
	}

	public function deallocateRow(id: CameraControllerId) {
		if(row.id == id) { row = null; }
	}

	public function reset() {
		this.row = null;
	}
}