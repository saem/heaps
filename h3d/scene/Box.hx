package h3d.scene;
import h3d.scene.SceneStorage.EntityId;

class Box extends Graphics {

	private final bRowRef : BoxRowRef;
	private final bRow : BoxRow;

	@:allow(h3d.scene.Scene.createBox)
	private function new( bRowRef : BoxRowRef, gRowRef : Graphics.GraphicsRowRef, ?depth : Bool = true, ?parent : Object = null) {
		this.bRowRef = bRowRef;
		this.bRow = bRowRef.getRow();

		super(gRowRef, parent);
		if( !depth ) material.mainPass.depth(true, Always);
	}

	public override function clone( ?o : h3d.scene.Object ) : h3d.scene.Object {
		var b = o == null ? this.getScene().createBox(this.bRow.color, this.bRow.bounds.clone(), this.material.mainPass.depthWrite, null) : cast o;
		super.clone(b);
		b.bRow.bounds = this.bRow.bounds.clone();
		b.bRow.prevXMin = this.bRow.prevXMin;
		b.bRow.prevYMin = this.bRow.prevYMin;
		b.bRow.prevZMin = this.bRow.prevZMin;
		b.bRow.prevXMax = this.bRow.prevXMax;
		b.bRow.prevYMax = this.bRow.prevYMax;
		b.bRow.prevZMax = this.bRow.prevZMax;
		return b;
	}

	override function getLocalCollider() {
		return null;
	}

	override function sync(ctx) {
		if( this.bRow.bounds == null ) {
			if( this.bRow.prevXMin == -0.5 && this.bRow.prevYMin == -0.5 && this.bRow.prevZMin == -0.5 && this.bRow.prevXMax == 0.5 && this.bRow.prevYMax == 0.5 && this.bRow.prevZMax == 0.5 )
				return;
			this.bRow.prevXMin = -0.5;
			this.bRow.prevYMin = -0.5;
			this.bRow.prevZMin = -0.5;
			this.bRow.prevXMax = 0.5;
			this.bRow.prevYMax = 0.5;
			this.bRow.prevZMax = 0.5;
		} else {
			if( this.bRow.prevXMin == this.bRow.bounds.xMin && this.bRow.prevYMin == this.bRow.bounds.yMin && this.bRow.prevZMin == this.bRow.bounds.zMin && this.bRow.prevXMax == this.bRow.bounds.xMax && this.bRow.prevYMax == this.bRow.bounds.yMax && this.bRow.prevZMax == this.bRow.bounds.zMax )
				return;
			this.bRow.prevXMin = this.bRow.bounds.xMin;
			this.bRow.prevYMin = this.bRow.bounds.yMin;
			this.bRow.prevZMin = this.bRow.bounds.zMin;
			this.bRow.prevXMax = this.bRow.bounds.xMax;
			this.bRow.prevYMax = this.bRow.bounds.yMax;
			this.bRow.prevZMax = this.bRow.bounds.zMax;
		}
		clear();
		lineStyle(this.bRow.thickness, this.bRow.color);
		moveTo(this.bRow.prevXMin, this.bRow.prevYMin, this.bRow.prevZMin);
		lineTo(this.bRow.prevXMax, this.bRow.prevYMin, this.bRow.prevZMin);
		lineTo(this.bRow.prevXMax, this.bRow.prevYMax, this.bRow.prevZMin);
		lineTo(this.bRow.prevXMin, this.bRow.prevYMax, this.bRow.prevZMin);
		lineTo(this.bRow.prevXMin, this.bRow.prevYMin, this.bRow.prevZMin);
		lineTo(this.bRow.prevXMin, this.bRow.prevYMin, this.bRow.prevZMax);
		lineTo(this.bRow.prevXMax, this.bRow.prevYMin, this.bRow.prevZMax);
		lineTo(this.bRow.prevXMax, this.bRow.prevYMax, this.bRow.prevZMax);
		lineTo(this.bRow.prevXMin, this.bRow.prevYMax, this.bRow.prevZMax);
		lineTo(this.bRow.prevXMin, this.bRow.prevYMin, this.bRow.prevZMax);

		moveTo(this.bRow.prevXMax, this.bRow.prevYMin, this.bRow.prevZMin);
		lineTo(this.bRow.prevXMax, this.bRow.prevYMin, this.bRow.prevZMax);
		moveTo(this.bRow.prevXMin, this.bRow.prevYMax, this.bRow.prevZMin);
		lineTo(this.bRow.prevXMin, this.bRow.prevYMax, this.bRow.prevZMax);
		moveTo(this.bRow.prevXMax, this.bRow.prevYMax, this.bRow.prevZMin);
		lineTo(this.bRow.prevXMax, this.bRow.prevYMax, this.bRow.prevZMax);

		super.sync(ctx);
	}
}

abstract BoxId(Int) to Int {
	public inline function new(id:Int) { this = id; }
}

private abstract InternalBoxId(Int) {
	public inline function new(id:Int) { this = id; }
}

class BoxRowRef {
	final rowId: BoxId;
	final sceneStorage: h3d.scene.SceneStorage;
	
	public function new(rowId: BoxId, sceneStorage: h3d.scene.SceneStorage) {
		this.rowId = rowId;
		this.sceneStorage = sceneStorage;
	}

	public inline function getRow() {
		return this.sceneStorage.selectBox(rowId);
	}

	/**
		TODO Leaving this here as it's not a general delete
	**/
	public inline function deleteRow() {
		final eid = this.getRow().entityId;
		this.sceneStorage.boxStorage.deallocateRow(rowId);
		this.sceneStorage.graphicsStorage.deallocateRowByEntityId(eid);
		this.sceneStorage.entityStorage.deallocateRow(eid);
	}
}

class BoxRow {
	public var id: BoxId;
	public var internalId: InternalBoxId;
	public var entityId(default,null): h3d.scene.SceneStorage.EntityId;

	public var color : Int;
	public var bounds : h3d.col.Bounds;
	public var thickness = 1.0;
	public var prevXMin = 1e9;
	public var prevYMin = 1e9;
	public var prevZMin = 1e9;
	public var prevXMax = -1e9;
	public var prevYMax = -1e9;
	public var prevZMax = -1e9;

	/**
		Setting is3D to true will switch from a screen space line (constant size whatever the distance) to a world space line
	**/
	public var is3D : Bool = true;

	public function new(id:BoxId, iid:InternalBoxId, eid:h3d.scene.SceneStorage.EntityId, ?color = 0xFFFF0000, ?bounds : h3d.col.Bounds = null) {
		this.id = id;
		this.internalId = iid;
		this.entityId = eid;

		this.color = color;
		this.bounds = bounds;
	}
}

class BoxStorage {
	final entityIdToBoxIdIndex = new hds.Map<EntityId, BoxId>();
	final storage = new hds.Map<InternalBoxId, BoxRow>();
	var sequence = new SequenceBox();
	
	public function new() {}

	public function allocateRow(eid: h3d.scene.SceneStorage.EntityId) {
		final id = sequence.next();

		this.entityIdToBoxIdIndex.set(eid, id);
		final iid = externalToInternalId(id);
		this.storage.set(iid, new BoxRow(id, iid, eid));

		return id;
	}

	public function deallocateRow(id: BoxId) {
		return this.storage.remove(externalToInternalId(id));
	}

	public function fetchRow(id: BoxId) {
		return this.storage.get(externalToInternalId(id));
	}

	private inline function externalToInternalId(id: BoxId): InternalBoxId {
        // make these zero based
		return new InternalBoxId(id--);
	}

	public function reset() {
		this.entityIdToBoxIdIndex.clear();
		this.storage.clear();
		this.sequence = new SequenceBox();
	}
}

private typedef SequenceBox = h3d.scene.SceneStorage.Sequence<BoxId>;