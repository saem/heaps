package h3d.scene;
import h3d.scene.SceneStorage.EntityId;

/**
	h3d.scene.Mesh is the base class for all 3D objects displayed on screen.
	Unlike Object base class, all properties of Mesh only apply to the current object and are not inherited by its children.
**/
class Mesh extends h3d.scene.Object implements Materialable {

	private final mRowRef : MeshRowRef;
	private final mRow : MeshRow;

	/**
		The primitive of the mesh: the list of vertexes and indices necessary to display the mesh.
	**/
	public var primitive(get,set): h3d.prim.Primitive;

	public var materials(get,set): Array<h3d.mat.Material>;

	/**
		The material of the mesh: the properties used to display it (texture, color, shaders, etc.)
	**/
	public var material(get, set) : h3d.mat.Material;
	
	inline function get_materials() return this.mRow.materials;
	inline function set_materials(m) return this.mRow.materials = m;
	inline function get_primitive() return this.mRow.primitive;
	function set_primitive( prim : h3d.prim.Primitive ) : h3d.prim.Primitive {
		if ( prim != this.mRow.primitive && allocated ) {
			if (this.mRow.primitive != null) this.mRow.primitive.decref();
			if (prim != null) prim.incref();
		}
		return this.mRow.primitive = prim;
	}
	inline function get_material() return this.mRow.material;
	inline function set_material(m) return this.mRow.material = m;

	/**
		Creates a new mesh with given primitive, materials, and parent object.
		If material is not specified, a new default material is created for the current renderer.
	**/
	@:allow(h3d.scene.Scene.createMesh)
	@:allow(h3d.scene.Scene.createMeshWithMaterials)
	private function new( eid: EntityId, mRowRef : MeshRowRef, ?parent : h3d.scene.Object = null ) {
		this.mRowRef = mRowRef;
		this.mRow = mRowRef.getRow();

		super(eid, parent);
	}

	override private function onAdd() {
		super.onAdd();
		if ( primitive != null ) primitive.incref();
	}

	override private function onRemove() {
		if ( primitive != null ) primitive.decref();
		super.onRemove();
		this.mRowRef.deleteRow();
	}

	/**
		Return all materials for the current object.
	**/
	public function getMeshMaterials() {
		return materials.copy();
	}

	override function getBoundsRec( b : h3d.col.Bounds ) {
		b = super.getBoundsRec(b);
		if( primitive == null || ignoreBounds )
			return b;
		var tmp = primitive.getBounds().clone();
		tmp.transform(absPos);
		b.add(tmp);
		return b;
	}

	override function clone( ?o : Cloneable ) : Cloneable {
		var m = o == null ? this.getScene().createMeshWithMaterials(primitive, [], null) : cast o;
		m.materials = [];
		m.primitive = primitive;
		for( mat in materials )
			m.materials.push(if( mat == null ) null else cast mat.clone());
		super.clone(m);
		return m;
	}

	override function getLocalCollider() : h3d.col.Collider {
		return primitive.getCollider();
	}

	override function draw( ctx : RenderContext.DrawContext ) {
		if( materials.length > 1 )
			primitive.selectMaterial(ctx.drawPass.index);

		primitive.render(ctx.engine);

		super.draw(ctx);
	}

	override function emit( ctx : RenderContext.EmitContext ) {
		for( i in 0...materials.length ) {
			var m = materials[i];
			if( m != null )
				ctx.emit(m, this, i);
		}
	}

	override function getMaterialByName( name : String ) : h3d.mat.Material {
		for( m in materials )
			if( m != null && m.name == name )
				return m;
		return super.getMaterialByName(name);
	}

	override function getMaterials( ?a : Array<h3d.mat.Material> ) {
		if( a == null ) a = [];
		for( m in materials )
			if( m != null && a.indexOf(m) < 0 )
				a.push(m);
		for( o in children )
			o.getMaterials(a);
		return super.getMaterials(a);
	}

	#if (hxbit && !macro && heaps_enable_serialize)
	override function customSerialize(ctx:hxbit.Serializer) {
		super.customSerialize(ctx);
		ctx.addKnownRef(primitive);
		ctx.addInt(materials.length);
		for( m in materials ) ctx.addKnownRef(m);
	}
	override function customUnserialize(ctx:hxbit.Serializer) {
		super.customUnserialize(ctx);
		primitive = ctx.getKnownRef(h3d.prim.Primitive);
		materials = [for( i in 0...ctx.getInt() ) ctx.getKnownRef(h3d.mat.Material)];
	}
	#end
}

abstract MeshId(Int) to Int {
	public inline function new(id:Int) { this = id; }
}

private abstract InternalMeshId(Int) {
	public inline function new(id:Int) { this = id; }
}

class MeshRowRef {
	final rowId: MeshId;
	final sceneStorage: h3d.scene.SceneStorage;
	
	public function new(rowId: MeshId, sceneStorage: h3d.scene.SceneStorage) {
		this.rowId = rowId;
		this.sceneStorage = sceneStorage;
	}

	public inline function getRow() {
		return this.sceneStorage.selectMesh(rowId);
	}

	/**
		TODO Leaving this here as it's not a general delete
	**/
	public inline function deleteRow() {
		final eid = this.getRow().entityId;
		this.sceneStorage.meshStorage.deallocateRow(rowId);
		this.sceneStorage.entityStorage.deallocateRow(eid);
	}
}

class MeshRow {
	public var id: MeshId;
	public var internalId: InternalMeshId;
	public var entityId(default,null): h3d.scene.SceneStorage.EntityId;

	/**
		The primitive of the mesh: the list of vertexes and indices necessary to display the mesh.
	**/
	public var primitive : h3d.prim.Primitive = null;

	public var materials = new Array<h3d.mat.Material>();

	/**
		The material of the mesh: the properties used to display it (texture, color, shaders, etc.)
	**/
	public var material(get, set) : h3d.mat.Material;
	inline function get_material() return this.materials[0];
	inline function set_material(m) return this.materials[0] = m;

	public function new(id:MeshId, iid:InternalMeshId, eid:h3d.scene.SceneStorage.EntityId, primitive : h3d.prim.Primitive, ?materials : Array<h3d.mat.Material> = null) {
		this.id = id;
		this.internalId = iid;
		this.entityId = eid;

		this.primitive = primitive;
		this.materials = ( materials == null || materials.length == 0 ) ?
			[h3d.mat.MaterialSetup.current.createMaterial()] :
			materials;
		material.props = material.getDefaultProps();
	}
}

class MeshStorage {
	final entityIdToMeshIdIndex = new hds.Map<EntityId, MeshId>();
	final storage = new hds.Map<InternalMeshId, MeshRow>();
	var sequence = new SequenceMesh();
	
	public function new() {}

	public function allocateRow(eid: h3d.scene.SceneStorage.EntityId, primitive : h3d.prim.Primitive, ?materials : Array<h3d.mat.Material> = null) {
		final id = sequence.next();

		this.entityIdToMeshIdIndex.set(eid, id);
		final iid = externalToInternalId(id);
		this.storage.set(iid, new MeshRow(id, iid, eid, primitive, materials));

		return id;
	}

	public function deallocateRow(id: MeshId) {
		return this.storage.remove(externalToInternalId(id));
	}

	public function deallocateRowByEntityId(id: EntityId) {
		return this.storage.remove(externalToInternalId(this.entityIdToMeshIdIndex[id]));
	}

	public function fetchRow(id: MeshId) {
		return this.storage.get(externalToInternalId(id));
	}

	private inline function externalToInternalId(id: MeshId): InternalMeshId {
        // make these zero based
		return new InternalMeshId(id--);
	}

	public function reset() {
		this.entityIdToMeshIdIndex.clear();
		this.storage.clear();
		this.sequence = new SequenceMesh();
	}
}

private typedef SequenceMesh = h3d.scene.SceneStorage.Sequence<MeshId>;