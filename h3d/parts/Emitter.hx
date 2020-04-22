package h3d.parts;
import h3d.parts.Data;
import h3d.scene.SceneStorage.EntityId;
import h3d.parts.Particles.ParticlesRowRef;

class Emitter extends Particles implements Randomized {

	private final eRowRef: EmitterRowRef;
	private final eRow: EmitterRow;

	@:allow(h3d.scene.Scene.createEmitter)
	private function new(eid: EntityId, eRowRef:EmitterRowRef, pRowRef:ParticlesRowRef, ?parent: h3d.scene.Object = null) {
		super(eid, pRowRef, parent);
		this.eRowRef = eRowRef;
		this.eRow = eRowRef.getRow();

		setState(this.eRow.state);
		this.objectType = h3d.scene.Object.ObjectType.TEmitter;
	}

	override function onRemove() {
		super.onRemove();
		this.eRowRef.deleteRow();
	}

	override function clear() {
		super.clear();
		this.eRow.time = 0;
		this.eRow.emitCount = 0;
		this.eRow.rnd = Math.random();
	}

	public function setState(s) {
		this.eRow.state = s;
		material.texture = s.frames == null || s.frames.length == 0 ? null : s.frames[0].getTexture();
		this.pRow.frames = s.frames;
		switch( s.blendMode ) {
		case Add:
			material.blendMode = Add;
		case SoftAdd:
			material.blendMode = SoftAdd;
		case Alpha:
			material.blendMode = Alpha;
		}
		this.eRow.colorMap = null;
		if( s.colors != null ) {
			for( i in 0...s.colors.length ) {
				final c = s.colors[s.colors.length - (1 + i)];
				final k = new ColorKey(c.time, ((c.color>>16)&0xFF)/255, ((c.color>>8)&0xFF)/255, (c.color&0xFF)/255);
				k.next = this.eRow.colorMap;
				this.eRow.colorMap = k;
			}
		}
		this.pRow.hasColor = this.eRow.colorMap != null || !this.eRow.state.alpha.match(VConst(1)) || !this.eRow.state.light.match(VConst(1));
		this.pRow.pshader.isAbsolute = !this.eRow.state.emitLocal;
		this.pRow.pshader.is3D = this.eRow.state.is3D;
		this.pRow.sortMode = this.eRow.state.sortMode;
		this.pRow.emitTrail = this.eRow.state.emitTrail;
	}

	inline function eval(v) {
		return Data.State.eval(v,this.eRow.time, this, this.eRow.curPart);
	}

	public function update(dt:Float) {
		var s = this.eRow.state;
		var old = this.eRow.time;
		if( posChanged ) syncPos();
		this.eRow.curPart = null;
		this.eRow.time += dt * eval(s.globalSpeed) / s.globalLife;
		var et = (this.eRow.time - old) * s.globalLife;
		if( this.eRow.time >= 1 && s.loop )
			this.eRow.time -= 1;
		if( this.eRow.time < 1 )
			this.eRow.emitCount += eval(s.emitRate) * et;
		for( b in s.bursts )
			if( b.time <= this.eRow.time && b.time > old )
				this.eRow.emitCount += b.count;
		if( this.eRow.emitCount > 0 && posChanged ) syncPos();
		while( this.eRow.emitCount > 0 ) {
			if( this.pRow.count < s.maxParts )
				initPart(emitParticle());
			this.eRow.emitCount -= 1;
			if( this.eRow.state.emitTrail )
				break;
		}
		var p = this.pRow.head;
		while( p != null ) {
			var n = p.next;
			this.eRow.curPart = p;
			updateParticle(p, et);
			p = n;
		}
		this.eRow.curPart = null;
	}

	public inline function rand() {
		return Math.random();
	}

	function initPosDir( p : Particle ) {
		switch( this.eRow.state.shape ) {
		case SLine(size):
			p.dx = 0;
			p.dy = 0;
			p.dz = 1;
			p.x = 0;
			p.y = 0;
			p.z = eval(size);
			if( !this.eRow.state.emitFromShell ) p.z *= rand();
		case SSphere(r):
			var theta = rand() * Math.PI * 2;
			var phi = Math.acos(rand() * 2 - 1);
			var r = eval(r);
			if( !this.eRow.state.emitFromShell ) r *= rand();
			p.dx = Math.sin(phi) * Math.cos(theta);
			p.dy = Math.sin(phi) * Math.sin(theta);
			p.dz = Math.cos(phi);
			p.x = p.dx * r;
			p.y = p.dy * r;
			p.z = p.dz * r;
		case SCone(r,angle):
			var theta = rand() * Math.PI * 2;
			var phi = eval(angle) * rand();
			var r = eval(r);
			if( !this.eRow.state.emitFromShell ) r *= rand();
			p.dx = Math.sin(phi) * Math.cos(theta);
			p.dy = Math.sin(phi) * Math.sin(theta);
			p.dz = Math.cos(phi);
			p.x = p.dx * r;
			p.y = p.dy * r;
			p.z = p.dz * r;
		case SDisc(r):
			var r = eval(r);
			if( !this.eRow.state.emitFromShell ) r *= rand();
			var a = rand() * Math.PI * 2;
			p.dx = Math.cos(a);
			p.dy = Math.sin(a);
			p.dz = 0;
			p.x = p.dx * r;
			p.y = p.dy * r;
			p.z = 0;
		case SCustom(f):
			f(this,p);
		}
		if( this.eRow.state.randomDir ) {
			var theta = rand() * Math.PI * 2;
			var phi = Math.acos(rand() * 2 - 1);
			p.dx = Math.sin(phi) * Math.cos(theta);
			p.dy = Math.sin(phi) * Math.sin(theta);
			p.dz = Math.cos(phi);
		}
	}

	function initPart(p:Particle) {
		initPosDir(p);
		if( !this.eRow.state.emitLocal ) {
			var pos = new h3d.Vector(p.x, p.y, p.z);
			pos.transform3x4(absPos);
			p.x = pos.x;
			p.y = pos.y;
			p.z = pos.z;
			var v = new h3d.Vector(p.dx, p.dy, p.dz);
			v.transform3x3(absPos);
			p.dx = v.x;
			p.dy = v.y;
			p.dz = v.z;
		}
		p.fx = p.fy = p.fz = 0;
		p.time = 0;
		p.lifeTimeFactor = 1 / eval(this.eRow.state.life);
	}

	function updateParticle( p : Particle, dt : Float ) {
		p.time += dt * p.lifeTimeFactor;
		if( p.time > 1 ) {
			kill(p);
			return;
		}
		p.randIndex = 0;

		// apply forces
		if( this.eRow.state.force != null ) {
			p.fx += p.eval(this.eRow.state.force.vx, this.eRow.time) * dt;
			p.fy += p.eval(this.eRow.state.force.vy, this.eRow.time) * dt;
			p.fz += p.eval(this.eRow.state.force.vz, this.eRow.time) * dt;
		}
		p.fz -= p.eval(this.eRow.state.gravity, this.eRow.time) * dt;
		// calc speed and update position
		var speed = p.eval(this.eRow.state.speed, p.time);
		var ds = speed * dt;
		p.x += p.dx * ds + p.fx * dt;
		p.y += p.dy * ds + p.fy * dt;
		p.z += p.dz * ds + p.fz * dt;
		p.size = p.eval(this.eRow.state.size, p.time);
		p.ratio = p.eval(this.eRow.state.ratio, p.time);
		p.rotation = p.eval(this.eRow.state.rotation, p.time);

		// collide
		if( this.eRow.state.collide && this.eRow.collider != null && this.eRow.collider.collidePart(p, this.pRow.tmp) ) {
			if( this.eRow.state.collideKill ) {
				kill(p);
				return;
			} else {
				var v = new h3d.Vector(p.dx, p.dy, p.dz).reflect(this.pRow.tmp);
				p.dx = v.x * this.eRow.state.bounce;
				p.dy = v.y * this.eRow.state.bounce;
				p.dz = v.z * this.eRow.state.bounce;
			}
		}


		// calc color
		var ck = this.eRow.colorMap;
		var light = p.eval(this.eRow.state.light, p.time);
		if( ck != null ) {
			if( ck.time >= p.time ) {
				p.r = ck.r;
				p.g = ck.g;
				p.b = ck.b;
			} else {
				var prev = ck;
				ck = ck.next;
				while( ck != null && ck.time < p.time ) {
					prev = ck;
					ck = ck.next;
				}
				if( ck == null ) {
					p.r = prev.r;
					p.g = prev.g;
					p.b = prev.b;
				} else {
					var b = (p.time - prev.time) / (ck.time - prev.time);
					var a = 1 - b;
					p.r = prev.r * a + ck.r * b;
					p.g = prev.g * a + ck.g * b;
					p.b = prev.b * a + ck.b * b;
				}
			}
			p.r *= light;
			p.g *= light;
			p.b *= light;
		} else {
			p.r = light;
			p.g = light;
			p.b = light;
		}
		p.a = p.eval(this.eRow.state.alpha, p.time);

		// frame
		if( this.eRow.state.frame != null ) {
			var f = p.eval(this.eRow.state.frame, p.time) % 1;
			if( f < 0 ) f += 1;
			p.frame = Std.int(f * this.eRow.state.frames.length);
		}

		if( this.eRow.state.update != null )
			this.eRow.state.update(p);
	}

	override function sync( ctx : h3d.scene.RenderContext.SyncContext ) {
		update(ctx.elapsedTime * this.eRow.speed);
	}

	public function isActive() {
		return this.pRow.count != 0 || this.eRow.time < 1 || this.eRow.state.loop;
	}

	override function draw( ctx : h3d.scene.RenderContext.DrawContext ) {
		this.pRow.globalSize = eval(this.eRow.state.globalSize) * 0.1;
		super.draw(ctx);
	}

}

abstract EmitterId(Int) to Int {
	public inline function new(id:Int) { this = id; }
}

private abstract InternalEmitterId(Int) {
	public inline function new(id:Int) { this = id; }
}

class EmitterRowRef {
	final rowId: EmitterId;
	final sceneStorage: h3d.scene.SceneStorage;
	
	public function new(rowId: EmitterId, sceneStorage: h3d.scene.SceneStorage) {
		this.rowId = rowId;
		this.sceneStorage = sceneStorage;
	}

	public inline function getRow() {
		return this.sceneStorage.selectEmitter(rowId);
	}

	/**
		TODO Leaving this here as it's not a general delete
	**/
	public inline function deleteRow() {
		final eid = this.getRow().entityId;
		this.sceneStorage.emitterStorage.deallocateRow(rowId);
		this.sceneStorage.particlesStorage.deallocateRowByEntityId(eid);
		this.sceneStorage.entityStorage.deallocateRow(eid);
	}
}

class EmitterRow {
	public var id: EmitterId;
	public var internalId: InternalEmitterId;
	public var entityId(default,null): h3d.scene.SceneStorage.EntityId;

	public var time : Float = 0.;
	public var state : State;
	public var speed : Float = 1.;
	public var collider : Collider = null;

	public var rnd : Float;
	public var emitCount : Float = 0.;
	public var colorMap : ColorKey = null;
	public var curPart : Particle = null;

	public function new(id:EmitterId, iid:InternalEmitterId, eid:h3d.scene.SceneStorage.EntityId, ?state:h3d.parts.Data.State=null) {
		this.id = id;
		this.internalId = iid;
		this.entityId = eid;
		
		rnd = Math.random();
		this.state = if( state == null ) {
			state = new State();
			state.setDefaults();
			state.initFrames();
			state;
		} else {
			state;
		}
	}
}

class EmitterStorage {
	final entityIdToEmitterIdIndex = new hds.Map<EntityId, EmitterId>();
	final storage = new hds.Map<InternalEmitterId, EmitterRow>();
	var sequence = new SequenceEmitter();
	
	public function new() {}

	public function allocateRow(eid: h3d.scene.SceneStorage.EntityId, state) {
		final id = sequence.next();

		this.entityIdToEmitterIdIndex.set(eid, id);
		final iid = externalToInternalId(id);
		this.storage.set(iid, new EmitterRow(id, iid, eid, state));

		return id;
	}

	public function deallocateRow(id: EmitterId) {
		return this.storage.remove(externalToInternalId(id));
	}

	public function fetchRow(id: EmitterId) {
		return storage.get(externalToInternalId(id));
	}

	private inline function externalToInternalId(id: EmitterId): InternalEmitterId {
        // make these zero based
		return new InternalEmitterId(id--);
	}

	public function reset() {
		this.entityIdToEmitterIdIndex.clear();
		this.storage.clear();
		this.sequence = new SequenceEmitter();
	}
}

private typedef SequenceEmitter = h3d.scene.SceneStorage.Sequence<EmitterId>;
