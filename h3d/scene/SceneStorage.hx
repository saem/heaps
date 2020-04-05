package h3d.scene;

class SceneStorage {
	public final sceneObject: Scene;
    public final entityStorage: EntityStorage = new EntityStorage();
    public final cameraControllerStorage = new CameraController.CameraControllerStorage();

	public function new(scene: Scene) { this.sceneObject = scene; }

	public function insertCameraController( ?distance ) {
        final eid = this.entityStorage.allocateRow();
        final ccid = this.cameraControllerStorage.allocateRow(eid, this.sceneObject, distance);

        // Crappy On Insert Trigger
        final ccr = cameraControllerStorage.fetchRow(ccid);
        ccr.onAdd(this.sceneObject, this.sceneObject.camera);

        return ccid;
    }
    
    public function deleteCameraController(ccid) {
        // Crappy On Delete Trigger
        final cc = this.cameraControllerStorage.fetchRow(ccid);
        if(cc != null) {
            cc.onRemove(this.sceneObject);
            this.cameraControllerStorage.deallocateRow(ccid);
        }
    }

    public inline function selectCameraController(ccid) {
        return this.cameraControllerStorage.fetchRow(ccid);
    }
}

abstract EntityId(Int) to Int {
	function new(i: Int) { this = i; }
}

private class EntityStorage {
	final storage = new Map<InternalEntityId, EntityRow>();
	var entitySequence = new SequenceEntity();

	public function new() {}

	public function allocateRow() {
		final id = entitySequence.next();
		final iid = entityIdToInternalId(id);
		this.storage.set(iid, new EntityRow(id, iid));

		return id;
	}

	private inline function entityIdToInternalId(id: EntityId): InternalEntityId {
        // make these zero based
		return new InternalEntityId(id--);
	}
}

/**
	Use 31 bit signed integers, due to V8:
	* V8 is optimized when it comes to storing signed 31 bit integers
	* See Smi described here: https://v8.dev/blog/react-cliff
	* Non-Smi object properties will indirect

	Bits     | Purpose
	-------------------------------------------
	Sign     | Mark Deleted[1] 
	1-bit    | Is Allocated
	29-bits  | Array Index

	Another way to look at it would be a 30 bit Int.

	[1]: Use < 0 comparisons, bitwise Ops in JS are signed
**/
private abstract SequenceEntity(Int) to Int {
	static final MaxSequence = Math.pow(2, 29) - 1;
	public inline function new() { this = 0; }

	public inline function next(): EntityId {
		if(this == MaxSequence) {
			throw "Ran out of room";
		}

		return @:privateAccess new EntityId(++this);
	}
}

private class EntityRow {
	public var id: EntityId;
	public var iid: InternalEntityId;

	public function new(id: EntityId, iid: InternalEntityId) {
		this.id = id;
		this.iid = iid;
	}
}

private abstract InternalEntityId(Int) {
	public function new(i: Int = 0) { this = i; }
}