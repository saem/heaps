package h3d.scene;
import hxd.Math;
import h3d.scene.SceneStorage.EntityId;

private class GPoint {
	public var x : Float;
	public var y : Float;
	public var z : Float;
	public var r : Float;
	public var g : Float;
	public var b : Float;
	public var a : Float;
	public function new(x, y, z, r, g, b, a) {
		this.x = x;
		this.y = y;
		this.z = z;
		this.r = r;
		this.g = g;
		this.b = b;
		this.a = a;
	}
}

class Graphics extends Object implements Materialable {

	private final gRowRef : GraphicsRowRef;
	@:allow(h3d.scene.Scene)
	private final gRow : GraphicsModule;

	public var materials(get,set): Array<h3d.mat.Material>;
	inline function get_materials() return [this.gRow.material];
	inline function set_materials(m) return [this.gRow.material = m[0]];

	/**
		The material of the Graphics: the properties used to display it (texture, color, shaders, etc.)
	**/
	public var material(get, set) : h3d.mat.Material;
	inline function get_material() return this.gRow.material;
	inline function set_material(m) return this.gRow.material = m;

	/**
		Setting is3D to true will switch from a screen space line (constant size whatever the distance) to a world space line
	**/
	public var is3D(get, set) : Bool;

	@:allow(h3d.scene.Scene.createGraphics)
	private function new(eid:EntityId, gRowRef:GraphicsRowRef, ?parent:h3d.scene.Object = null) {
		this.gRowRef = gRowRef;
		this.gRow = this.gRowRef.getRow();

		super(eid, parent);
		this.objectType = Object.ObjectType.TGraphics;
	}

	inline function get_is3D() : Bool return this.gRow.is3D;
	function set_is3D(v) : Bool return this.gRow.is3D = v;

	override function onRemove() {
		super.onRemove();
		this.gRow.bprim.clear();
		this.gRowRef.deleteRow();
	}

	public static function syncGraphics(gRow:GraphicsModule) {
		gRow.flush();
		gRow.bprim.flush();
	}

	override function draw( ctx : RenderContext.DrawContext ) {
		flush();
		this.gRow.bprim.flush();
		this.gRow.bprim.render(ctx.engine);
		super.draw(ctx);
	}

	override function getMaterialByName( name : String ) : h3d.mat.Material {
		if( this.material != null && this.material.name == name )
			return this.material;
		return super.getMaterialByName(name);
	}

	override function getMaterials( ?a : Array<h3d.mat.Material> ) {
		if( a == null ) a = [];
		if( this.material != null && a.indexOf(this.material) < 0 )
			a.push(this.material);
		for( o in children )
			o.getMaterials(a);
		return super.getMaterials(a);
	}

	public function clear() {
		this.gRow.clear();
	}

	function flush() {
		this.gRow.flush();
	}

	public function lineStyle( size = 0., color = 0, alpha = 1. ) {
		this.gRow.lineStyle(size, color, alpha);
	}

	public function setColor( color : Int, alpha = 1. ) {
		this.gRow.setColor(color, alpha);
	}

	public inline function drawLine( p1 : h3d.col.Point, p2 : h3d.col.Point ) {
		this.gRow.drawLine(p1, p2);
	}

	public function moveTo( x : Float, y : Float, z : Float ) {
		this.gRow.moveTo(x, y, z);
	}

	public function lineTo( x : Float, y : Float, z : Float ) {
		this.gRow.lineTo(x,y,z);
	}

	#if (hxbit && !macro && heaps_enable_serialize)
	override function customUnserialize(ctx:hxbit.Serializer) {
		super.customUnserialize(ctx);
		lineShader = material.mainPass.getShader(h3d.shader.LineShader);
		tmpPoints = [];
		bprim = cast primitive;
	}
	#end
}

abstract GraphicsId(Int) to Int {
	public inline function new(id:Int) { this = id; }
}

private abstract InternalGraphicsId(Int) {
	public inline function new(id:Int) { this = id; }
}

class GraphicsRowRef {
	final rowId: GraphicsId;
	final sceneStorage: h3d.scene.SceneStorage;
	
	public function new(rowId: GraphicsId, sceneStorage: h3d.scene.SceneStorage) {
		this.rowId = rowId;
		this.sceneStorage = sceneStorage;
	}

	public inline function getRow() {
		return this.sceneStorage.selectGraphics(rowId);
	}

	/**
		TODO Leaving this here as it's not a general delete
	**/
	public inline function deleteRow() {
		final eid = this.getRow().entityId;
		this.sceneStorage.graphicsStorage.deallocateRow(rowId);
		this.sceneStorage.entityStorage.deallocateRow(eid);
	}
}

@:forward(bprim, material)
abstract GraphicsModule(GraphicsRow) to GraphicsRow from GraphicsRow {
	public var is3D(get,set): Bool;

	/**
		The material of the Graphics: the properties used to display it (texture, color, shaders, etc.)
	**/
	public var material(get, set) : h3d.mat.Material;
	inline function get_material() return this.material;
	inline function set_material(m) return this.material = m;

	inline function get_is3D() : Bool return this.is3D;
	function set_is3D(v) {
		if( this.is3D == v )
			return v;
		if( v ) {
			this.material.mainPass.removeShader(this.lineShader);
		} else {
			this.material.mainPass.addShader(this.lineShader);
		}
		this.bprim.clear();
		this.tmpPoints.resize(0);
		return this.is3D = v;
	}

	public inline function lineStyle( size = 0., color = 0, alpha = 1. ) {
		flush();
		if( size > 0 && this.lineSize != size ) {
			this.lineSize = size;
			if( !is3D ) this.lineShader.width = this.lineSize;
		}
		setColor(color, alpha);
	}

	public inline function setColor( color : Int, alpha = 1. ) {
		this.curA = alpha;
		this.curR = ((color >> 16) & 0xFF) / 255.;
		this.curG = ((color >> 8) & 0xFF) / 255.;
		this.curB = (color & 0xFF) / 255.;
	}

	public inline function drawLine( p1 : h3d.col.Point, p2 : h3d.col.Point ) {
		moveTo(p1.x, p1.y, p1.z);
		lineTo(p2.x, p2.y, p2.z);
	}

	public inline function moveTo( x : Float, y : Float, z : Float ) {
		if( is3D ) {
			flush();
			lineTo(x, y, z);
		} else {
			this.curX = x;
			this.curY = y;
			this.curZ = z;
		}
	}

	public inline function lineTo( x : Float, y : Float, z : Float ) {
		if( is3D ) {
			addVertex(x, y, z, this.curR, this.curG, this.curB, this.curA);
			return;
		}

		this.bprim.begin(4,6);
		var nx = x - this.curX;
		var ny = y - this.curY;
		var nz = z - this.curZ;

		this.bprim.addBounds(this.curX, this.curY, this.curZ);
		this.bprim.addBounds(x, y, z);

		inline function push(v) {
			this.bprim.addVertexValue(v);
		}

		inline function add(u, v) {
			push(this.curX);
			push(this.curY);
			push(this.curZ);

			push(nx);
			push(ny);
			push(nz);

			push(u);
			push(v);

			push(this.curR);
			push(this.curG);
			push(this.curB);
			push(this.curA);
		}

		add(0, 0);
		add(0, 1);
		add(1, 0);
		add(1, 1);

		this.bprim.addIndex(0);
		this.bprim.addIndex(1);
		this.bprim.addIndex(2);
		this.bprim.addIndex(2);
		this.bprim.addIndex(3);
		this.bprim.addIndex(1);

		this.curX = x;
		this.curY = y;
		this.curZ = z;
	}

	public inline function clear() {
		flush();
		this.bprim.clear();
	}

	inline function addVertex( x, y, z, r, g, b, a ) {
		this.tmpPoints.push(new GPoint(x, y, z, r, g, b, a));
	}

	public function flush() {
		if( this.tmpPoints.length == 0 )
			return;
		if( is3D ) {
			flushLine();
			this.tmpPoints.resize(0);
		}
	}

	function flushLine() {
		var pts = this.tmpPoints;

		var last = pts.length - 1;
		var prev = pts[last];
		var p = pts[0];

		var closed = p.x == prev.x && p.y == prev.y && p.z == prev.z;
		var count = pts.length;
		if( !closed ) {
			var prevLast = pts[last - 1];
			if( prevLast == null ) prevLast = p;
			pts.push(new GPoint(prev.x * 2 - prevLast.x, prev.y * 2 - prevLast.y, prev.z * 2 - prevLast.z, 0, 0, 0, 0));
			var pNext = pts[1];
			if( pNext == null ) pNext = p;
			prev = new GPoint(p.x * 2 - pNext.x, p.y * 2 - pNext.y, p.z * 2 - pNext.z, 0, 0, 0, 0);
		} else if( p != prev ) {
			count--;
			last--;
			prev = pts[last];
		}

		var start = this.bprim.vertexCount();
		var pindex = start;
		var v = 0.;
		for( i in 0...count ) {
			var next = pts[(i + 1) % pts.length];

			// ATM we only tesselate in the XY plane using a Z up normal !

			var nx1 = prev.y - p.y;
			var ny1 = p.x - prev.x;
			var ns1 = Math.invSqrt(nx1 * nx1 + ny1 * ny1);

			var nx2 = p.y - next.y;
			var ny2 = next.x - p.x;
			var ns2 = Math.invSqrt(nx2 * nx2 + ny2 * ny2);

			var nx = nx1 * ns1 + nx2 * ns2;
			var ny = ny1 * ns1 + ny2 * ns2;
			var ns = Math.invSqrt(nx * nx + ny * ny);

			nx *= ns;
			ny *= ns;

			var size = nx * nx1 * ns1 + ny * ny1 * ns1; // N.N1
			var d = this.lineSize * 0.5 / size;
			nx *= d;
			ny *= d;

			inline function add(v:Float) {
				this.bprim.addVertexValue(v);
			}

			var hasIndex = i < count - 1 || closed;
			this.bprim.begin(2, hasIndex ? 6 : 0);

			add(p.x + nx);
			add(p.y + ny);
			add(p.z);

			add(0);
			add(0);
			add(1);

			add(0);
			add(v);

			add(p.r);
			add(p.g);
			add(p.b);
			add(p.a);

			add(p.x - nx);
			add(p.y - ny);
			add(p.z);

			add(0);
			add(0);
			add(1);

			add(1);
			add(v);

			add(p.r);
			add(p.g);
			add(p.b);
			add(p.a);

			v = 1 - v;

			if( hasIndex ) {
				var pnext = i == last ? start - pindex : 2;
				this.bprim.addIndex(0);
				this.bprim.addIndex(1);
				this.bprim.addIndex(pnext);

				this.bprim.addIndex(pnext);
				this.bprim.addIndex(1);
				this.bprim.addIndex(pnext + 1);
			}

			pindex += 2;

			prev = p;
			p = next;
		}
	}
}

class GraphicsRow {
	public var id: GraphicsId;
	public var internalId: InternalGraphicsId;
	public var entityId(default,null): h3d.scene.SceneStorage.EntityId;

	public var material: h3d.mat.Material = null;
	public var bprim = new h3d.prim.BigPrimitive(12);
	public var curX : Float = 0.;
	public var curY : Float = 0.;
	public var curZ : Float = 0.;
	public var curR : Float = 0.;
	public var curG : Float;
	public var curB : Float;
	public var curA : Float;
	public var lineSize = 0.;
	public var lineShader : h3d.shader.LineShader = new h3d.shader.LineShader();
	public var tmpPoints : Array<GPoint> = [];

	/**
		Setting is3D to true will switch from a screen space line (constant size whatever the distance) to a world space line
	**/
	public var is3D : Bool = false;

	public function new(id:GraphicsId, iid:InternalGraphicsId, eid:h3d.scene.SceneStorage.EntityId) {
		this.id = id;
		this.internalId = iid;
		this.entityId = eid;

		this.material = h3d.mat.MaterialSetup.current.createMaterial();
		this.material.props = this.material.getDefaultProps();
		this.material.shadows = false;
		this.material.mainPass.enableLights = false;
		this.material.mainPass.addShader(this.lineShader);
		final vcolor = new h3d.shader.VertexColorAlpha();
		vcolor.setPriority(-100);
		this.material.mainPass.addShader(vcolor);
		this.material.mainPass.culling = None;

		this.bprim.isStatic = false;

		this.lineShader.setPriority(-100);
	}
}

class GraphicsStorage {
	final entityIdToGraphicsIdIndex = new hds.Map<EntityId, GraphicsId>();
	final storage = new hds.Map<InternalGraphicsId, GraphicsRow>();
	var sequence = new SequenceGraphics();
	
	public function new() {}

	public function allocateRow(eid: h3d.scene.SceneStorage.EntityId) {
		final id = sequence.next();

		this.entityIdToGraphicsIdIndex.set(eid, id);
		final iid = externalToInternalId(id);
		this.storage.set(iid, new GraphicsRow(id, iid, eid));

		return id;
	}

	public function deallocateRow(id: GraphicsId) {
		return this.storage.remove(externalToInternalId(id));
	}

	public function deallocateRowByEntityId(id: EntityId) {
		return this.storage.remove(externalToInternalId(this.entityIdToGraphicsIdIndex[id]));
	}

	public function fetchRow(id: GraphicsId) {
		return this.storage.get(externalToInternalId(id));
	}

	public function fetchRowByEntityId(id: EntityId) {
		return this.storage.get(externalToInternalId(this.entityIdToGraphicsIdIndex[id]));
	}

	private inline function externalToInternalId(id: GraphicsId): InternalGraphicsId {
        // make these zero based
		return new InternalGraphicsId(id--);
	}

	public function reset() {
		this.entityIdToGraphicsIdIndex.clear();
		this.storage.clear();
		this.sequence = new SequenceGraphics();
	}
}

private typedef SequenceGraphics = h3d.scene.SceneStorage.Sequence<GraphicsId>;