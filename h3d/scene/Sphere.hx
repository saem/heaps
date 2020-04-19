package h3d.scene;
import h3d.scene.SceneStorage.EntityId;

class Sphere extends Graphics {

	private final sRowRef : SphereRowRef;
	private final sRow : SphereRow;

	public var color(get,set) : Int;
	public var radius(get, set) : Float;

	@:allow(h3d.scene.Scene.createSphere)
	private function new( eid : EntityId, sRowRef : SphereRowRef, gRowRef : Graphics.GraphicsRowRef, mRowRef : h3d.scene.Mesh.MeshRowRef, ?depth : Bool = true, ?parent : Object ) {
		this.sRowRef = sRowRef;
		this.sRow = this.sRowRef.getRow();

		super(eid, gRowRef, mRowRef, parent);

		if( !depth ) material.mainPass.depth(true, Always);
	}

	override function onRemove() {
		this.sRowRef.deleteRow();
	}

	inline function get_color():Int return this.sRow.colour;
	inline function set_color(c):Int return this.sRow.colour = c;
	inline function get_radius():Float return this.sRow.radius;
	function set_radius(v: Float) {
		this.sRow.radius = v;
		refresh();
		return v;
	}

	function refresh() {
		clear();
		lineStyle(1, color);

		var nsegments = 32;

		inline function circle(f) {
			for(i in 0...nsegments) {
				var c = hxd.Math.cos(i / (nsegments - 1) * hxd.Math.PI * 2.0) * radius;
				var s = hxd.Math.sin(i / (nsegments - 1) * hxd.Math.PI * 2.0) * radius;
				f(i, c, s);
			}
		}
		inline function seg(i, x, y, z) {
			if(i == 0)
				moveTo(x, y, z);
			else
				lineTo(x, y, z);
		}

		circle(function(i, c, s) return seg(i, c, s, 0));
		circle(function(i, c, s) return seg(i, 0, c, s));
		circle(function(i, c, s) return seg(i, c, 0, s));
	}

	override function getLocalCollider() {
		return null;
	}
}

abstract SphereId(Int) to Int {
	public inline function new(id:Int) { this = id; }
}

private abstract InternalSphereId(Int) {
	public inline function new(id:Int) { this = id; }
}

class SphereRowRef {
	final rowId: SphereId;
	final sceneStorage: h3d.scene.SceneStorage;
	
	public function new(rowId: SphereId, sceneStorage: h3d.scene.SceneStorage) {
		this.rowId = rowId;
		this.sceneStorage = sceneStorage;
	}

	public inline function getRow() {
		return this.sceneStorage.selectSphere(rowId);
	}

	/**
		TODO Leaving this here as it's not a general delete
	**/
	public inline function deleteRow() {
		final eid = this.getRow().entityId;
		this.sceneStorage.sphereStorage.deallocateRow(rowId);
		this.sceneStorage.graphicsStorage.deallocateRowByEntityId(eid);
		this.sceneStorage.entityStorage.deallocateRow(eid);
	}
}

class SphereRow {
	public var id: SphereId;
	public var internalId: InternalSphereId;
	public var entityId(default,null): h3d.scene.SceneStorage.EntityId;

	public var colour : Int;
	public var radius : Float;

	public function new(id:SphereId, iid:InternalSphereId, eid:h3d.scene.SceneStorage.EntityId, colour = 0xFFFF0000, radius : Float = 1.0) {
		this.id = id;
		this.internalId = iid;
		this.entityId = eid;

		this.colour = colour;
		this.radius = radius;
	}
}

class SphereStorage {
	final entityIdToSphereIdIndex = new hds.Map<EntityId, SphereId>();
	final storage = new hds.Map<InternalSphereId, SphereRow>();
	var sequence = new SequenceSphere();
	
	public function new() {}

	public function allocateRow(eid: h3d.scene.SceneStorage.EntityId, colour: Int, radius: Float) {
		final id = sequence.next();

		this.entityIdToSphereIdIndex.set(eid, id);
		final iid = externalToInternalId(id);
		this.storage.set(iid, new SphereRow(id, iid, eid, colour, radius));

		return id;
	}

	public function deallocateRow(id: SphereId) {
		return this.storage.remove(externalToInternalId(id));
	}

	public function fetchRow(id: SphereId) {
		return this.storage.get(externalToInternalId(id));
	}

	private inline function externalToInternalId(id: SphereId): InternalSphereId {
        // make these zero based
		return new InternalSphereId(id--);
	}

	public function reset() {
		this.entityIdToSphereIdIndex.clear();
		this.storage.clear();
		this.sequence = new SequenceSphere();
	}
}

private typedef SequenceSphere = h3d.scene.SceneStorage.Sequence<SphereId>;