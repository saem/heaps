package h3d.scene;
import h3d.scene.SceneStorage.EntityId;

class Light extends h3d.scene.Object {

	private final lRowRef : LightRowRef;
	private final lRow : LightRow;

	final _state: State;

	public var shader(get,never) : hxsl.Shader;
	inline function get_shader() return this._state.shader;

	var objectDistance : Float; // used internaly
	inline function get_objectDistance() return this._state.objectDistance;
	inline function set_objectDistance(o) return this._state.objectDistance = o;
	@:noCompletion public var next : Light; // used internaly (public to allow sorting)
	inline function get_next() return this._state.next;
	inline function set_next(n) return this._state.next = n;

	@:s var cullingDistance : Float = -1;
	inline function get_cullingDistance() return this._state.cullingDistance;
	inline function set_cullingDistance(n) return this._state.cullingDistance = n;
	@:s public var priority : Int = 0;
	inline function get_priority() return this._state.priority;
	inline function set_priority(n) return this._state.priority = n;

	public var color(get, set) : h3d.Vector;
	public var enableSpecular(get, set) : Bool;

	private function new(eid: EntityId, lRowRef:LightRowRef, ?parent) {
		this.lRowRef = lRowRef;
		this._state = this.lRow = lRowRef.getRow();
		super(eid, parent);
	}

	override function onRemove() {
		super.onRemove();
		this.lRowRef.deleteRow();
	}

	// dummy implementation
	function get_color() {
		return new h3d.Vector();
	}

	function set_color(v:h3d.Vector) {
		return v;
	}

	function get_enableSpecular() {
		return false;
	}

	function set_enableSpecular(b) {
		if( b ) throw "Not implemented for this light";
		return false;
	}

	override function emit(ctx:RenderContext.EmitContext) {
		ctx.emitLight(this);
	}

	function getShadowDirection() : h3d.Vector {
		return null;
	}

	#if (hxbit && !macro && heaps_enable_serialize)
	override function customSerialize(ctx:hxbit.Serializer) {
		super.customSerialize(ctx);
		ctx.addDouble(color.x);
		ctx.addDouble(color.y);
		ctx.addDouble(color.z);
		ctx.addDouble(color.w);
		ctx.addBool(enableSpecular);
	}
	override function customUnserialize(ctx:hxbit.Serializer) {
		super.customUnserialize(ctx);
		color.set(ctx.getDouble(), ctx.getDouble(), ctx.getDouble(), ctx.getDouble());
		enableSpecular = ctx.getBool();
	}
	#end
}

typedef State = LightRow;

enum abstract Type(Int) {
	var FwdDir;
	var FwdPoint;
	var PbrDir;
	var PbrPoint;
	var PbrSpot;
}

abstract LightId(Int) to Int {
	public inline function new(id:Int) { this = id; }
}

private abstract InternalLightId(Int) {
	public inline function new(id:Int) { this = id; }
}

class LightRowRef {
	final rowId: LightId;
	final sceneStorage: h3d.scene.SceneStorage;
	
	public function new(rowId: LightId, sceneStorage: h3d.scene.SceneStorage) {
		this.rowId = rowId;
		this.sceneStorage = sceneStorage;
	}

	public inline function getRow() {
		return this.sceneStorage.selectLight(rowId);
	}

	/**
		TODO Leaving this here as it's not a general delete
	**/
	public inline function deleteRow() {
		final eid = this.getRow().entityId;
		this.sceneStorage.lightStorage.deallocateRow(rowId);
		this.sceneStorage.entityStorage.deallocateRow(eid);
	}
}

class LightRow {
	public var id: LightId;
	public var internalId: InternalLightId;
	public var entityId(default,null): h3d.scene.SceneStorage.EntityId;

	// Common
	public final type : Type;
	public final shader : hxsl.Shader;
	public var cullingDistance : Float = -1.;
	public var priority : Int = 0;

	// Common - Internal Usage
	public var objectDistance : Float; // used internaly
	@:noCompletion public var next : Light; // used internaly (public to allow sorting)

	// FWD - Lights have no specific state

	// PBR
	public var color = new h3d.Vector(1,1,1,1);
	public var primitive : h3d.prim.Primitive = null;
	public var power : Float = 1.;
	public var shadows : h3d.pass.Shadows = null;
	public var occlusionFactor : Float = 0.;

	// PBR - PointLight
	public var size : Float = 1.;
	public var zNear : Float = 0.02;

	// PBR - SpotLight
	public var range : Float = 10.;
	public var angle : Float = 45.;
	public var fallOff : Float = 0.;
	public var cookie : h3d.mat.Texture = null;
	public var lightProj = new h3d.Camera();

	// PBR - temps for culling
	public var s = new h3d.col.Sphere(); // Point & Spot
	public var d = new h3d.Vector(); 	 // Spot

	// PBR - DirLight - has no state

	public function new(id:LightId, iid:InternalLightId, eid:h3d.scene.SceneStorage.EntityId, type:Type, shader:hxsl.Shader) {
		this.id = id;
		this.internalId = iid;
		this.entityId = eid;

		this.type = type;
		this.shader = shader;
	}
}

class LightStorage {
	final entityIdToLightIdIndex = new hds.Map<EntityId, LightId>();
	final storage = new hds.Map<InternalLightId, LightRow>();
	var sequence = new SequenceLight();
	
	public function new() {}

	public function allocateRow(eid: h3d.scene.SceneStorage.EntityId, type:Type, shader:hxsl.Shader ) {
		final id = sequence.next();

		this.entityIdToLightIdIndex.set(eid, id);
		final iid = externalToInternalId(id);
		this.storage.set(iid, new LightRow(id, iid, eid, type, shader));

		return id;
	}

	public function deallocateRow(id: LightId) {
		return this.storage.remove(externalToInternalId(id));
	}

	public function fetchRow(id: LightId) {
		return this.storage.get(externalToInternalId(id));
	}

	private inline function externalToInternalId(id: LightId): InternalLightId {
        // make these zero based
		return new InternalLightId(id--);
	}

	public function reset() {
		this.entityIdToLightIdIndex.clear();
		this.storage.clear();
		this.sequence = new SequenceLight();
	}
}

private typedef SequenceLight = h3d.scene.SceneStorage.Sequence<LightId>;