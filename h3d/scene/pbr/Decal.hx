package h3d.scene.pbr;
import h3d.scene.SceneStorage.EntityId;

class Decal extends Mesh {

	private final dRowRef : DecalRowRef;
	private final dRow : DecalRow;

	@:allow(h3d.scene.Scene.createPbrDecal)
	private function new( eid: EntityId, dRowRef: DecalRowRef, mRowRef: h3d.scene.Mesh.MeshRowRef, ?parent : h3d.scene.Object ) {
		this.dRowRef = dRowRef;
		this.dRow = dRowRef.getRow();

		super(eid, mRowRef, parent);
		this.objectType = h3d.scene.Object.ObjectType.TPbrDecal;
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

abstract DecalId(Int) to Int {
	public inline function new(id:Int) { this = id; }
}

private abstract InternalDecalId(Int) {
	public inline function new(id:Int) { this = id; }
}

class DecalRowRef {
	final rowId: DecalId;
	final sceneStorage: h3d.scene.SceneStorage;
	
	public function new(rowId: DecalId, sceneStorage: h3d.scene.SceneStorage) {
		this.rowId = rowId;
		this.sceneStorage = sceneStorage;
	}

	public inline function getRow() {
		return this.sceneStorage.selectDecal(rowId);
	}

	/**
		TODO Leaving this here as it's not a general delete
	**/
	public inline function deleteRow() {
		final eid = this.getRow().entityId;
		this.sceneStorage.decalStorage.deallocateRow(rowId);
		this.sceneStorage.entityStorage.deallocateRow(eid);
	}
}

class DecalRow {
	public var id: DecalId;
	public var internalId: InternalDecalId;
	public var entityId(default,null): h3d.scene.SceneStorage.EntityId;

	public function new(id:DecalId, iid:InternalDecalId, eid:h3d.scene.SceneStorage.EntityId) {
		this.id = id;
		this.internalId = iid;
		this.entityId = eid;
	}
}

class DecalStorage {
	final entityIdToDecalIdIndex = new hds.Map<EntityId, DecalId>();
	final storage = new hds.Map<InternalDecalId, DecalRow>();
	var sequence = new SequenceDecal();
	
	public function new() {}

	public function allocateRow(eid: h3d.scene.SceneStorage.EntityId) {
		final id = sequence.next();

		this.entityIdToDecalIdIndex.set(eid, id);
		final iid = externalToInternalId(id);
		this.storage.set(iid, new DecalRow(id, iid, eid));

		return id;
	}

	public function deallocateRow(id: DecalId) {
		return this.storage.remove(externalToInternalId(id));
	}

	public function deallocateRowByEntityId(id: EntityId) {
		return this.storage.remove(externalToInternalId(this.entityIdToDecalIdIndex[id]));
	}

	public function fetchRow(id: DecalId) {
		return this.storage.get(externalToInternalId(id));
	}

	private inline function externalToInternalId(id: DecalId): InternalDecalId {
        // make these zero based
		return new InternalDecalId(id--);
	}

	public function reset() {
		this.entityIdToDecalIdIndex.clear();
		this.storage.clear();
		this.sequence = new SequenceDecal();
	}
}

private typedef SequenceDecal = h3d.scene.SceneStorage.Sequence<DecalId>;