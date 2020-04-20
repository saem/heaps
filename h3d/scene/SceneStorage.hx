package h3d.scene;
import hds.Map;

class SceneStorage {
    public final entityStorage: EntityStorage = new EntityStorage();
    public final cameraControllerStorage = new CameraController.CameraControllerStorage();
    public final meshStorage = new h3d.scene.Mesh.MeshStorage();
    public final gpuParticleStorage = new h3d.parts.GpuParticles.GpuParticlesStorage();
    public final emitterStorage = new h3d.parts.Emitter.EmitterStorage();
    public final particlesStorage = new h3d.parts.Particles.ParticlesStorage();
    public final skinStorage = new h3d.scene.Skin.SkinStorage();
    public final skinJointStorage = new h3d.scene.Skin.SkinJointStorage();
    public final lightStorage = new h3d.scene.Light.LightStorage();
    public final graphicsStorage = new h3d.scene.Graphics.GraphicsStorage();
    public final boxStorage = new h3d.scene.Box.BoxStorage();
    public final sphereStorage = new h3d.scene.Sphere.SphereStorage();
    public final decalStorage = new h3d.scene.pbr.Decal.DecalStorage();
    public final worldStorage = new h3d.scene.World.WorldStorage();

    public final relativePositionStorage = new h3d.scene.Object.RelativePositionStorage();
    public final animationStorage = new h3d.scene.Object.AnimationStorage();

	public function new() {}
	
	public function insertEntity(): EntityId {
		return this.entityStorage.allocateRow();
    }
    
    public function insertRelativePosition(eid: EntityId) {
        return this.relativePositionStorage.allocateRow(eid);
    }

    public function selectRelativePosition(id: h3d.scene.Object.RelativePositionId) {
        return this.relativePositionStorage.fetchRow(id);
    }
    
    public function insertAnimation(eid: EntityId) {
        return this.animationStorage.allocateRow(eid);
    }

    public function selectAnimation(id: h3d.scene.Object.AnimationId) {
        return this.animationStorage.fetchRow(id);
    }
    
    public function insertMesh(eid: EntityId, primitive: h3d.prim.Primitive, materials: Array<h3d.mat.Material>): h3d.scene.Mesh.MeshId {
        return this.meshStorage.allocateRow(eid, primitive, materials);
	}

    // The return type here isn't the best, return the raw row.
    public function selectMesh(gid: h3d.scene.Mesh.MeshId): h3d.scene.Mesh.MeshRow {
        return this.meshStorage.fetchRow(gid);
    }
    
    public function insertSkin(eid: EntityId, skinData: h3d.anim.Skin): h3d.scene.Skin.SkinId {
        return this.skinStorage.allocateRow(eid, skinData);
	}

    // The return type here isn't the best, return the raw row.
    public function selectSkin(gid: h3d.scene.Skin.SkinId): h3d.scene.Skin.SkinRow {
        return this.skinStorage.fetchRow(gid);
    }
    
    public function insertSkinJoint(eid: EntityId, skin: h3d.scene.Skin, name: String, index: Int): h3d.scene.Skin.SkinJointId {
        return this.skinJointStorage.allocateRow(eid, skin, name, index);
	}

    // The return type here isn't the best, return the raw row.
    public function selectSkinJoint(gid: h3d.scene.Skin.SkinJointId): h3d.scene.Skin.SkinJointRow {
        return this.skinJointStorage.fetchRow(gid);
    }
    
    public function insertLight(eid: EntityId, type:h3d.scene.Light.Type, shader:hxsl.Shader): h3d.scene.Light.LightId {
        return this.lightStorage.allocateRow(eid, type, shader);
	}

    // The return type here isn't the best, return the raw row.
    public function selectLight(id: h3d.scene.Light.LightId): h3d.scene.Light.LightRow {
        return this.lightStorage.fetchRow(id);
    }
    
    public function insertGraphics(eid: EntityId): h3d.scene.Graphics.GraphicsId {
        return this.graphicsStorage.allocateRow(eid);
	}

    // The return type here isn't the best, return the raw row.
    public function selectGraphics(gid: h3d.scene.Graphics.GraphicsId): h3d.scene.Graphics.GraphicsRow {
        return this.graphicsStorage.fetchRow(gid);
    }
    
    public function insertBox(eid: EntityId, colour: UInt, bounds: h3d.col.Bounds): h3d.scene.Box.BoxId {
        return this.boxStorage.allocateRow(eid, colour, bounds);
	}

    // The return type here isn't the best, return the raw row.
    public function selectBox(gid: h3d.scene.Box.BoxId): h3d.scene.Box.BoxRow {
        return this.boxStorage.fetchRow(gid);
    }
    
    public function insertSphere(eid: EntityId, colour: Int, radius: Float): h3d.scene.Sphere.SphereId {
        return this.sphereStorage.allocateRow(eid, colour, radius);
	}

    // The return type here isn't the best, return the raw row.
    public function selectSphere(gid: h3d.scene.Sphere.SphereId): h3d.scene.Sphere.SphereRow {
        return this.sphereStorage.fetchRow(gid);
    }
    
    public function insertDecal(eid: EntityId): h3d.scene.pbr.Decal.DecalId {
        return this.decalStorage.allocateRow(eid);
	}

    // The return type here isn't the best, return the raw row.
    public function selectDecal(gid: h3d.scene.pbr.Decal.DecalId): h3d.scene.pbr.Decal.DecalRow {
        return this.decalStorage.fetchRow(gid);
    }

    public function insertWorld(eid: EntityId, chunkSize: Int, worldSize: Int, ?autoCollect: Bool = true): h3d.scene.World.WorldId {
        return this.worldStorage.allocateRow(eid, chunkSize, worldSize, autoCollect);
	}

    // The return type here isn't the best, return the raw row.
    public function selectWorld(id: h3d.scene.World.WorldId): h3d.scene.World.WorldRow {
        return this.worldStorage.fetchRow(id);
    }
    
    public function insertGpuParticles(eid: EntityId): h3d.parts.GpuParticles.GpuParticlesId {
        return this.gpuParticleStorage.allocateRow(eid);
	}

    // The return type here isn't the best, return the raw row.
    public function selectGpuParticles(gid: h3d.parts.GpuParticles.GpuParticlesId): h3d.parts.GpuParticles.GpuParticlesRow {
        return this.gpuParticleStorage.fetchRow(gid);
    }
    
    public function insertParticles(eid: EntityId, ?texture: h3d.mat.Texture = null): h3d.parts.Particles.ParticlesId {
		return this.particlesStorage.allocateRow(eid, texture);
	}

    // The return type here isn't the best, return the raw row.
    public function selectParticles(id: h3d.parts.Particles.ParticlesId): h3d.parts.Particles.ParticlesRow {
        return this.particlesStorage.fetchRow(id);
    }
    
    public function insertEmitter(eid: EntityId, state:h3d.parts.Data.State = null): h3d.parts.Emitter.EmitterId {
		return this.emitterStorage.allocateRow(eid,state);
	}

    // The return type here isn't the best, return the raw row.
    public function selectEmitter(id: h3d.parts.Emitter.EmitterId): h3d.parts.Emitter.EmitterRow {
        return this.emitterStorage.fetchRow(id);
    }

	public function insertCameraController(eventHandler: h3d.scene.CameraController.CameraControllerEventHandler, ?distance: Float): h3d.scene.CameraController.CameraControllerId {
       return this.cameraControllerStorage.allocateRow(eventHandler, distance);
    }

    public inline function selectCameraController(ccid) {
        return this.cameraControllerStorage.fetchRow(ccid);
	}
	
	public function reset() {
		this.entityStorage.reset();
		this.cameraControllerStorage.reset();
		this.meshStorage.reset();
		this.gpuParticleStorage.reset();
		this.particlesStorage.reset();
		this.emitterStorage.reset();
		this.skinStorage.reset();
		this.skinJointStorage.reset();
		this.graphicsStorage.reset();
		this.boxStorage.reset();
		this.sphereStorage.reset();
		this.decalStorage.reset();
		this.worldStorage.reset();
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