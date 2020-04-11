package h3d.scene;
import hds.Map;

class SceneStorage {
	public final sceneObject: Scene;
    public final entityStorage: EntityStorage = new EntityStorage();
    public final cameraControllerStorage = new CameraController.CameraControllerStorage();
    public final gpuParticleStorage = new h3d.parts.GpuParticles.GpuParticlesStorage();

    public function new(scene: Scene) { this.sceneObject = scene; }
    
    public function insertGpuParticles(): h3d.parts.GpuParticles.GpuParticlesId {
        final eid = this.entityStorage.allocateRow();
        return this.gpuParticleStorage.allocateRow(eid);
	}

    // The return type here isn't the best, return the raw row.
    public function selectGpuParticles(gid: h3d.parts.GpuParticles.GpuParticlesId): h3d.parts.GpuParticles.GpuParticlesRow {
        return this.gpuParticleStorage.fetchRow(gid);
    }

	public function insertCameraController( ?distance ): h3d.scene.CameraController.CameraControllerId {
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
	
	public function reset() {
		this.entityStorage.reset();
		this.cameraControllerStorage.reset();
		this.gpuParticleStorage.reset();
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
abstract Sequence<T>(Int) {
	static final MaxSequence = Math.pow(2, 29) - 1;
	public inline function new() { this = 0; }

	public inline function next(): T {
		if(this == MaxSequence) {
			throw "Ran out of room";
		}

		return cast(++this);
	}
}

abstract EntityId(Int) to Int {
	function new(i: Int) { this = i; }
}

private class EntityStorage {
	final storage = new hds.Map<InternalEntityId, EntityRow>();
	var sequence = new SequenceEntity();

	public function new() {}

	public function allocateRow() {
		final id = sequence.next();
		final iid = externalToInternalId(id);
		this.storage.set(iid, new EntityRow(id, iid));

		return id;
	}

	public function deallocateRow(eid: EntityId) {
		return this.storage.remove(externalToInternalId(eid));
	}

	private inline function externalToInternalId(id: EntityId): InternalEntityId {
        // make these zero based
		return new InternalEntityId(id--);
	}

	public function reset() {
		this.storage.clear();
		this.sequence = new SequenceEntity();
	}
}

private typedef SequenceEntity = Sequence<EntityId>;

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