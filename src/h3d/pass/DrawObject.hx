package h3d.pass;

import h3d.scene.SceneStorage.EntityId;

typedef DrawObject = {
	public var absPos(get,never): h3d.Matrix;
	public var lightCameraCenter(get, never): Bool;
	public var cullingCollider(get, never): h3d.col.Collider;
	public final id: EntityId;
	public function getInvPos(): Matrix;
};