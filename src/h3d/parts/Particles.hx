package h3d.parts;
import h3d.scene.SceneStorage.EntityId;

private class ParticleIterator {
	var p : Particle;
	public inline function new(p) {
		this.p = p;
	}
	public inline function hasNext() {
		return p != null;
	}
	public inline function next() {
		var v = p;
		p = p.next;
		return v;
	}
}

@:access(h3d.parts.Particle)
class Particles extends h3d.scene.Object implements h3d.scene.Materialable {

	private final pRowRef: ParticlesRowRef;
	@:allow(h3d.scene.Scene)
	private final pRow: ParticlesRow;

	public var materials(get,set): Array<h3d.mat.Material>;
	inline function get_materials() return [this.pRow.material];
	inline function set_materials(m) return [this.pRow.material = m[0]];

	/**
		The material of the mesh: the properties used to display it (texture, color, shaders, etc.)
	**/
	public var material(get, set) : h3d.mat.Material;
	inline function get_material() return this.pRow.material;
	inline function set_material(m) return this.pRow.material = m;

	@:allow(h3d.scene.Scene.createParticles)
	private function new(oRowRef: h3d.scene.Object.ObjectRowRef, pRowRef:ParticlesRowRef) {
		this.pRowRef = pRowRef;
		this.pRow = pRowRef.getRow();
		
		super(oRowRef);
	}

	function set_hasColor(b) {
		var c = material.mainPass.getShader(h3d.shader.VertexColorAlpha);
		if( b ) {
			if( c == null )
				material.mainPass.addShader(new h3d.shader.VertexColorAlpha());
		} else {
			if( c != null )
				material.mainPass.removeShader(c);
		}
		return this.pRow.hasColor = b;
	}

	override function onRemove() {
		super.onRemove();
		this.pRowRef.deleteRow();
	}

	function draw( ctx : h3d.scene.RenderContext.DrawContext ) {
		drawParticles(this.pRow, ctx);
	}

	@:access(h2d.Tile)
	@:noDebug
	public static function drawParticles( pRow : ParticlesRow, ctx : h3d.scene.RenderContext.DrawContext ) {
		if( pRow.head == null )
			return;
		switch( pRow.sortMode ) {
		case Sort, InvSort:
			var p = pRow.head;
			var m = ctx.camera.m;
			while( p != null ) {
				p.w = (p.x * m._13 + p.y * m._23 + p.z * m._33 + m._43) / (p.x * m._14 + p.y * m._24 + p.z * m._34 + m._44);
				p = p.next;
			}
			pRow.head = pRow.sortMode == Sort ? sort(pRow.head) : sortInv(pRow.head);
			pRow.tail = pRow.head.prev;
			pRow.head.prev = null;
		default:
		}
		if( pRow.tmpBuf == null ) pRow.tmpBuf = new hxd.FloatBuffer();
		var pos = 0;
		var p = pRow.head;
		var tmp = pRow.tmpBuf;
		var surface = 0.;
		if( pRow.frames == null || pRow.frames.length == 0 ) {
			var t = pRow.material.texture == null ? h2d.Tile.fromColor(0xFF00FF) : h2d.Tile.fromTexture(pRow.material.texture);
			pRow.frames = [t];
		}
		pRow.material.texture = pRow.frames[0].getTexture();
		if( pRow.emitTrail ) {
			var prev = p;
			var prevX1 = p.x, prevY1 = p.y, prevZ1 = p.z;
			var prevX2 = p.x, prevY2 = p.y, prevZ2 = p.z;
			if( p != null ) p = p.next;
			while( p != null ) {
				var f = pRow.frames[p.frame];
				if( f == null ) f = pRow.frames[0];
				var ratio = p.size * p.ratio * (f.height / f.width);

				// pos
				tmp[pos++] = prevX1;
				tmp[pos++] = prevY1;
				tmp[pos++] = prevZ1;
				// normal
				tmp[pos++] = p.size;
				tmp[pos++] = ratio;
				tmp[pos++] = p.rotation;
				// delta
				tmp[pos++] = 0;
				tmp[pos++] = 0;
				// UV
				tmp[pos++] = f.u;
				tmp[pos++] = f.v2;
				// RBGA
				if( pRow.hasColor ) {
					tmp[pos++] = p.r;
					tmp[pos++] = p.g;
					tmp[pos++] = p.b;
					tmp[pos++] = p.a;
				}

				tmp[pos++] = prevX2;
				tmp[pos++] = prevY2;
				tmp[pos++] = prevZ2;
				tmp[pos++] = p.size;
				tmp[pos++] = ratio;
				tmp[pos++] = p.rotation;
				tmp[pos++] = 0;
				tmp[pos++] = 0;
				tmp[pos++] = f.u;
				tmp[pos++] = f.v;
				if( pRow.hasColor ) {
					tmp[pos++] = p.r;
					tmp[pos++] = p.g;
					tmp[pos++] = p.b;
					tmp[pos++] = p.a;
				}

				var dx = p.x - prev.x;
				var dy = p.y - prev.y;
				var dz = p.z - prev.z;
				var d = hxd.Math.invSqrt(dx * dx + dy * dy + dz * dz);
				// this prevent big rotations from occuring while we have a very small offset
				// the value is a bit arbitrary
				if( d > 10 ) d = 10;
				dx *= d;
				dy *= d;
				dz *= d;
				var dir = new h3d.Vector(Math.sin(p.rotation), 0, Math.cos(p.rotation)).cross(new h3d.Vector(dx, dy, dz));

				prevX1 = p.x + dir.x * p.size;
				prevY1 = p.y + dir.y * p.size;
				prevZ1 = p.z + dir.z * p.size;

				prevX2 = p.x - dir.x * p.size;
				prevY2 = p.y - dir.y * p.size;
				prevZ2 = p.z - dir.z * p.size;

				tmp[pos++] = prevX1;
				tmp[pos++] = prevY1;
				tmp[pos++] = prevZ1;
				tmp[pos++] = p.size;
				tmp[pos++] = ratio;
				tmp[pos++] = p.rotation;
				tmp[pos++] = 0;
				tmp[pos++] = 0;
				tmp[pos++] = f.u2;
				tmp[pos++] = f.v2;
				if( pRow.hasColor ) {
					tmp[pos++] = p.r;
					tmp[pos++] = p.g;
					tmp[pos++] = p.b;
					tmp[pos++] = p.a;
				}

				tmp[pos++] = prevX2;
				tmp[pos++] = prevY2;
				tmp[pos++] = prevZ2;
				tmp[pos++] = p.size;
				tmp[pos++] = ratio;
				tmp[pos++] = p.rotation;
				tmp[pos++] = 0;
				tmp[pos++] = 0;
				tmp[pos++] = f.u2;
				tmp[pos++] = f.v;
				if( pRow.hasColor ) {
					tmp[pos++] = p.r;
					tmp[pos++] = p.g;
					tmp[pos++] = p.b;
					tmp[pos++] = p.a;
				}

				prev = p;
				p = p.next;
			}
		} else {
			while( p != null ) {
				var f = pRow.frames[p.frame];
				if( f == null ) f = pRow.frames[0];
				var ratio = p.size * p.ratio * (f.height / f.width);
				tmp[pos++] = p.x;
				tmp[pos++] = p.y;
				tmp[pos++] = p.z;
				tmp[pos++] = p.size;
				tmp[pos++] = ratio;
				tmp[pos++] = p.rotation;
				// delta
				tmp[pos++] = -0.5;
				tmp[pos++] = -0.5;
				// UV
				tmp[pos++] = f.u;
				tmp[pos++] = f.v2;
				// RBGA
				if( pRow.hasColor ) {
					tmp[pos++] = p.r;
					tmp[pos++] = p.g;
					tmp[pos++] = p.b;
					tmp[pos++] = p.a;
				}

				tmp[pos++] = p.x;
				tmp[pos++] = p.y;
				tmp[pos++] = p.z;
				tmp[pos++] = p.size;
				tmp[pos++] = ratio;
				tmp[pos++] = p.rotation;
				tmp[pos++] = -0.5;
				tmp[pos++] = 0.5;
				tmp[pos++] = f.u;
				tmp[pos++] = f.v;
				if( pRow.hasColor ) {
					tmp[pos++] = p.r;
					tmp[pos++] = p.g;
					tmp[pos++] = p.b;
					tmp[pos++] = p.a;
				}

				tmp[pos++] = p.x;
				tmp[pos++] = p.y;
				tmp[pos++] = p.z;
				tmp[pos++] = p.size;
				tmp[pos++] = ratio;
				tmp[pos++] = p.rotation;
				tmp[pos++] = 0.5;
				tmp[pos++] = -0.5;
				tmp[pos++] = f.u2;
				tmp[pos++] = f.v2;
				if( pRow.hasColor ) {
					tmp[pos++] = p.r;
					tmp[pos++] = p.g;
					tmp[pos++] = p.b;
					tmp[pos++] = p.a;
				}

				tmp[pos++] = p.x;
				tmp[pos++] = p.y;
				tmp[pos++] = p.z;
				tmp[pos++] = p.size;
				tmp[pos++] = ratio;
				tmp[pos++] = p.rotation;
				tmp[pos++] = 0.5;
				tmp[pos++] = 0.5;
				tmp[pos++] = f.u2;
				tmp[pos++] = f.v;
				if( pRow.hasColor ) {
					tmp[pos++] = p.r;
					tmp[pos++] = p.g;
					tmp[pos++] = p.b;
					tmp[pos++] = p.a;
				}

				p = p.next;
			}
		}
		var stride = 10;
		if( pRow.hasColor ) stride += 4;
		var buffer = h3d.Buffer.ofSubFloats(tmp, stride, Std.int(pos/stride), [Quads, Dynamic, RawFormat]);
		if( pRow.pshader.is3D )
			pRow.pshader.size.set(pRow.globalSize, pRow.globalSize);
		else
			pRow.pshader.size.set(pRow.globalSize * ctx.engine.height / ctx.engine.width * 4, pRow.globalSize * 4);
		ctx.uploadParams();
		ctx.engine.renderQuadBuffer(buffer);
		buffer.dispose();
	}

	/**
		Offset all existing particles by the given values.
	**/
	public function offsetParticles( dx : Float, dy : Float, dz = 0. ) {
		var p = this.pRow.head;
		while( p != null ) {
			p.x += dx;
			p.y += dy;
			p.z += dz;
			p = p.next;
		}
	}

	public function clear() {
		while( this.pRow.head != null )
			kill(this.pRow.head);
	}

	public function alloc() {
		var p = emitParticle();
		if( posChanged ) syncPos();
		p.parts = this;
		p.x = absPos.tx;
		p.y = absPos.ty;
		p.z = absPos.tz;
		p.rotation = 0;
		p.ratio = 1;
		p.size = 1;
		p.r = p.g = p.b = p.a = 1;
		return p;
	}

	public function add(p) {
		emitParticle(p);
		return p;
	}

	function emitParticle( ?p ) {
		if( p == null ) {
			if( this.pRow.pool == null )
				p = new Particle();
			else {
				p = this.pRow.pool;
				this.pRow.pool = p.next;
			}
		}
		this.pRow.count++;
		switch( this.pRow.sortMode ) {
		case Front, Sort, InvSort:
			if( this.pRow.head == null ) {
				p.next = null;
				this.pRow.head = this.pRow.tail = p;
			} else {
				this.pRow.head.prev = p;
				p.next = this.pRow.head;
				this.pRow.head = p;
			}
		case Back:
			if( this.pRow.head == null ) {
				p.next = null;
				this.pRow.head = this.pRow.tail = p;
			} else {
				this.pRow.tail.next = p;
				p.prev = this.pRow.tail;
				p.next = null;
				this.pRow.tail = p;
			}
		}
		return p;
	}

	function kill(p:Particle) {
		if( p.prev == null ) this.pRow.head = p.next else p.prev.next = p.next;
		if( p.next == null ) this.pRow.tail = p.prev else p.next.prev = p.prev;
		p.prev = null;
		p.next = this.pRow.pool;
		this.pRow.pool = p;
		this.pRow.count--;
	}

	static function sort( list : Particle ) {
		return haxe.ds.ListSort.sort(list, function(p1, p2) return p1.w < p2.w ? 1 : -1);
	}

	static function sortInv( list : Particle ) {
		return haxe.ds.ListSort.sort(list, function(p1, p2) return p1.w < p2.w ? -1 : 1);
	}

	public inline function getParticles() {
		return new ParticleIterator(this.pRow.head);
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
}

abstract ParticlesId(Int) to Int {
	public inline function new(id:Int) { this = id; }
}

private abstract InternalParticlesId(Int) {
	public inline function new(id:Int) { this = id; }
}

class ParticlesRowRef {
	final rowId: ParticlesId;
	final sceneStorage: h3d.scene.SceneStorage;
	
	public function new(rowId: ParticlesId, sceneStorage: h3d.scene.SceneStorage) {
		this.rowId = rowId;
		this.sceneStorage = sceneStorage;
	}

	public inline function getRow() {
		return this.sceneStorage.selectParticles(rowId);
	}

	/**
		TODO Leaving this here as it's not a general delete
	**/
	public inline function deleteRow() {
		final eid = this.getRow().entityId;
		this.sceneStorage.particlesStorage.deallocateRow(rowId);
		this.sceneStorage.entityStorage.deallocateRow(eid);
	}
}

class ParticlesRow {
	public var id: ParticlesId;
	public var internalId: InternalParticlesId;
	public var entityId(default,null): h3d.scene.SceneStorage.EntityId;

	public var material: h3d.mat.Material = null;
	public var pshader : h3d.shader.ParticleShader;
	public var frames : Array<h2d.Tile>;
	public var count : Int = 0;
	public var hasColor : Bool;
	public var sortMode : Data.SortMode = Back;
	public var globalSize : Float = 1;
	public var emitTrail : Bool = false;

	public var head : Particle = null;
	public var tail : Particle = null;
	public var pool : Particle = null;

	public var tmp = new h3d.Vector();
	public var tmpBuf : hxd.FloatBuffer = null;

	public function new(id:ParticlesId, iid:InternalParticlesId, eid:h3d.scene.SceneStorage.EntityId, ?texture:h3d.mat.Texture = null) {
		this.id = id;
		this.internalId = iid;
		this.entityId = eid;
		
		material.props = material.getDefaultProps("particles3D");
		material.mainPass.addShader(this.pshader);
		material.mainPass.dynamicParameters = true;
		material.texture = texture;
		
		sortMode = Back;
		pshader = new h3d.shader.ParticleShader();
		pshader.isAbsolute = true;
	}
}

class ParticlesStorage {
	final entityIdToParticlesIdIndex = new hds.Map<EntityId, ParticlesId>();
	final storage = new hds.Map<InternalParticlesId, ParticlesRow>();
	var sequence = new SequenceParticles();
	
	public function new() {}

	public function allocateRow(eid: h3d.scene.SceneStorage.EntityId, ?texture: h3d.mat.Texture = null) {
		final id = sequence.next();

		this.entityIdToParticlesIdIndex.set(eid, id);
		final iid = externalToInternalId(id);
		this.storage.set(iid, new ParticlesRow(id, iid, eid, texture));

		return id;
	}

	public function deallocateRow(id: ParticlesId) {
		return this.storage.remove(externalToInternalId(id));
	}

	public function deallocateRowByEntityId(id: EntityId) {
		return this.storage.remove(externalToInternalId(this.entityIdToParticlesIdIndex[id]));
	}

	public function fetchRow(id: ParticlesId) {
		return this.storage.get(externalToInternalId(id));
	}

	private inline function externalToInternalId(id: ParticlesId): InternalParticlesId {
        // make these zero based
		return new InternalParticlesId(id--);
	}

	public function reset() {
		this.entityIdToParticlesIdIndex.clear();
		this.storage.clear();
		this.sequence = new SequenceParticles();
	}
}

private typedef SequenceParticles = h3d.scene.SceneStorage.Sequence<ParticlesId>;
