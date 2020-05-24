package h3d.pass;

import h3d.scene.SceneStorage.EntityId;

class DrawObject {
	public final id: EntityId;
	public final command: DrawCommand;

	public var absPos(get, never): h3d.Matrix;
	inline function get_absPos() return this.sceneObject.absPos;
	public var lightCameraCenter(get, never): Bool;
	inline function get_lightCameraCenter() return this.sceneObject.lightCameraCenter;
	public var cullingCollider(get, never): h3d.col.Collider;
	inline function get_cullingCollider() return this.sceneObject.cullingCollider;

	public final sceneObject: h3d.scene.Object;
	public function new(sceneObject: h3d.scene.Object, command: DrawCommand) {
		this.sceneObject = sceneObject;
		this.id = this.sceneObject.id;
		this.command = command;
	}

	public inline function getInvPos(): Matrix return this.sceneObject.getInvPos();
}

enum DrawCommand {
	Legacy;
}