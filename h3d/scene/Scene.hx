package h3d.scene;


/**
	h3d.scene.Scene is the root class for a 3D scene. All root objects are added to it before being drawn on screen.
**/
class Scene extends h3d.scene.Object implements h3d.IDrawable implements hxd.SceneEvents.InteractiveScene {

	/**
		The scene current camera.
	**/
	public var camera : h3d.Camera;

	private var cameraControllerId = CameraController.CameraControllerId.nullRef();
	private var cameraControllerSystem: CameraController.CameraControllerEventHandlerSystem;

	/**
		The scene light system. Can be customized.
	**/
	public var lightSystem : LightSystem;

	/**
		The scene renderer. Can be customized.
	**/
	public var renderer(default,set) : Renderer;

	var ctx : RenderContext;
	var interactives : Array<Interactive>;
	@:allow(h3d.scene.Interactive)
	var events : hxd.SceneEvents;
	var hitInteractives : Array<Interactive>;
	var eventListeners : Array<hxd.Event -> Void>;
	var window : hxd.Window;
	#if debug
	public var checkPasses = true;
	#end
	final sceneStorage : SceneStorage;

	/**
		Create a new scene. A default 3D scene is already available in `hxd.App.s3d`
	**/
	@:allow(h3d.scene.Object.createScene)
	private function new( ?createRenderer = true, ?createLightSystem = true ) {
		super(null);
		window = hxd.Window.getInstance();
		eventListeners = [];
		hitInteractives = [];
		interactives = [];
		camera = new h3d.Camera();
		// update ratio before render (prevent first-frame difference)
		var engine = h3d.Engine.getCurrent();
		if( engine != null )
			camera.screenRatio = engine.width / engine.height;
		ctx = new RenderContext();
		if( createRenderer ) renderer = h3d.mat.MaterialSetup.current.createRenderer();
		if( createLightSystem ) lightSystem = h3d.mat.MaterialSetup.current.createLightSystem();

		this.sceneStorage = new SceneStorage();
	}

	function set_renderer(r) {
		renderer = r;
		if( r != null ) @:privateAccess r.ctx = ctx;
		return r;
	}

	@:noCompletion @:dox(hide) public function setEvents(events) {
		this.events = events;
		this.cameraControllerSystem = (events == null) ?
			null :
			new CameraController.CameraControllerEventHandlerSystem(this.events, this.camera);
	}

	/**
		Add an event listener that will capture all events not caught by an h2d.Interactive
	**/
	public function addEventListener( f : hxd.Event -> Void ) {
		eventListeners.push(f);
	}

	/**
		Remove a previously added event listener, return false it was not part of our event listeners.
	**/
	public function removeEventListener( f : hxd.Event -> Void ) {
		for( e in eventListeners )
			if( Reflect.compareMethods(e, f) ) {
				eventListeners.remove(e);
				return true;
			}
		return false;
	}

	@:dox(hide) @:noCompletion
	public function dispatchListeners(event:hxd.Event) {
		for( l in eventListeners ) {
			l(event);
			if( !event.propagate ) break;
		}
	}

	function sortHitPointByCameraDistance( i1 : Interactive, i2 : Interactive ) {
		var z1 = i1.hitPoint.w;
		var z2 = i2.hitPoint.w;
		if( z1 > z2 )
			return -1;
		return 1;
	}

	@:dox(hide) @:noCompletion
	public function dispatchEvent( event : hxd.Event, to : hxd.SceneEvents.Interactive ) {
		var i : Interactive = cast to;
		// TODO : compute relX/Y/Z
		i.handleEvent(event);
	}

	@:dox(hide) @:noCompletion
	public function isInteractiveVisible( i : hxd.SceneEvents.Interactive ) {
		var o : Object = cast i;
		while( o != this ) {
			if( o == null || !o.visible ) return false;
			o = o.parent;
		}
		return true;
	}

	@:dox(hide) @:noCompletion
	public function handleEvent( event : hxd.Event, last : hxd.SceneEvents.Interactive ) {

		if( interactives.length == 0 )
			return null;

		if( hitInteractives.length == 0 ) {

			var screenX = (event.relX / window.width - 0.5) * 2;
			var screenY = -(event.relY / window.height - 0.5) * 2;
			var p0 = camera.unproject(screenX, screenY, 0);
			var p1 = camera.unproject(screenX, screenY, 1);
			var r = h3d.col.Ray.fromPoints(p0.toPoint(), p1.toPoint());
			var saveR = r.clone();
			var priority = 0x80000000;

			for( i in interactives ) {

				if( i.priority < priority ) continue;

				var p : h3d.scene.Object = i;
				while( p != null && p.visible )
					p = p.parent;
				if( p != null ) continue;

				var minv = i.getInvPos();
				r.transform(minv);

				// check for NaN
				if( r.lx != r.lx ) {
					r.load(saveR);
					continue;
				}

				var hit = i.shape.rayIntersection(r, i.bestMatch);
				if( hit < 0 ) {
					r.load(saveR);
					continue;
				}

				var hitPoint = r.getPoint(hit);
				r.load(saveR);

				i.hitPoint.x = hitPoint.x;
				i.hitPoint.y = hitPoint.y;
				i.hitPoint.z = hitPoint.z;

				if( i.priority > priority ) {
					while( hitInteractives.length > 0 ) hitInteractives.pop();
					priority = i.priority;
				}

				hitInteractives.push(i);
			}

			if( hitInteractives.length == 0 )
				return null;


			if( hitInteractives.length > 1 ) {
				for( i in hitInteractives ) {
					var m = i.invPos;
					var wfactor = 0.;

					// adjust result with better precision
					if( i.preciseShape != null ) {
						r.transform(m);
						var hit = i.preciseShape.rayIntersection(r, i.bestMatch);
						if( hit > 0 ) {
							var hitPoint = r.getPoint(hit);
							i.hitPoint.x = hitPoint.x;
							i.hitPoint.y = hitPoint.y;
							i.hitPoint.z = hitPoint.z;
						} else
							wfactor = 1.;
						r.load(saveR);
					}

					var p = i.hitPoint.clone();
					p.w = 1;
					p.transform3x4(i.absPos);
					p.project(camera.m);
					i.hitPoint.w = p.z + wfactor;
				}
				hitInteractives.sort(sortHitPointByCameraDistance);
			}

			hitInteractives.unshift(null);
		}

		while( hitInteractives.length > 0 ) {

			var i = hitInteractives.pop();
			if( i == null )
				return null;

			event.relX = i.hitPoint.x;
			event.relY = i.hitPoint.y;
			event.relZ = i.hitPoint.z;
			i.handleEvent(event);

			if( event.cancel ) {
				event.cancel = false;
				event.propagate = false;
				continue;
			}

			if( !event.propagate ) {
				while( hitInteractives.length > 0 ) hitInteractives.pop();
			}

			return i;
		}

		return null;
	}

	@:allow(h3d)
	function addEventTarget(i:Interactive) {
		if( interactives.indexOf(i) >= 0 ) throw "assert";
		interactives.push(i);
	}

	@:allow(h3d)
	function removeEventTarget(i:Interactive) {
		if( interactives.remove(i) ) {
			if( events != null ) @:privateAccess events.onRemove(i);
			hitInteractives.remove(i);
		}
	}

	override function clone( ?o : Object ) {
		var s = o == null ? h3d.scene.Object.createScene() : cast o;
		s.camera = camera.clone();
		super.clone(s);
		return s;
	}

	/**
		Free the GPU memory for this Scene and its children
	**/
	public function dispose() {
		if ( allocated )
			onRemove();
		if( hardwarePass != null ) {
			hardwarePass.dispose();
			hardwarePass = null;
		}
		ctx.dispose();
		if(renderer != null) {
			renderer.dispose();
			renderer = new Renderer();
		}
		sceneStorage.reset();
	}

	/**
		Before render() or sync() are called, allow to set how much time has elapsed (in seconds) since the last frame in order to update scene animations.
		This is managed automatically by hxd.App
	**/
	public function setElapsedTime( elapsedTime ) {
		ctx.elapsedTime = elapsedTime;
	}

	var hardwarePass : h3d.pass.HardwarePick;

	/**
		Use GPU rendering to pick a model at the given pixel position.
		hardwarePick() will check all scene visible meshes bounds against a ray cast with current camera, then draw them into a 1x1 pixel texture with a specific shader.
		The texture will then be read and the color will identify the object that was rendered at this pixel.
		This is a very precise way of doing scene picking since it performs exactly the same transformations (skinning, custom shaders, etc.) but might be more costly than using CPU colliders.
		Please note that when done during/after rendering, this might clear the screen on some platforms so it should always be done before rendering.
	**/
	public function hardwarePick( pixelX : Float, pixelY : Float): Object {
		var engine = h3d.Engine.getCurrent();
		camera.screenRatio = engine.width / engine.height;
		camera.update();
		ctx.start(camera, engine, this);

		var ray = camera.rayFromScreen(pixelX, pixelY);
		var savedRay = ray.clone();

		iterVisibleMeshes(function(m) {
			if( m.primitive == null ) return;
			ray.transform(m.getInvPos());
			if( m.primitive.getBounds().rayIntersection(ray,false) >= 0 )
				ctx.emitPass(m.material.mainPass, m);
			ray.load(savedRay);
		});

		ctx.lightSystem = null;

		var found = null;
		var passes = new h3d.pass.PassList(@:privateAccess ctx.passes);

		if( !passes.isEmpty() ) {
			var p = hardwarePass;
			if( p == null )
				hardwarePass = p = new h3d.pass.HardwarePick();
			ctx.setGlobal("depthMap", { texture : h3d.mat.Texture.fromColor(0xFF00000, 0) });
			p.pickX = pixelX;
			p.pickY = pixelY;
			p.setContext(ctx);
			p.draw(passes);
			if( p.pickedIndex >= 0 )
				for( po in passes )
					if( p.pickedIndex-- == 0 ) {
						found = Std.downcast(Object.ObjectMap.get(po.obj.id), h3d.scene.Object);
						break;
					}
		}

		ctx.done();
		return found;
	}

	function syncScene( ctx : RenderContext.SyncContext ) {
		this.syncContinueFlag = true;
		this.syncVisibleFlag = true;

		syncChildren(ctx);
	}

	/**
		Synchronize the scene without rendering, updating all objects and animations by the given amount of time, in seconds.
	**/
	public function syncOnly( et : Float ) {
		var engine = h3d.Engine.getCurrent();
		setElapsedTime(et);
		updateCamera(engine, camera);
		ctx.start(camera, engine, this);
		syncScene(new RenderContext.SyncContext(ctx));
		ctx.done();
	}

	/**
		Perform a rendering with `RendererContext.computingStatic=true`, allowing the computation of static shadow maps, etc.
	**/
	public function computeStatic() {
		var old = ctx.elapsedTime;
		ctx.elapsedTime = 0;
		ctx.computingStatic = true;
		render(h3d.Engine.getCurrent());
		ctx.computingStatic = false;
		ctx.elapsedTime = old;
	}

	/**
		Render the scene on screen. Internal usage only.
	**/
	public function render( engine : h3d.Engine ) {
		allocateScene(this);
		updateCamera(engine, camera);
		realRender(engine, this, this.ctx, this.camera, this.renderer, this.lightSystem);
	}

	private static inline function allocateScene(scene: Scene) {
		if( !scene.allocated )
			scene.onAdd();
	}

	private static inline function updateCamera(engine: h3d.Engine, camera: h3d.Camera) {
		camera.screenRatio = engine.getTargetScreenRation();
		camera.update();
	}

	@:access(h3d.mat.Pass)
	@:access(h3d.scene.RenderContext)
	private static function realRender(engine: h3d.Engine, scene: Scene, ctx: RenderContext, camera: h3d.Camera, renderer: h3d.scene.Renderer, lightSystem: h3d.scene.LightSystem) {
		if( camera.rightHanded )
			engine.driver.setRenderFlag(CameraHandness,1);

		ctx.start(camera, engine, scene);
		renderer.start();

		scene.syncScene(new RenderContext.SyncContext(ctx));
		if(scene.cameraControllerId.isNotNull())
			CameraController.sync(scene.sceneStorage.selectCameraController(scene.cameraControllerId), camera, ctx.elapsedTime);
		scene.emitRec(new RenderContext.EmitContext(ctx));

		ctx.sortPasses();

		// group by pass implementation
		var curPass = ctx.passes;
		var passes = [];
		while( curPass != null ) {
			var passId = curPass.pass.passId;
			var p = curPass, prev = null;
			while( p != null && p.pass.passId == passId ) {
				prev = p;
				p = p.next;
			}
			prev.next = null;
			var pobjs = ctx.cachedPassObjects[++ctx.passIndex];
			if( pobjs == null ) {
				pobjs = new Renderer.PassObjects();
				ctx.cachedPassObjects[ctx.passIndex] = pobjs;
			}
			pobjs.name = curPass.pass.name;
			pobjs.passes.init(curPass);
			passes.push(pobjs);
			curPass = p;
		}

		// send to rendered
		if( lightSystem != null ) {
			ctx.lightSystem = lightSystem;
			lightSystem.initLights(ctx);
		}
		renderer.process(passes);

		// check that passes have been rendered
		#if debug
		if( !ctx.computingStatic && scene.checkPasses)
			for( p in passes )
				if( !p.rendered )
					trace("Pass " + p.name+" has not been rendered : don't know how to handle.");
		#end

		if( camera.rightHanded )
			engine.driver.setRenderFlag(CameraHandness,0);

		ctx.done();
	}

	/**
		Serialize the scene content as HSD bytes (see hxd.fmt.hsd package). Requires -lib hxbit
	**/
	public function serializeScene() : haxe.io.Bytes {
		#if hxbit
		var s = new hxd.fmt.hsd.Serializer();
		return s.saveHSD(this, false, camera);
		#else
		throw "You need -lib hxbit to serialize the scene data";
		#end
	}

	#if (hxbit && !macro && heaps_enable_serialize)
	override function customSerialize(ctx:hxbit.Serializer) {
		throw this + " should not be serialized";
	}
	#end

	public function createCameraController( ?distance : Float ) {
		this.cameraControllerId = this.sceneStorage.insertCameraController(this.cameraControllerSystem, distance);

        // Crappy On Insert Trigger
		final ccr:CameraController.CameraControllerRow = this.sceneStorage.selectCameraController(this.cameraControllerId);
        CameraController.onAdd(ccr, this, this.camera);

		return new h3d.scene.CameraController(ccr);
	}

	public function createMesh( primitive : h3d.prim.Primitive, ?material : h3d.mat.Material = null, ?parent : Object = null ) {
		parent = parent == null ? this : parent;
		final eid = this.sceneStorage.insertEntity();
		final id = this.sceneStorage.insertMesh(eid, primitive, material == null ? [] : [material]);

		final rowRef = new h3d.scene.Mesh.MeshRowRef(id, this.sceneStorage);

		return new h3d.scene.Mesh(rowRef, parent);
	}

	public function createMeshWithMaterials( primitive : h3d.prim.Primitive, ?materials : Array<h3d.mat.Material> = null, ?parent : Object = null ) {
		parent = parent == null ? this : parent;
		final eid = this.sceneStorage.insertEntity();
		final id = this.sceneStorage.insertMesh(eid, primitive, materials == null ? [] : materials);

		final rowRef = new h3d.scene.Mesh.MeshRowRef(id, this.sceneStorage);

		return new h3d.scene.Mesh(rowRef, parent);
	}

	public function createGraphics( ?parent : Object = null ) {
		parent = parent == null ? this : parent;
		final eid = this.sceneStorage.insertEntity();
		final id = this.sceneStorage.insertGraphics(eid);

		final rowRef = new h3d.scene.Graphics.GraphicsRowRef(id, this.sceneStorage);
		
		// TODO - hacky, but the primitive is setup in the GraphicsRow
		final mid = this.sceneStorage.insertMesh(eid, rowRef.getRow().bprim, null);
		final mRowRef = new h3d.scene.Mesh.MeshRowRef(mid, this.sceneStorage);

		return new h3d.scene.Graphics(rowRef, mRowRef, parent);
	}

	public function createBox( ?colour = 0xFFFF0000, ?bounds : h3d.col.Bounds = null, ?depth : Bool = true, ?parent : Object = null ) {
		parent = parent == null ? this : parent;
		final eid = this.sceneStorage.insertEntity();
		final gid = this.sceneStorage.insertGraphics(eid);
		final id = this.sceneStorage.insertBox(eid, colour, bounds);
		
		final rowRef = new h3d.scene.Box.BoxRowRef(id, this.sceneStorage);
		final gRowRef = new h3d.scene.Graphics.GraphicsRowRef(gid, this.sceneStorage);
		
		// TODO - hacky, but the primitive is setup in the GraphicsRow
		final mid = this.sceneStorage.insertMesh(eid, gRowRef.getRow().bprim, null);
		final mRowRef = new h3d.scene.Mesh.MeshRowRef(mid, this.sceneStorage);

		return new h3d.scene.Box(rowRef, gRowRef, mRowRef, depth, parent);
	}

	public function createSphere( ?colour = 0xFFFF0000, ?radius : Float = 1.0, ?depth : Bool = true, ?parent : Object = null ) {
		parent = parent == null ? this : parent;
		final eid = this.sceneStorage.insertEntity();
		final gid = this.sceneStorage.insertGraphics(eid);
		final id = this.sceneStorage.insertSphere(eid, colour, radius);
		
		final rowRef = new h3d.scene.Sphere.SphereRowRef(id, this.sceneStorage);
		final gRowRef = new h3d.scene.Graphics.GraphicsRowRef(gid, this.sceneStorage);
		
		// TODO - hacky, but the primitive is setup in the GraphicsRow
		final mid = this.sceneStorage.insertMesh(eid, gRowRef.getRow().bprim, null);
		final mRowRef = new h3d.scene.Mesh.MeshRowRef(mid, this.sceneStorage);

		return new h3d.scene.Sphere(rowRef, gRowRef, mRowRef, depth, parent);
	}

	public function createSkin( ?skinData:h3d.anim.Skin = null, ?materials : Array<h3d.mat.Material> = null, ?parent : Object = null ) {
		parent = parent == null ? this : parent;
		final eid = this.sceneStorage.insertEntity();
		final mid = this.sceneStorage.insertMesh(eid, null, materials);
		final id = this.sceneStorage.insertSkin(eid, skinData);

		final rowRef = new h3d.scene.Skin.SkinRowRef(id, this.sceneStorage);
		final mRowRef = new h3d.scene.Mesh.MeshRowRef(mid, this.sceneStorage);

		return new h3d.scene.Skin(rowRef, mRowRef, parent);
	}

	public function createMeshBatch( primitive : h3d.prim.MeshPrimitive, materials : Array<h3d.mat.Material> = null, parent : Object = null ) {
		parent = parent == null ? this : parent;
		final eid = this.sceneStorage.insertEntity();
		final id  = this.sceneStorage.insertMeshBatch(eid, primitive);
		
		final rowRef = new h3d.scene.MeshBatch.MeshBatchRowRef(id, this.sceneStorage);
		final mid = this.sceneStorage.insertMesh(eid, rowRef.getRow().instanced, materials);
		final mRowRef = new h3d.scene.Mesh.MeshRowRef(mid, this.sceneStorage);

		return new h3d.scene.MeshBatch(rowRef, mRowRef, parent);
	}

	public function createPbrDecal( primitive : h3d.prim.Primitive, materials : Array<h3d.mat.Material> = null, parent : Object = null ) {
		parent = parent == null ? this : parent;
		final eid = this.sceneStorage.insertEntity();
		final mid = this.sceneStorage.insertMesh(eid, primitive, materials);
		final id  = this.sceneStorage.insertDecal(eid);

		final rowRef = new h3d.scene.pbr.Decal.DecalRowRef(id, this.sceneStorage);
		final mRowRef = new h3d.scene.Mesh.MeshRowRef(mid, this.sceneStorage);

		return new h3d.scene.pbr.Decal(rowRef, mRowRef, parent);
	}

	public function createParticles( ?texture : h3d.mat.Texture = null, parent : Object = null ) {
		parent = parent == null ? this : parent;
		final eid = this.sceneStorage.insertEntity();
		final mid = this.sceneStorage.insertMesh(eid, null, null);
		final id  = this.sceneStorage.insertParticles(eid);

		final rowRef = new h3d.parts.Particles.ParticlesRowRef(id, this.sceneStorage);
		final mRowRef = new h3d.scene.Mesh.MeshRowRef(mid, this.sceneStorage);
		
		return new h3d.parts.Particles(rowRef, mRowRef, texture, parent);
	}

	public function createEmitter( ?state : h3d.parts.Data.State = null, parent : Object = null ) {
		parent = parent == null ? this : parent;
		final eid = this.sceneStorage.insertEntity();
		final mid = this.sceneStorage.insertMesh(eid, null, null);
		final pid = this.sceneStorage.insertParticles(eid);
		final id  = this.sceneStorage.insertEmitter(eid, state);

		final rowRef = new h3d.parts.Emitter.EmitterRowRef(id, this.sceneStorage);
		final pRowRef = new h3d.parts.Particles.ParticlesRowRef(pid, this.sceneStorage);
		final mRowRef = new h3d.scene.Mesh.MeshRowRef(mid, this.sceneStorage);
		
		return new h3d.parts.Emitter(rowRef, pRowRef, mRowRef, parent);
	}

	public function createGpuParticles( parent : Object = null ) {
		parent = parent == null ? this : parent;
		final eid = this.sceneStorage.entityStorage.allocateRow();
		final mid = this.sceneStorage.insertMesh(eid, null, []);
		final gid = this.sceneStorage.insertGpuParticles(eid);

		final gpuRowRef = new h3d.parts.GpuParticles.GpuParticlesRowRef(gid, this.sceneStorage);
		final mRowRef = new h3d.scene.Mesh.MeshRowRef(mid, this.sceneStorage);

		return new h3d.parts.GpuParticles(gpuRowRef, mRowRef, parent);
	}
}