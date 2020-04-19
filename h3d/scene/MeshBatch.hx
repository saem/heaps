package h3d.scene;
import h3d.scene.SceneStorage.EntityId;

private class BatchData {

	public var count : Int;
	public var buffer : h3d.Buffer;
	public var data : hxd.FloatBuffer;
	public var params : hxsl.RuntimeShader.AllocParam;
	public var shader : hxsl.BatchShader;
	public var shaders : Array<hxsl.Shader>;
	public var pass : h3d.mat.Pass;
	public var next : BatchData;

	public function new() {
	}

}

/**
	h3d.scene.MeshBatch allows to draw multiple meshed in a single draw call.
	See samples/MeshBatch.hx for an example.
**/
class MeshBatch extends Mesh {

	private final mbRowRef: MeshBatchRowRef;
	private final mbRow: MeshBatchRow;

	public var shadersChanged(get,set): Bool;
	inline function get_shadersChanged() return this.mbRow.shadersChanged;
	inline function set_shadersChanged(s) return this.mbRow.shadersChanged = s;

	@:allow(h3d.scene.Scene.createMeshBatch)
	private function new( eid: EntityId, mbRowRef:MeshBatchRowRef, mRowRef: h3d.scene.Mesh.MeshRowRef, parent:h3d.scene.Object ) {
		this.mbRowRef = mbRowRef;
		this.mbRow = this.mbRowRef.getRow();
		
		super(eid, mRowRef, parent);

		for( p in this.material.getPasses() )
			@:privateAccess p.batchMode = true;
	}

	override function onRemove() {
		super.onRemove();
		cleanPasses();
		this.mbRowRef.deleteRow();
	}

	function cleanPasses() {
		var alloc = hxd.impl.Allocator.get();
		while( this.mbRow.dataPasses != null ) {
			this.mbRow.dataPasses.pass.removeShader(this.mbRow.dataPasses.shader);
			alloc.disposeBuffer(this.mbRow.dataPasses.buffer);
			alloc.disposeFloats(this.mbRow.dataPasses.data);
			this.mbRow.dataPasses = this.mbRow.dataPasses.next;
		}
		this.mbRow.instanced.commands.dispose();
		this.mbRow.shaderInstances = 0;
		this.mbRow.shadersChanged = true;
	}

	function initShadersMapping() {
		var scene = getScene();
		if( scene == null ) return;
		cleanPasses();
		this.mbRow.shaderInstances = this.mbRow.maxInstances;
		for( p in material.getPasses() ) @:privateAccess {
			var ctx = scene.renderer.getPassByName(p.name);
			if( ctx == null ) throw "Could't find renderer pass "+p.name;

			var manager = cast(ctx,h3d.pass.Default).manager;
			var shaders = p.getShadersRec();
			var rt = manager.compileShaders(shaders,false);

			var shader = manager.shaderCache.makeBatchShader(rt);

			var b = new BatchData();
			b.count = rt.vertex.paramsSize + rt.fragment.paramsSize;
			b.params = rt.fragment.params == null ? null : rt.fragment.params.clone();

			var hd = b.params;
			while( hd != null ) {
				hd.pos += rt.vertex.paramsSize << 2;
				hd = hd.next;
			}

			if( b.params == null )
				b.params = rt.vertex.params;
			else if( rt.vertex != null ) {
				var vl = rt.vertex.params.clone();
				var hd = vl;
				while( vl.next != null ) vl = vl.next;
				vl.next = b.params;
				b.params = hd;
			}

			var tot = b.count * this.mbRow.shaderInstances;
			b.shader = shader;
			b.pass = p;
			b.shaders = [null/*link shader*/];
			var alloc = hxd.impl.Allocator.get();
			b.buffer = alloc.allocBuffer(tot,4,UniformDynamic);
			b.data = alloc.allocFloats(tot * 4);
			b.next = this.mbRow.dataPasses;
			this.mbRow.dataPasses = b;

			var sl = shaders;
			while( sl != null ) {
				b.shaders.push(sl.s);
				sl = sl.next;
			}

			shader.Batch_Count = tot;
			shader.Batch_Buffer = b.buffer;
			shader.constBits = tot;
			shader.updateConstants(null);
		}
		// add batch shaders
		var p = this.mbRow.dataPasses;
		while( p != null ) {
			p.pass.addShader(p.shader);
			p = p.next;
		}
	}

	public function begin( maxCount : Int ) {
		if( maxCount > this.mbRow.shaderInstances )
			this.mbRow.shadersChanged = true;
		this.mbRow.colorSave.load(material.color);
		this.mbRow.curInstances = 0;
		this.mbRow.maxInstances = maxCount;
		if( this.mbRow.shadersChanged ) {
			if( this.mbRow.colorMult != null ) {
				material.mainPass.removeShader(this.mbRow.colorMult);
				this.mbRow.colorMult = null;
			}
			initShadersMapping();
			this.mbRow.shadersChanged = false;
			if( this.mbRow.allowGlobalMaterialColor ) {
				if( this.mbRow.colorMult == null ) {
					this.mbRow.colorMult = new h3d.shader.ColorMult();
					material.mainPass.addShader(this.mbRow.colorMult);
				}
			} else {
				if( this.mbRow.colorMult != null ) {
					material.mainPass.removeShader(this.mbRow.colorMult);
					this.mbRow.colorMult = null;
				}
			}
		}
	}

	function syncData( data : BatchData ) {
		var p = data.params;
		var buf = data.data;
		var shaders = data.shaders;
		var startPos = data.count * this.mbRow.curInstances * 4;
		var calcInv = false;
		while( p != null ) {
			var pos = startPos + p.pos;
			inline function addMatrix(m:h3d.Matrix) {
				buf[pos++] = m._11;
				buf[pos++] = m._21;
				buf[pos++] = m._31;
				buf[pos++] = m._41;
				buf[pos++] = m._12;
				buf[pos++] = m._22;
				buf[pos++] = m._32;
				buf[pos++] = m._42;
				buf[pos++] = m._13;
				buf[pos++] = m._23;
				buf[pos++] = m._33;
				buf[pos++] = m._43;
				buf[pos++] = m._14;
				buf[pos++] = m._24;
				buf[pos++] = m._34;
				buf[pos++] = m._44;
			}
			if( p.perObjectGlobal != null ) {
				if( p.perObjectGlobal.gid == this.mbRow.modelViewID ) {
					addMatrix(this.mbRow.worldPosition != null ? this.mbRow.worldPosition : absPos);
				} else if( p.perObjectGlobal.gid == this.mbRow.modelViewInverseID ) {
					if( this.mbRow.worldPosition == null )
						addMatrix(getInvPos());
					else {
						if( !calcInv ) {
							calcInv = true;
							if( this.mbRow.invWorldPosition == null ) this.mbRow.invWorldPosition = new h3d.Matrix();
							this.mbRow.invWorldPosition.initInverse(this.mbRow.worldPosition);
						}
						addMatrix(this.mbRow.invWorldPosition);
					}
				} else
					throw "Unsupported global param "+p.perObjectGlobal.path;
				p = p.next;
				continue;
			}
			var curShader = shaders[p.instance];
			switch( p.type ) {
			case TVec(size, _):
				var v : h3d.Vector = curShader.getParamValue(p.index);
				switch( size ) {
				case 2:
					buf[pos++] = v.x;
					buf[pos++] = v.y;
				case 3:
					buf[pos++] = v.x;
					buf[pos++] = v.y;
					buf[pos++] = v.z;
				default:
					buf[pos++] = v.x;
					buf[pos++] = v.y;
					buf[pos++] = v.z;
					buf[pos++] = v.w;
				}
			case TFloat:
				buf[pos++] = curShader.getParamFloatValue(p.index);
			case TMat4:
				var m : h3d.Matrix = curShader.getParamValue(p.index);
				addMatrix(m);
			default:
				throw "Unsupported batch type "+p.type;
			}
			p = p.next;
		}
	}

	public function emitInstance() {
		if( this.mbRow.curInstances == this.mbRow.maxInstances ) throw "Too many instances";
		syncPos();
		var p = this.mbRow.dataPasses;
		while( p != null ) {
			syncData(p);
			p = p.next;
		}
		if( this.mbRow.allowGlobalMaterialColor ) material.color.load(this.mbRow.colorSave);
		this.mbRow.curInstances++;
	}

	override function sync(ctx:RenderContext.SyncContext) {
		super.sync(ctx);
		if( this.mbRow.curInstances == 0 ) return;
		var p = this.mbRow.dataPasses;
		while( p != null ) {
			if( p.buffer.isDisposed() ) {
				p.buffer = hxd.impl.Allocator.get().allocBuffer(p.count * this.mbRow.shaderInstances,4,UniformDynamic);
				p.shader.Batch_Buffer = p.buffer;
			}
			p.buffer.uploadVector(p.data,0,this.mbRow.curInstances * p.count);
			p = p.next;
		}
		this.mbRow.instanced.commands.setCommand(this.mbRow.curInstances,this.mbRow.indexCount);
		if( this.mbRow.colorMult != null ) this.mbRow.colorMult.color.load(material.color);
	}

	override function emit(ctx:RenderContext.EmitContext) {
		if( this.mbRow.curInstances == 0 ) return;
		super.emit(ctx);
	}

}

abstract MeshBatchId(Int) to Int {
	public inline function new(id:Int) { this = id; }
}

private abstract InternalMeshBatchId(Int) {
	public inline function new(id:Int) { this = id; }
}

class MeshBatchRowRef {
	final rowId: MeshBatchId;
	final sceneStorage: h3d.scene.SceneStorage;
	
	public function new(rowId: MeshBatchId, sceneStorage: h3d.scene.SceneStorage) {
		this.rowId = rowId;
		this.sceneStorage = sceneStorage;
	}

	public inline function getRow() {
		return this.sceneStorage.selectMeshBatch(rowId);
	}

	/**
		TODO Leaving this here as it's not a general delete
	**/
	public inline function deleteRow() {
		final eid = this.getRow().entityId;
		this.sceneStorage.meshBatchStorage.deallocateRow(rowId);
		this.sceneStorage.entityStorage.deallocateRow(eid);
	}
}

class MeshBatchRow {
	public var id: MeshBatchId;
	public var internalId: InternalMeshBatchId;
	public var entityId(default,null): h3d.scene.SceneStorage.EntityId;

	public var instanced = new h3d.prim.Instanced();
	public var curInstances : Int = 0;
	public var maxInstances : Int = 0;
	public var shaderInstances : Int = 0;
	public var dataBuffer : h3d.Buffer;
	public var dataPasses : BatchData;
	public var indexCount : Int;
	public var modelViewID = hxsl.Globals.allocID("global.modelView");
	public var modelViewInverseID = hxsl.Globals.allocID("global.modelViewInverse");
	public var colorSave = new h3d.Vector();
	public var colorMult : h3d.shader.ColorMult;

	/**
		Tells if we can use material.color as a global multiply over each instance color (default: true)
	**/
	public var allowGlobalMaterialColor : Bool = true;

	/**
	 * 	If set, use this position in emitInstance() instead MeshBatch absolute position
	**/
	public var worldPosition : Matrix;
	public var invWorldPosition : Matrix;

	/**
		Set if shader list or shader constants has changed, before calling begin()
	**/
	public var shadersChanged = true;

	public function new(id:MeshBatchId, iid:InternalMeshBatchId, eid:h3d.scene.SceneStorage.EntityId, meshPrim: h3d.prim.MeshPrimitive) {
		this.id = id;
		this.internalId = iid;
		this.entityId = eid;

		this.instanced.setMesh(meshPrim);
		this.instanced.commands = new h3d.impl.InstanceBuffer();
		this.indexCount = meshPrim.indexes == null ? meshPrim.triCount() * 3 : meshPrim.indexes.count;
	}
}

class MeshBatchStorage {
	final entityIdToMeshBatchIdIndex = new hds.Map<EntityId, MeshBatchId>();
	final storage = new hds.Map<InternalMeshBatchId, MeshBatchRow>();
	var sequence = new SequenceMeshBatch();
	
	public function new() {}

	public function allocateRow(eid: h3d.scene.SceneStorage.EntityId, meshPrim: h3d.prim.MeshPrimitive) {
		final id = sequence.next();

		this.entityIdToMeshBatchIdIndex.set(eid, id);
		final iid = externalToInternalId(id);
		this.storage.set(iid, new MeshBatchRow(id, iid, eid, meshPrim));

		return id;
	}

	public function deallocateRow(id: MeshBatchId) {
		return this.storage.remove(externalToInternalId(id));
	}

	public function fetchRow(id: MeshBatchId) {
		return this.storage.get(externalToInternalId(id));
	}

	private inline function externalToInternalId(id: MeshBatchId): InternalMeshBatchId {
        // make these zero based
		return new InternalMeshBatchId(id--);
	}

	public function reset() {
		this.entityIdToMeshBatchIdIndex.clear();
		this.storage.clear();
		this.sequence = new SequenceMeshBatch();
	}
}

private typedef SequenceMeshBatch = h3d.scene.SceneStorage.Sequence<MeshBatchId>;