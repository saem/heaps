package h3d.scene;
import h3d.scene.SceneStorage.EntityId;

class Joint extends h3d.scene.Object {
	@:s public var skin : Skin;
	@:s public var index : Int;

	@:allow(h3d.scene.Object.createSkinJoint)
	private function new(skin, j : h3d.anim.Skin.Joint ) {
		super(null);
		name = j.name;
		this.skin = skin;
		// fake parent
		this.parent = skin;
		this.index = j.index;
	}
}

class Skin extends h3d.scene.Mesh {

	private final sRowRef: SkinRowRef;
	private final sRow: SkinRow;

	public var jointsUpdated(get,set):Bool;
	inline function get_jointsUpdated():Bool return this.sRow.jointsUpdated;
	inline function set_jointsUpdated(b:Bool):Bool return this.sRow.jointsUpdated = b;
	public var showJoints(get,set):Bool;
	inline function get_showJoints():Bool return this.sRow.showJoints;
	inline function set_showJoints(b:Bool):Bool return this.sRow.showJoints = b;

	public var skinData(get,never):h3d.anim.Skin;
	inline function get_skinData():h3d.anim.Skin return this.sRow.skinData;
	public var currentPalette(get,never):Array<Matrix>;
	inline function get_currentPalette():Array<Matrix> return this.sRow.currentPalette;
	public var currentRelPose(get,never):Array<Matrix>;
	inline function get_currentRelPose():Array<Matrix> return this.sRow.currentRelPose;

	@:allow(h3d.scene.Scene.createSkin)
	private function new(sRowRef:SkinRowRef, ?mats:Array<h3d.mat.Material> = null, ?parent:h3d.scene.Object) {
		super(null, mats, parent);
		this.sRowRef = sRowRef;
		this.sRow = this.sRowRef.getRow();

		if( sRow.skinData != null )
			setSkinData(sRow.skinData);
	}

	override function onRemove() {
		if ( this.sRow.jointsGraphics != null ) {
			this.sRow.jointsGraphics.remove();
		}
		super.onRemove();
		this.sRowRef.deleteRow();
	}

	override function clone( ?o : Object ) {
		var s = o == null ? this.getScene().createSkin(null,materials.copy()) : cast o;
		super.clone(s);
		s.setSkinData(this.sRow.skinData);
		s.sRow.currentRelPose = this.sRow.currentRelPose.copy(); // copy current pose
		return s;
	}

	override function getBoundsRec( b : h3d.col.Bounds ) {
		b = super.getBoundsRec(b);
		var tmp = primitive.getBounds().clone();
		var b0 = this.sRow.skinData.allJoints[0];
		// not sure if that's the good joint
		if( b0 != null && b0.parent == null ) {
			var mtmp = absPos.clone();
			var r = this.sRow.currentRelPose[b0.index];
			if( r != null )
				mtmp.multiply3x4(r, mtmp);
			else
				mtmp.multiply3x4(b0.defMat, mtmp);
			if( b0.transPos != null )
				mtmp.multiply3x4(b0.transPos, mtmp);
			tmp.transform(mtmp);
		} else
			tmp.transform(absPos);
		b.add(tmp);
		return b;
	}

	override function getObjectByName( name : String ) : h3d.scene.Object {
		// we can reference the object by both its model name and skin name
		if( this.sRow.skinData != null && this.sRow.skinData.name == name )
			return this;
		var o = super.getObjectByName(name);
		if( o != null ) return o;
		// create a fake object targeted at the bone, not persistant but matrixes are shared
		if( this.sRow.skinData != null ) {
			var j = this.sRow.skinData.namedJoints.get(name);
			if( j != null )
				return h3d.scene.Object.createSkinJoint(this, j);
		}
		return null;
	}

	override function getLocalCollider() {
		throw "Not implemented";
		return null;
	}

	override function getGlobalCollider() {
		var col = cast(primitive.getCollider(), h3d.col.Collider.OptimizedCollider);
		cast(primitive, h3d.prim.HMDModel).loadSkin(this.sRow.skinData);
		return new h3d.col.SkinCollider(this, cast(col.b, h3d.col.PolygonBuffer));
	}

	override function calcAbsPos() {
		super.calcAbsPos();
		// if we update our absolute position, rebuild the matrixes
		this.sRow.jointsUpdated = true;
	}

	public function getSkinData() {
		return this.sRow.skinData;
	}

	public function setSkinData( s:h3d.anim.Skin, shaderInit = true ) {
		this.sRow.skinData = s;
		this.sRow.jointsUpdated = true;
		primitive = s.primitive;
		if( shaderInit ) {
			var hasNormalMap = false;
			for( m in materials )
				if( m != null && m.normalMap != null ) {
					hasNormalMap = true;
					break;
				}
				this.sRow.skinShader = hasNormalMap ? new h3d.shader.SkinTangent() : new h3d.shader.Skin();
			var maxBones = 0;
			if( this.sRow.skinData.splitJoints != null ) {
				for( s in this.sRow.skinData.splitJoints )
					if( s.joints.length > maxBones )
						maxBones = s.joints.length;
			} else
				maxBones = this.sRow.skinData.boundJoints.length;
			if( this.sRow.skinShader.MaxBones < maxBones )
				this.sRow.skinShader.MaxBones = maxBones;
			for( m in materials )
				if( m != null ) {
					if( m.normalMap != null )
						@:privateAccess m.mainPass.addShaderAtIndex(this.sRow.skinShader, m.mainPass.getShaderIndex(m.normalShader) + 1);
					else
						m.mainPass.addShader(this.sRow.skinShader);
					if( this.sRow.skinData.splitJoints != null ) m.mainPass.dynamicParameters = true;
				}
		}
		this.sRow.currentRelPose = [];
		this.sRow.currentAbsPose = [];
		this.sRow.currentPalette = [];
		this.sRow.paletteChanged = true;
		for( j in this.sRow.skinData.allJoints )
			this.sRow.currentAbsPose.push(h3d.Matrix.I());
		for( i in 0...this.sRow.skinData.boundJoints.length )
			this.sRow.currentPalette.push(h3d.Matrix.I());
		if( this.sRow.skinData.splitJoints != null ) {
			this.sRow.splitPalette = [];
			for( a in this.sRow.skinData.splitJoints )
				this.sRow.splitPalette.push([for( j in a.joints ) this.sRow.currentPalette[j.bindIndex]]);
		} else
			this.sRow.splitPalette = null;
	}

	override function sync( ctx : RenderContext.SyncContext ) {
		if( !syncVisibleFlag && !alwaysSync )
			return;
		syncJoints();

		if( this.sRow.showJoints ) {
			if( this.sRow.jointsGraphics == null ) {
				this.sRow.jointsGraphics = this.getScene().createGraphics(null);
				this.sRow.jointsGraphics.material.mainPass.depth(false, Always);
				this.sRow.jointsGraphics.material.mainPass.setPassName("additive");
			}

			var topParent : Object = this;
			while( topParent.parent != null )
				topParent = topParent.parent;
			topParent.addChild(this.sRow.jointsGraphics);

			var g = this.sRow.jointsGraphics;
			g.clear();
			for( j in this.sRow.skinData.allJoints ) {
				var m = this.sRow.currentAbsPose[j.index];
				var mp = j.parent == null ? absPos : this.sRow.currentAbsPose[j.parent.index];
				g.lineStyle(1, j.parent == null ? 0xFF0000FF : 0xFFFFFF00);
				g.moveTo(mp._41, mp._42, mp._43);
				g.lineTo(m._41, m._42, m._43);
			}
		} else if( this.sRow.jointsGraphics != null ) {
			this.sRow.jointsGraphics.remove();
			this.sRow.jointsGraphics = null;
		}
	}

	@:noDebug
	function syncJoints() {
		if( !this.sRow.jointsUpdated ) return;
		for( j in this.sRow.skinData.allJoints ) {
			var id = j.index;
			var m = this.sRow.currentAbsPose[id];
			var r = this.sRow.currentRelPose[id];
			var bid = j.bindIndex;
			if( r == null ) r = j.defMat else if( j.retargetAnim ) { r._41 = j.defMat._41; r._42 = j.defMat._42; r._43 = j.defMat._43; }
			if( j.parent == null )
				m.multiply3x4inline(r, absPos);
			else
				m.multiply3x4inline(r, this.sRow.currentAbsPose[j.parent.index]);
			if( bid >= 0 )
				this.sRow.currentPalette[bid].multiply3x4inline(j.transPos, m);
		}
		this.sRow.skinShader.bonesMatrixes = this.sRow.currentPalette;
		if( this.sRow.jointsAbsPosInv != null ) this.sRow.jointsAbsPosInv._44 = 0; // mark as invalid
		this.sRow.jointsUpdated = false;
	}

	override function emit( ctx : RenderContext.EmitContext ) {
		if( this.sRow.splitPalette == null )
			super.emit(ctx);
		else {
			for( i in 0...this.sRow.splitPalette.length ) {
				var m = materials[this.sRow.skinData.splitJoints[i].material];
				if( m != null )
					ctx.emit(m, this, i);
			}
		}
	}

	override function draw( ctx : RenderContext.DrawContext ) {
		if( this.sRow.splitPalette == null ) {
			super.draw(ctx);
		} else {
			var i = ctx.drawPass.index;
			this.sRow.skinShader.bonesMatrixes = this.sRow.splitPalette[i];
			primitive.selectMaterial(i);
			ctx.uploadParams();
			primitive.render(ctx.engine);
		}
	}

	#if (hxbit && !macro && heaps_enable_serialize)
	override function customUnserialize(ctx:hxbit.Serializer) {
		super.customUnserialize(ctx);
		var prim = hxd.impl.Api.downcast(primitive, h3d.prim.HMDModel);
		if( prim == null ) throw "Cannot load skin primitive " + prim;
		jointsUpdated = true;
		skinShader = material.mainPass.getShader(h3d.shader.Skin);
		@:privateAccess {
			var lib = prim.lib;
			for( m in lib.header.models )
				if( lib.header.geometries[m.geometry] == prim.data ) {
					var skinData = lib.makeSkin(m.skin);
					skinData.primitive = prim;
					setSkinData(skinData, false);
					break;
				}
		}
	}
	#end
}

abstract SkinId(Int) to Int {
	public inline function new(id:Int) { this = id; }
}

private abstract InternalSkinId(Int) {
	public inline function new(id:Int) { this = id; }
}

class SkinRowRef {
	final rowId: SkinId;
	final sceneStorage: h3d.scene.SceneStorage;
	
	public function new(rowId: SkinId, sceneStorage: h3d.scene.SceneStorage) {
		this.rowId = rowId;
		this.sceneStorage = sceneStorage;
	}

	public inline function getRow() {
		return this.sceneStorage.selectSkin(rowId);
	}

	/**
		TODO Leaving this here as it's not a general delete
	**/
	public inline function deleteRow() {
		final eid = this.getRow().entityId;
		this.sceneStorage.skinStorage.deallocateRow(rowId);
		this.sceneStorage.entityStorage.deallocateRow(eid);
	}
}

class SkinRow {
	public var id: SkinId;
	public var internalId: InternalSkinId;
	public var entityId(default,null): h3d.scene.SceneStorage.EntityId;

	public var skinData : h3d.anim.Skin = null;
	public var currentRelPose : Array<h3d.Matrix> = null;
	public var currentAbsPose : Array<h3d.Matrix> = null;
	public var currentPalette : Array<h3d.Matrix> = null;
	public var splitPalette : Array<Array<h3d.Matrix>> = [];
	public var jointsUpdated : Bool = false;
	public var jointsAbsPosInv : h3d.Matrix = null;
	public var paletteChanged : Bool = false;
	public var skinShader : h3d.shader.SkinBase = null;
	public var jointsGraphics : Graphics = null;

	public var showJoints : Bool = false;

	public function new(id:SkinId, iid:InternalSkinId, eid:h3d.scene.SceneStorage.EntityId, skinData:h3d.anim.Skin) {
		this.id = id;
		this.internalId = iid;
		this.entityId = eid;
		this.skinData = skinData;
	}
}

class SkinStorage {
	final entityIdToSkinIdIndex = new hds.Map<EntityId, SkinId>();
	final storage = new hds.Map<InternalSkinId, SkinRow>();
	var sequence = new SequenceSkin();
	
	public function new() {}

	public function allocateRow(eid: h3d.scene.SceneStorage.EntityId, skinData: h3d.anim.Skin) {
		final id = sequence.next();

		this.entityIdToSkinIdIndex.set(eid, id);
		final iid = externalToInternalId(id);
		this.storage.set(iid, new SkinRow(id, iid, eid, skinData));

		return id;
	}

	public function deallocateRow(id: SkinId) {
		return this.storage.remove(externalToInternalId(id));
	}

	public function fetchRow(id: SkinId) {
		return this.storage.get(externalToInternalId(id));
	}

	private inline function externalToInternalId(id: SkinId): InternalSkinId {
        // make these zero based
		return new InternalSkinId(id--);
	}

	public function reset() {
		this.entityIdToSkinIdIndex.clear();
		this.storage.clear();
		this.sequence = new SequenceSkin();
	}
}

private typedef SequenceSkin = h3d.scene.SceneStorage.Sequence<SkinId>;