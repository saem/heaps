package h3d.scene;

private enum abstract ObjectFlags(Int) {
	public var FVisible = 0x01;
	public var FCulled = 0x02;
	public var FLightCameraCenter = 0x04;
	public var FAllocated = 0x08;
	public var FAlwaysSync = 0x10;
	public var FNoSerialize = 0x20;
	public var FIgnoreBounds = 0x40;
	public var FInitialTransformDone = 0x80;
	public var FSyncVisibility = 0x100;
	public var FSyncContinue = 0x200;
	public var FSyncChanged = 0x400;
	public inline function new(value) {
		this = value;
	}
	public inline function toInt() return this;
	public inline function has(f:ObjectFlags) return this & f.toInt() != 0;
	public inline function set(f:ObjectFlags, b) {
		if( b ) this |= f.toInt() else this &= ~f.toInt();
		return b;
	}
}

enum abstract AnimationResult(Int) {
	var Removed;
	var Animated;
	var NoAnimation;
}

enum abstract SyncSelfResult(Int) {
	var AbortSync;
	var Unchanged;
	var Changed;
}

/**
	h3d.scene.Object is the base 3D class that all scene tree elements inherit from.
	It can be used to create a virtual container that does not display anything but can contain other objects
	so the various transforms are inherited to its children.
**/
class Object implements hxd.impl.Serializable {

	// TODO: No deallocation/reuse, so we leaking memory everywhere
	static var ObjectId: Int = 0;
	public static final ObjectMap: haxe.ds.Map<Int, Object> = new haxe.ds.IntMap();
	public static final RelativePositionComp: ComponentStorage<RelativePosition> = ComponentStorage.newStorage();
	public static final AbsolutePositionView: ComponentStorage<AbsolutePositionCache> = ComponentStorage.newStorage();
	public static final AnimationComp: ComponentStorage<Animation> = ComponentStorage.newStorage();

	/**
		Numeric ID, will be used to work towards an ECS.
	**/
	public final id: Int = ObjectId++;

	var children : Array<Object>;

	/**
		The parent object in the scene tree.
	**/
	public var parent(default, null) : Object;

	/**
		How many immediate children this object has.
	**/
	public var numChildren(get, never) : Int;

	/**
		The name of the object, can be used to retrieve an object within a tree by using `getObjectByName` (default null)
	**/
	@:s public var name : Null<String>;

	/**
		Various flags, such as whether to render or not.
	**/
	@:s var flags : ObjectFlags;

	/**
		The x position of the object relative to its parent.
	**/
	@:s public var x(get, set) : Float;

	/**
		The y position of the object relative to its parent.
	**/
	@:s public var y(get, set) : Float;

	/**
		The z position of the object relative to its parent.
	**/
	@:s public var z(get, set) : Float;

	/**
		The amount of scaling along the X axis of this object (default 1.0)
	**/
	@:s public var scaleX(get, set) : Float;

	/**
		The amount of scaling along the Y axis of this object (default 1.0)
	**/
	@:s public var scaleY(get, set) : Float;

	/**
		The amount of scaling along the Z axis of this object (default 1.0)
	**/
	@:s public var scaleZ(get, set) : Float;

	/**
		This is an additional optional transformation that is performed before other local transformations.
		It is used by the animation system.
	**/
	public var initialTransformDone(get, set): Bool;
	public var initialTransform: h3d.Matrix;
	public var defaultTransform(default, set) : h3d.Matrix;
	@:s public var currentAnimation(get, never) : h3d.anim.Animation;
	inline function get_currentAnimation() return anim.currentAnimation;

	/**
		Is the object and its children are displayed on screen (default true).
	**/
	public var visible(get, set) : Bool;

	/**
		Inform that the object is not to be displayed and his animation doesn't have to be sync.
	**/
	public var culled(get, set) : Bool;

	/**
		When an object is not visible or culled, its animation does not get synchronized unless you set alwaysSync=true
	**/
	public var alwaysSync(get, set) : Bool;

	/**
		Is the Object visible for the purposes of sync.
	
		To replace RenderContext.SyncContext::visibileFlag

		- Current object during a syncChildren updates it so children can query it
		- If an object is visible and it hasn't been culled then it's considered visible
		- Children query the parent, which breaks the SyncContext dependency

		Once all SyncContext dependencies no longer require depth first traversal,
		we can switch to breadth first traversal and work towards ECS.

		NB: This isn't public because it's only ever managed in the graph
	**/
	var syncVisibleFlag(get, set) : Bool;

	/**
		Whether the syncChildren process should continue or stop, this is mostly if
		the animation removes this object and we need to stop.

		This is required for breadth first traversal when doing recursive sync.
	**/
	var syncContinueFlag(get, set) : Bool;

	/**
		Whether the sync resulted in any sort of position change.
	**/
	var syncChangedFlag(get, set) : Bool;

	/**
		When enabled, the object bounds are ignored when using getBounds()
	**/
	public var ignoreBounds(get, set) : Bool;

	/**
		When enabled, the object can be serialized (default : true)
	**/
	public var allowSerialize(get, set) : Bool;

	/**
		When selecting the lights to apply to this object, we will use the camera target as reference
		instead of the object absolute position. This is useful for very large objects so they can get good lighting.
	**/
	public var lightCameraCenter(get, set) : Bool;


	public var cullingCollider : h3d.col.Collider;

	public var absPos(default, null) : h3d.Matrix;
	var invPos : h3d.Matrix;
	var qRot(get, set) : h3d.Quat;
	var posChanged(get,set) : Bool;
	var allocated(get,set) : Bool;
	var lastFrame : Int;

	// Start of transformation to arrays of components
	var relPos(get, null): RelativePosition;
	inline function get_relPos() return Object.RelativePositionComp[this.id];
	var anim(get, null): Animation;
	inline function get_anim() return Object.AnimationComp[this.id];

	// Static factor methods to start indirect new calls

	public static function createObject( ?parent : Object = null ) {
		return new Object(parent);
	}

	public static function createScene( ?createRenderer = true, ?createLightSystem = true ) {
		return new Scene(createRenderer, createLightSystem);
	}

	public static function createGraphics( ?parent : Object = null ) {
		return new Graphics(parent);
	}

	public static function createBox( ?colour = 0xFFFF0000, ?bounds : h3d.col.Bounds = null, ?depth = true, ?parent = null) {
		return new Box(colour, bounds, depth, parent);
	}

	public static function createSphere( ?colour = 0xFFFF0000, ?radius : Float = 1.0, ?depth = true, ?parent = null ) {
		return new Sphere(colour, radius, depth, parent);
	}

	public static function createMesh( primitive, ?material = null, ?parent = null ) {
		return new Mesh(primitive, material, parent);
	}

	public static function createMeshBatch( primitive, ?material = null, ?parent = null ) {
		return new MeshBatch(primitive, material, parent);
	}

	public static function createMultiMaterial( primitive, ?material = null, ?parent = null ) {
		return new MultiMaterial(primitive, material, parent);
	}

	public static function createSkin( s, ?mat = null, ?parent = null ) {
		return new Skin(s, mat, parent);
	}

	@:allow(h3d.scene.Skin.getObjectByName)
	private static function createSkinJoint( skin : h3d.scene.Skin, joint : h3d.anim.Skin.Joint ) {
		return new Skin.Joint(skin, joint);
	}

	public static function createParticles( ?texture = null, ?parent = null ) {
		return new h3d.parts.Particles(texture, parent);
	}

	public static function createGpuParticles( ?parent = null ) {
		return new h3d.parts.GpuParticles(parent);
	}

	public static function createEmitter( ?state = null, ?parent = null ) {
		return new h3d.parts.Emitter(state, parent);
	}

	public static function createWorld(chunkSize, worldSize, parent, ?autoCollect = true) {
		return new World(chunkSize, worldSize, parent, autoCollect);
	}

	public static function createFwdDirLight( ?dir : h3d.Vector = null, ?parent = null ) {
		return new h3d.scene.fwd.DirLight(dir, parent);
	}

	public static function createFwdPointLight( ?parent = null ) {
		return new h3d.scene.fwd.PointLight(parent);
	}

	public static function createPbrDecal( primitive, ?material = null, ?parent = null ) {
		return new h3d.scene.pbr.Decal(primitive, material, parent);
	}

	public static function createPbrDirLight( ?dir : h3d.Vector = null, ?parent = null ) {
		return new h3d.scene.pbr.DirLight(dir, parent);
	}

	public static function createPbrPointLight( ?parent = null ) {
		return new h3d.scene.pbr.PointLight(parent);
	}

	public static function createPbrSpotLight( ?parent = null ) {
		return new h3d.scene.pbr.SpotLight(parent);
	}

	public static function createInteractive( shape, ?parent = null) {
		return new Interactive(shape, parent);
	}

	/**
		Create a new empty object, and adds it to the parent object if not null.

		No longer allow direct creation, use static methods instead.
	**/
	private function new( ?parent : Object ) {
		flags = new ObjectFlags(0);
		absPos = new h3d.Matrix();
		absPos.identity();
		allowSerialize = true;
		ObjectMap.set(this.id, this);
		// Assuming we allocate position every time, so id and index line up
		Object.RelativePositionComp.add(new RelativePosition(id));
		Object.AnimationComp.add(new Animation(id));
		Object.AbsolutePositionView.add(new AbsolutePositionCache(id));

		posChanged = false;
		visible = true;
		syncVisibleFlag = true;
		syncContinueFlag = true;
		syncChangedFlag = posChanged;
		children = [];
		if( parent != null )
			parent.addChild(this);
	}

	inline function get_x() return this.relPos.x;
	inline function set_x(v) return this.relPos.x = v;
	inline function get_y() return this.relPos.y;
	inline function set_y(v) return this.relPos.y = v;
	inline function get_z() return this.relPos.z;
	inline function set_z(v) return this.relPos.z = v;
	inline function get_scaleX() return this.relPos.scaleX;
	inline function set_scaleX(v) return this.relPos.scaleX = v;
	inline function get_scaleY() return this.relPos.scaleY;
	inline function set_scaleY(v) return this.relPos.scaleY = v;
	inline function get_scaleZ() return this.relPos.scaleZ;
	inline function set_scaleZ(v) return this.relPos.scaleZ = v;
	inline function get_qRot() return this.relPos.rotationQuat;
	inline function set_qRot(q) return this.relPos.rotationQuat = q;
	inline function get_visible() return flags.has(FVisible);
	inline function get_syncVisibleFlag() return flags.has(FSyncVisibility);
	inline function get_syncContinueFlag() return flags.has(FSyncContinue);
	inline function get_syncChangedFlag() return flags.has(FSyncChanged);
	inline function get_allocated() return flags.has(FAllocated);
	inline function get_posChanged() return this.relPos.posChanged;
	inline function get_culled() return flags.has(FCulled);
	inline function get_lightCameraCenter() return flags.has(FLightCameraCenter);
	inline function get_alwaysSync() return flags.has(FAlwaysSync);
	inline function get_ignoreBounds() return flags.has(FIgnoreBounds);
	inline function get_allowSerialize() return !flags.has(FNoSerialize);
	inline function get_initialTransformDone() return flags.has(FInitialTransformDone);
	inline function set_posChanged(b) return this.relPos.posChanged = (b);
	inline function set_culled(b) return flags.set(FCulled, b);
	inline function set_visible(b) return flags.set(FVisible,b);
	inline function set_syncVisibleFlag(b) return flags.set(FSyncVisibility,b);
	inline function set_syncContinueFlag(b) return flags.set(FSyncContinue,b);
	inline function set_syncChangedFlag(b) return flags.set(FSyncChanged,b);
	inline function set_allocated(b) return flags.set(FAllocated, b);
	inline function set_lightCameraCenter(b) return flags.set(FLightCameraCenter, b);
	inline function set_alwaysSync(b) return flags.set(FAlwaysSync, b);
	inline function set_ignoreBounds(b) return flags.set(FIgnoreBounds, b);
	inline function set_allowSerialize(b) return !flags.set(FNoSerialize, !b);
	inline function set_initialTransformDone(b) return flags.set(FInitialTransformDone, b);

	/**
		Create an animation instance bound to the object, set it as currentAnimation and play it.
	**/
	public function playAnimation( a : h3d.anim.Animation ) {
		return anim.playAnimation(a);
	}

	/**
		Change the current animation. This animation should be an instance that was previously created by playAnimation.
	**/
	public function switchToAnimation( a : h3d.anim.Animation ) {
		return anim.switchToAnimation(a);
	}

	/**
		Stop the current animation. If recursive is set to true, all children will also stop their animation
	**/
	public function stopAnimation( ?recursive = false ) {
		anim.stopAnimation();
		
		// TODO can't do this with the component, should be in a system.
		if(recursive) {
			for(c in children)
				c.stopAnimation(true);
		}
	}

	/**
		Return the total number of children, recursively.
	**/
	public function getObjectsCount() {
		var k = 0;
		for( c in children )
			k += c.getObjectsCount() + 1;
		return k;
	}

	/**
		Search for a material recursively by name, return it or null if not found.
	**/
	public function getMaterialByName( name : String ) : h3d.mat.Material {
		for( o in children ) {
			var m = o.getMaterialByName(name);
			if( m != null ) return m;
		}
		return null;
	}

	/**
		Find a single object in the tree by calling `f` on each and returning the first not-null value returned, or null if not found.
	**/
	public function find<T>( f : Object -> Null<T> ) : Null<T> {
		var v = f(this);
		if( v != null )
			return v;
		for( o in children ) {
			var v = o.find(f);
			if( v != null ) return v;
		}
		return null;
	}

	/**
		Find several objects in the tree by calling `f` on each and returning all the not-null values returned.
	**/
	public function findAll<T>( f : Object -> Null<T>, ?arr : Array<T> ) : Array<T> {
		if( arr == null ) arr = [];
		var v = f(this);
		if( v != null )
			arr.push(v);
		for( o in children )
			o.findAll(f,arr);
		return arr;
	}

	/**
		Return all materials in the tree.
	**/
	public function getMaterials( ?a : Array<h3d.mat.Material> ) {
		if( a == null ) a = [];
		for( o in children )
			o.getMaterials(a);
		return a;
	}

	/**
		Convert a local position (or [0,0] if pt is null) relative to the object origin into an absolute global position, applying all the inherited transforms.
	**/
	public function localToGlobal( ?pt : h3d.Vector ) {
		syncPos();
		if( pt == null ) pt = new h3d.Vector();
		pt.transform3x4(absPos);
		return pt;
	}

	/**
		Convert an absolute global position into a local position relative to the object origin, applying all the inherited transforms.
	**/
	public function globalToLocal( pt : h3d.Vector ) {
		pt.transform3x4(getInvPos());
		return pt;
	}

	/**
		Returns the updated inverse position matrix. Please note that this is not a copy and should not be modified.
	**/
	public function getInvPos() {
		syncPos();
		if( invPos == null ) {
			invPos = new h3d.Matrix();
			invPos._44 = 0;
		}
		if( invPos._44 == 0 )
			invPos.inverse3x4(absPos);
		return invPos;
	}

	/**
		Return the bounds of this object and all its children, in absolute global coordinates.
	**/
	@:final public function getBounds( ?b : h3d.col.Bounds ) {
		if( b == null )
			b = new h3d.col.Bounds();
		if( parent != null )
			parent.syncPos();
		return getBoundsRec(b);
	}

	function getBoundsRec( b : h3d.col.Bounds ) {
		if( posChanged ) {
			for( c in children )
				c.posChanged = true;
			posChanged = false;
			calcAbsPos();
		}
		for( c in children )
			c.getBoundsRec(b);
		return b;
	}

	/**
		Return all meshes part of this tree
	**/
	public function getMeshes( ?out : Array<Mesh> ) {
		if( out == null ) out = [];
		var m = hxd.impl.Api.downcast(this, Mesh);
		if( m != null ) out.push(m);
		for( c in children )
			c.getMeshes(out);
		return out;
	}

	/**
		Search for an mesh recursively by name, return null if not found.
	**/
	public function getMeshByName( name : String) {
		return hxd.impl.Api.downcast(getObjectByName(name), Mesh);
	}

	/**
		Search for an object recursively by name, return null if not found.
	**/
	public function getObjectByName( name : String ) {
		if( this.name == name )
			return this;
		for( c in children ) {
			var o = c.getObjectByName(name);
			if( o != null ) return o;
		}
		return null;
	}

	/**
		Make a copy of the object and all its children.
	**/
	public function clone( ?o : Object ) : Object {
		if( o == null ) o = h3d.scene.Object.createObject();
		#if debug
		if( Type.getClass(o) != Type.getClass(this) ) throw this + " is missing clone()";
		#end
		o.x = x;
		o.y = y;
		o.z = z;
		o.scaleX = scaleX;
		o.scaleY = scaleY;
		o.scaleZ = scaleZ;
		o.qRot.load(qRot);
		o.name = name;
		o.visible = visible;
		if( defaultTransform != null )
			o.defaultTransform = defaultTransform.clone();
		for( c in children ) {
			var c = c.clone();
			c.parent = o;
			o.children.push(c);
		}
		return o;
	}

	/**
		Add a child object at the end of the children list.
	**/
	public function addChild( o : Object ) {
		var p = this;
		while( p != null ) {
			if( p == o ) throw "Recursive addChild";
			p = p.parent;
		}
		if( o.parent != null ) {
			// prevent calling onDelete
			var old = o.allocated;
			o.allocated = false;
			o.parent.removeChild(o);
			o.allocated = old;
		}
		children.push(o);
		if( !allocated && o.allocated )
			o.onRemove();
		o.parent = this;
		o.posChanged = true;
		// ensure that proper alloc/delete is done if we change parent
		if( allocated ) {
			if( !o.allocated )
				o.onAdd();
			else
				o.onParentChanged();
		}
	}

	/**
		Iterate on all mesh that are currently visible and not culled in the tree. Call `callb` for each mesh found.
	**/
	public function iterVisibleMeshes( callb : Mesh -> Void ) {
		if( !visible || culled )
			return;
		if( !culled ) {
			var m = hxd.impl.Api.downcast(this, Mesh);
			if( m != null ) callb(m);
		}
		for( o in children )
			o.iterVisibleMeshes(callb);
	}

	function onParentChanged() {
		for( c in children )
			c.onParentChanged();
	}

	// kept for internal init
	function onAdd() {
		allocated = true;
		for( c in children )
			c.onAdd();
	}

	// kept for internal cleanup
	function onRemove() {
		allocated = false;
		ObjectMap.remove(this.id);
		for( c in children )
			c.onRemove();
	}

	/**
		Remove the given object from our immediate children list if it's part of it.
	**/
	public function removeChild( o : Object ) {
		if( children.remove(o) ) {
			if( o.allocated ) o.onRemove();
			o.parent = null;
			o.posChanged = true;
		}
	}

	/**
		Remove all children from our immediate children list
	**/
	public function removeChildren() {
		while( numChildren>0 )
			removeChild( getChildAt(0) );
	}

	/**
		Same as parent.removeChild(this), but does nothing if parent is null.
		In order to capture add/removal from scene, you can override onAdd/onRemove/onParentChanged
	**/
	public inline function remove() {
		if( this != null && parent != null ) parent.removeChild(this);
	}

	/**
		Return the Scene this object is part of, or null if not added to a Scene.
	**/
	public function getScene() {
		var p = this;
		while( p.parent != null ) p = p.parent;
		return hxd.impl.Api.downcast(p, Scene);
	}

	/**
		Returns the updated absolute position matrix. Please note that this is not a copy so it should not be modified.
	**/
	public function getAbsPos() {
		syncPos();
		return absPos;
	}

	/**
		Tell if the object is a Mesh.
	**/
	public inline function isMesh() {
		return hxd.impl.Api.downcast(this, Mesh) != null;
	}

	/**
		If the object is a Mesh, return the corresponding Mesh. If not, throw an exception.
	**/
	public function toMesh() : Mesh {
		var m = hxd.impl.Api.downcast(this, Mesh);
		if( m != null )
			return m;
		throw this + " is not a Mesh";
	}

	/**
		Tell if the object is a Skin.
	**/
	public inline function isSkin() {
		return hxd.impl.Api.downcast(this, Skin) != null;
	}

	/**
		If the object is a Skin, return the corresponding Skin. If not, throw an exception.
	**/
	public function toSkin() : Skin {
		var m = hxd.impl.Api.downcast(this, Skin);
		if( m != null )
			return m;
		throw this + " is not a Skin";
	}

	/**
		Build and return the global absolute recursive collider for the object.
		Returns null if no collider was found.
	**/
	@:final public function getCollider() : h3d.col.Collider {
		var colliders = [];
		var col = getGlobalCollider();
		if( col != null )
			colliders.push(col);
		for( obj in children ) {
			var c = obj.getCollider();
			if( c == null ) continue;
			var cgrp = hxd.impl.Api.downcast(c, h3d.col.Collider.GroupCollider);
			if( cgrp != null ) {
				for( c in cgrp.colliders )
					colliders.push(c);
			} else
				colliders.push(c);
		}
		if( colliders.length == 0 )
			return null;
		if( colliders.length == 1 )
			return colliders[0];
		return new h3d.col.Collider.GroupCollider(colliders);
	}

	/**
		Same as getLocalCollider, but returns an absolute collider instead of a local one.
	**/
	public function getGlobalCollider() : h3d.col.Collider {
		var col = getLocalCollider();
		return col == null ? null : new h3d.col.ObjectCollider(this, col);
	}

	/**
		Build and returns the local relative not-recursive collider for the object, or null if this object does not have a collider.
	**/
	public function getLocalCollider() : h3d.col.Collider {
		return null;
	}

	function draw( ctx : RenderContext.DrawContext ) {
	}

	function calcAbsPos() {
		qRot.toMatrix(absPos);
		// prepend scale
		absPos._11 *= scaleX;
		absPos._12 *= scaleX;
		absPos._13 *= scaleX;
		absPos._21 *= scaleY;
		absPos._22 *= scaleY;
		absPos._23 *= scaleY;
		absPos._31 *= scaleZ;
		absPos._32 *= scaleZ;
		absPos._33 *= scaleZ;
		absPos._41 = x;
		absPos._42 = y;
		absPos._43 = z;
		if( parent != null )
			absPos.multiply3x4inline(absPos, parent.absPos);
		if( !initialTransformDone && initialTransform != null ) {
			absPos.multiply3x4inline(absPos, initialTransform);
			initialTransformDone = true;
		}
		// animation is applied before every other transform
		if( defaultTransform != null )
			absPos.multiply3x4inline(defaultTransform, absPos);
		if( invPos != null )
			invPos._44 = 0; // mark as invalid
	}

	final function syncSelf( ctx : RenderContext.SyncContext ) : Void {
		updateSyncStateSelf();

		this.syncChangedFlag = (switch(animateSelf(new RenderContext.AnimationContext(ctx))) {
			case Removed: this.syncContinueFlag = false; return;
			default: posChanged || this.syncChangedFlag;
		});

		if( this.syncChangedFlag ) calcAbsPos();

		sync(ctx);
		this.posChanged = false;
		this.lastFrame = ctx.frame;
	}

	/**
		Used to keep various flags for sync/syncRec up to date.
	**/
	final inline function updateSyncStateSelf() {
		this.syncContinueFlag = true;
		if( this.parent != null ) {
			this.syncChangedFlag = parent.syncChangedFlag;
			this.syncVisibleFlag = parent.syncVisibleFlag;
		} else {
			this.syncChangedFlag = posChanged;
			this.syncVisibleFlag = visible && !culled;
		}
	}

	final inline function animateSelf( ctx : RenderContext.AnimationContext ) : AnimationResult {
		if( currentAnimation != null ) {
			var old = parent;
			var dt = ctx.elapsedTime;
			while( dt > 0 && currentAnimation != null )
				dt = currentAnimation.update(dt);

			if( currentAnimation != null && ((syncVisibleFlag && visible && !culled) || alwaysSync)  )
				currentAnimation.sync();
			if( parent == null && old != null )
				return AnimationResult.Removed; // if we were removed by an animation event

			// Handle animations making a visible object invisible or culled(?)
			this.syncVisibleFlag = this.syncVisibleFlag && visible && !culled;

			return AnimationResult.Animated;
	}

		return AnimationResult.NoAnimation;
	}

	function sync( ctx : RenderContext.SyncContext ) {
	}

	final function syncChildren( ctx : RenderContext.SyncContext ) : Void {
		// First sync only the immediate children.
		var p = 0;
		while( p < children.length ) {
			final c = children[p];
			if( c == null ) {
				continue;
			}
			if( c.lastFrame != ctx.frame ) {
				c.syncSelf(ctx);
			}
			// if the object was removed, let's restart again.
			// our lastFrame ensures that no object will get synched twice
			if( children[p] != c ) {
				p = 0;
			} else
				p++;
		}

		// Now recurse per child
		p = 0;
		while( p < children.length ) {
			final c = children[p];
			if( c.syncContinueFlag ) {
				c.syncChildren(ctx);
			}
			p++;
		}

		postSyncChildren(ctx);
	}
	
	function postSyncChildren( ctx : RenderContext.SyncContext ) : Void {
		// this is mostly a hack for h3d.scene.World's need to override syncRec
	}

	final function updateAbsPosChildren( changed: Bool ) {
		if( !changed ) return;
		for( c in this.children ) {
			c.calcAbsPos();
		}
	}

	function syncPos() {
		if( parent != null ) parent.syncPos();
		if( posChanged ) {
			posChanged = false;
			calcAbsPos();
			for( c in children )
				c.posChanged = true;
		}
	}

	function emit( ctx : RenderContext.EmitContext ) {
	}

	function emitRec( ctx : RenderContext.EmitContext ) {
		if( !visible || (culled && !ctx.computingStatic) )
			return;

		// TODO - Can likely be removed, bring back if some syncing bugs appear
		// fallback in case the object was added during a sync() event and we somehow didn't update it
		// if( posChanged ) {
		// 	// only sync anim, don't update() (prevent any event from occuring during draw())
		// 	if( currentAnimation != null ) currentAnimation.sync();
		// 	posChanged = false;
		// 	calcAbsPos();
		// 	for( c in children )
		// 		c.posChanged = true;
		// }
		if( !culled || ctx.computingStatic )
			emit(ctx);

		for( c in children )
			c.emitRec(ctx);
	}

	inline function set_defaultTransform(v) {
		defaultTransform = v;
		posChanged = true;
		return v;
	}

	/**
		Set the position of the object relative to its parent.
	**/
	public inline function setPosition( x : Float, y : Float, z : Float ) {
		this.x = x;
		this.y = y;
		this.z = z;
		posChanged = true;
	}

	/**
		Set the position, scale and rotation of the object relative to its parent based on the specified transform matrix.
	**/
	static var tmpMat = new h3d.Matrix();
	static var tmpVec = new h3d.Vector();
	public function setTransform( mat : h3d.Matrix ) {
		var s = mat.getScale(tmpVec);
		this.x = mat.tx;
		this.y = mat.ty;
		this.z = mat.tz;
		this.scaleX = s.x;
		this.scaleY = s.y;
		this.scaleZ = s.z;
		tmpMat.load(mat);
		tmpMat.prependScale(1.0 / s.x, 1.0 / s.y, 1.0 / s.z);
		qRot.initRotateMatrix(tmpMat);
		posChanged = true;
	}

	/**
		Rotate around the current rotation axis by the specified angles (in radian).
	**/
	public inline function rotate( rx : Float, ry : Float, rz : Float ) {
		this.relPos.rotate(rx, ry, rz);
	}

	/**
		Set the rotation using the specified angles (in radian).
	**/
	public inline function setRotation( rx : Float, ry : Float, rz : Float ) {
		this.relPos.setRotation(rx, ry, rz);
	}

	/**
		Set the rotation using the specified axis and angle of rotation around it (in radian).
	**/
	public inline function setRotationAxis( ax : Float, ay : Float, az : Float, angle : Float ) {
		this.relPos.setRotationAxis(ax, ay, az, angle);
	}

	/**
		Set the rotation using the specified look at direction
	**/
	public inline function setDirection( v : h3d.Vector ) {
		this.relPos.setDirection(v);
	}

	/**
		Return the direction in which the object rotation is currently oriented to
	**/
	public inline function getDirection() {
		return this.relPos.rotationQuat.getDirection();
	}

	/**
		Return the quaternion representing the current object rotation.
		Dot not modify as it's not a copy.
	**/
	public inline function getRotationQuat() {
		return this.relPos.rotationQuat;
	}

	/**
		Set the quaternion representing the current object rotation.
		Dot not modify the value afterwards as no copy is made.
	**/
	public function setRotationQuat(q) {
		this.relPos.rotationQuat = q;
	}

	/**
		Scale uniformly the object by the given factor.
	**/
	public inline function scale( v : Float ) {
		this.relPos.scale(v);
	}

	/**
		Set the uniform scale for the object.
	**/
	public inline function setScale( v : Float ) {
		this.relPos.setScale(v);
	}

	/**
		Return both class name and object name if any.
	**/
	public function toString() {
		return Type.getClassName(Type.getClass(this)).split(".").pop() + (name == null ? "" : "(" + name + ")");
	}

	/**
		Return the `n`th element among our immediate children list, or null if there is no.
	**/
	public inline function getChildAt( n ) {
		return children[n];
	}

	/**
		Return the index of the object `o` within our immediate children list, or `-1` if it is not part of our children list.
	**/
	public function getChildIndex( o ) {
		for( i in 0...children.length )
			if( children[i] == o )
				return i;
		return -1;
	}

	inline function get_numChildren() {
		return children.length;
	}

	/**
		Return an iterator over this object immediate children
	**/
	public inline function iterator() : hxd.impl.ArrayIterator<Object> {
		return new hxd.impl.ArrayIterator(children);
	}

	#if (hxbit && !macro && heaps_enable_serialize)
	function customSerialize( ctx : hxbit.Serializer ) {

		var children = [for( o in children ) if( o.allowSerialize ) o];
		ctx.addInt(children.length);
		for( o in children )
			ctx.addKnownRef(o);
		ctx.addDouble(qRot.x);
		ctx.addDouble(qRot.y);
		ctx.addDouble(qRot.z);
		ctx.addDouble(qRot.w);

		ctx.addBool(defaultTransform != null);
		if( defaultTransform != null ) {
			ctx.addFloat(defaultTransform._11);
			ctx.addFloat(defaultTransform._12);
			ctx.addFloat(defaultTransform._13);
			ctx.addFloat(defaultTransform._21);
			ctx.addFloat(defaultTransform._22);
			ctx.addFloat(defaultTransform._23);
			ctx.addFloat(defaultTransform._31);
			ctx.addFloat(defaultTransform._32);
			ctx.addFloat(defaultTransform._33);
			ctx.addFloat(defaultTransform._41);
			ctx.addFloat(defaultTransform._42);
			ctx.addFloat(defaultTransform._43);
		}

	}

	static var COUNT = 0;

	function customUnserialize( ctx : hxbit.Serializer ) {
		children = [for( i in 0...ctx.getInt() ) ctx.getKnownRef(Object)];
		qRot = new h3d.Quat(ctx.getDouble(), ctx.getDouble(), ctx.getDouble(), ctx.getDouble());

		if( ctx.getBool() ) {
			defaultTransform = new h3d.Matrix();
			defaultTransform.loadValues([
				ctx.getFloat(),
				ctx.getFloat(),
				ctx.getFloat(),
				0,
				ctx.getFloat(),
				ctx.getFloat(),
				ctx.getFloat(),
				0,
				ctx.getFloat(),
				ctx.getFloat(),
				ctx.getFloat(),
				0,
				ctx.getFloat(),
				ctx.getFloat(),
				ctx.getFloat(),
				1
			]);
		}

		// init
		for( c in children )
			c.parent = this;
		allocated = false;
		posChanged = true;
		absPos = new h3d.Matrix();
		absPos.identity();
		if( currentAnimation != null )
			@:privateAccess currentAnimation.initAndBind(this);
	}
	#end

	@:allow(h3d.pass.Default) private static function drawObject(obj: h3d.pass.DrawObject, ctx: RenderContext.DrawContext) {
		final o = Object.ObjectMap.get(obj.id);
		if (o != null)
			o.draw(ctx);
	}
}

private enum abstract RelativePositionFlags(Int) {
	public var FPosChanged = 0x01;
	// public var FFlag = 0x02;
	// public var FFlag = 0x04;
	// public var FFlag = 0x08;
	// public var FFlag = 0x10;

	// public var FAllocated = 0x20;
	// public var FAlwaysSync = 0x40;
	// public var FNoSerialize = 0x100;
	// public var FIgnoreBounds = 0x200;
	// public var FFlag = 0x400;
	// public var FFlag = 0x800;
	// public var FFlag = 0x1000;
	public inline function new(value = 0) {
		this = value;
	}
	public inline function toInt() return this;
	public inline function has(f:RelativePositionFlags) return this & f.toInt() != 0;
	public inline function set(f:RelativePositionFlags, b) {
		if( b ) this |= f.toInt() else this &= ~f.toInt();
		return b;
	}
}

/**
	Rework into just x, y, z + orientation
**/
private class RelativePosition {
	public final id: Int;

	private var flags = new RelativePositionFlags();
	public var posChanged(get, set): Bool;
	inline function get_posChanged() { return this.flags.has(FPosChanged); }
	inline function set_posChanged(v: Bool) { return this.flags.set(FPosChanged, v); }

	/**
		The x position of the object relative to its parent.
	**/
	public var x(default,set) : Float = .0;

	/**
		The y position of the object relative to its parent.
	**/
	public var y(default, set) : Float = .0;

	/**
		The z position of the object relative to its parent.
	**/
	public var z(default, set) : Float = .0;

	/**
		Rotation/Orientation as a quarternion.
	**/
	public var rotationQuat(default, set) : h3d.Quat = new h3d.Quat();
	
	/**
		The amount of scaling along the X axis of this object (default 1.0)
	**/
	@:s public var scaleX(default,set) : Float = 1.;

	/**
		The amount of scaling along the Y axis of this object (default 1.0)
	**/
	@:s public var scaleY(default, set) : Float = 1.;

	/**
		The amount of scaling along the Z axis of this object (default 1.0)
	**/
	@:s public var scaleZ(default,set) : Float = 1.;

	public function new(id: Int) {
		this.id = id;
	}

	inline function set_x(x) {
		posChanged = true;
		return this.x = x;
	}

	inline function set_y(y) {
		posChanged = true;
		return this.y = y;
	}

	inline function set_z(z) {
		posChanged = true;
		return this.z = z;
	}

	inline function set_rotationQuat(q: h3d.Quat) {
		posChanged = true;
		return this.rotationQuat = q;
	}

	/**
		Rotate around the current rotation axis by the specified angles (in radian).
	**/
	public function rotate( rx : Float, ry : Float, rz : Float ) {
		var qTmp = new h3d.Quat();
		qTmp.initRotation(rx, ry, rz);
		this.rotationQuat.multiply(qTmp,this.rotationQuat);
		posChanged = true;
	}

	/**
		Set the rotation using the specified angles (in radian).
	**/
	public function setRotation( rx : Float, ry : Float, rz : Float ) {
		this.rotationQuat.initRotation(rx, ry, rz);
		posChanged = true;
	}

	/**
		Set the rotation using the specified axis and angle of rotation around it (in radian).
	**/
	public function setRotationAxis( ax : Float, ay : Float, az : Float, angle : Float ) {
		this.rotationQuat.initRotateAxis(ax, ay, az, angle);
		posChanged = true;
	}

	/**
		Set the rotation using the specified look at direction
	**/
	public function setDirection( v : h3d.Vector ) {
		this.rotationQuat.initDirection(v);
		posChanged = true;
	}

	inline function set_scaleX(v) {
		scaleX = v;
		posChanged = true;
		return v;
	}

	inline function set_scaleY(v) {
		scaleY = v;
		posChanged = true;
		return v;
	}

	inline function set_scaleZ(v) {
		scaleZ = v;
		posChanged = true;
		return v;
	}

	/**
		Scale uniformly the object by the given factor.
	**/
	public inline function scale(v: Float) {
		scaleX *= v;
		scaleY *= v;
		scaleZ *= v;
		posChanged = true;
	}

	/**
		Set the uniform scale for the object.
	**/
	public inline function setScale(v : Float) {
		scaleX = v;
		scaleY = v;
		scaleZ = v;
		posChanged = true;
	}
}

private class AbsolutePositionCache {
	public final id: Int;

	public final absPos: h3d.Matrix = Matrix.I();
	public final invPos: h3d.Matrix = Matrix.I();

	// TODO Cruft that needs to go with FBX silliness
	public var initialTransformRequired(default, null): Bool = false;
	public var initialTransform(default, set): h3d.Matrix;
	inline function set_initialTransform(t) {
		changed = true;
		initialTransformRequired = true;
		return initialTransform = t;
	}

	public var animationTransform(default, set): h3d.Matrix = null;
	inline function set_animationTransform(m) {
		changed = true;
		return animationTransform = m;
	}

	public var changed(default, null): Bool = true;

	public function new(id) {
		this.id = id;
	}

	public static function update(abs: AbsolutePositionCache, rel: RelativePosition, ?parent: AbsolutePositionCache) {
		if (rel.posChanged || abs.changed) {
			rel.rotationQuat.toMatrix(abs.absPos);
			// prepend scale
			abs.absPos._11 *= rel.scaleX;
			abs.absPos._12 *= rel.scaleX;
			abs.absPos._13 *= rel.scaleX;
			abs.absPos._21 *= rel.scaleY;
			abs.absPos._22 *= rel.scaleY;
			abs.absPos._23 *= rel.scaleY;
			abs.absPos._31 *= rel.scaleZ;
			abs.absPos._32 *= rel.scaleZ;
			abs.absPos._33 *= rel.scaleZ;
			abs.absPos._41 = rel.x;
			abs.absPos._42 = rel.y;
			abs.absPos._43 = rel.z;
			if( parent != null )
				abs.absPos.multiply3x4inline(abs.absPos, parent.absPos);
			if( abs.initialTransformRequired ) {
				if ( abs.initialTransform != null ) {
					abs.absPos.multiply3x4inline(abs.absPos, abs.initialTransform);
				}
				abs.initialTransformRequired = false;
			}
			// animation is applied before every other transform
			if( abs.animationTransform != null )
				abs.absPos.multiply3x4inline(abs.animationTransform, abs.absPos);
			if( abs.invPos != null )
				abs.invPos._44 = 0; // mark as invalid

			abs.changed = false;
			// NB: not managing the posChanged lifetime here yet.
		}
	}
}

private enum RenderFlags {
	FCulled;
	FAllocated;
	FVisible;
}

private class Render {
	public final id: Int;
	public var culled(get, set): Bool;
	public var allocated(get, set): Bool;
	public var visible(get, set): Bool;
	public var cullingCollider : h3d.col.Collider;

	var flags = new haxe.EnumFlags<RenderFlags>();

	inline function get_culled() return flags.has(FCulled);
	inline function set_culled(v) { v ? flags.set(FCulled) : flags.unset(FCulled); return v; }
	inline function get_allocated() return flags.has(FAllocated);
	inline function set_allocated(v) { v ? flags.set(FAllocated) : flags.unset(FAllocated); return v; }
	inline function get_visible() return flags.has(FVisible);
	inline function set_visible(v) { v ? flags.set(FVisible) : flags.unset(FVisible); return v; }

	public function new(id: Int) {
		this.id = id;
	}
}

private class Animation {
	public final id: Int;

	@:s public var currentAnimation(default, null) : h3d.anim.Animation;

	public function new(id: Int) {
		this.id = id;
	}
	
	/**
		Create an animation instance bound to the object, set it as currentAnimation and play it.
	**/
	public function playAnimation( a : h3d.anim.Animation ) {
		return currentAnimation = a.createInstance(Object.ObjectMap.get(this.id));
	}

	/**
		Change the current animation. This animation should be an instance that was previously created by playAnimation.
	**/
	public function switchToAnimation( a : h3d.anim.Animation ) {
		return currentAnimation = a;
	}

	/**
		Stop the current animation.
	**/
	public function stopAnimation() {
		currentAnimation = null;
	}
}

/**
	Creating a layer of indirection for when refactoring will be required,
	this way the type contract can be easily broken and usages easily found. 
**/
abstract ComponentStorage<T>(Array<T>) {
	public function new(arr) { this = arr; }

	@:arrayAccess public inline function get(i: Int) return this[i];
	@:arrayAccess public inline function set(i: Int, t: T) {
		this[i] = t;
		return t;
	}

	public inline function add(t: T) this.push(t);

	public inline static function newStorage<T>() return new ComponentStorage(new Array<T>());
}
