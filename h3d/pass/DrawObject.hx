package h3d.pass;

typedef DrawObject = {
	public var absPos(default, null): h3d.Matrix;
	public var lightCameraCenter(get, never): Bool;
	public var cullingCollider(default, never): h3d.col.Collider;
	public final id: Int;
	public function getInvPos(): Matrix;
};