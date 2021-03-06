package h3d.scene;

import h3d.scene.SceneStorage.EntityId;

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
	final storage : SceneStorage;

	/**
		Create a new scene. A default 3D scene is already available in `hxd.App.s3d`
	**/
	@:allow(h3d.scene.Scene.createScene)
	private function new( oRowRef: Object.ObjectRowRef, storage: SceneStorage, ?createRenderer = true, ?createLightSystem = true ) {
		this.storage = storage;

		super(oRowRef);
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
	public function isInteractiveVisible( interactive : hxd.SceneEvents.Interactive ) {
		final i = Std.downcast(interactive, h3d.scene.Interactive);
		if( i == null ) return false;
		var o = Object.ObjectMap.get(i.objectId);
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

				final obj : h3d.scene.Object = Object.ObjectMap.get(i.objectId);
				var p : h3d.scene.Object = obj;
				while( p != null && p.visible )
					p = p.parent;
				if( p != null ) continue;

				var minv = obj.getInvPos();

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
					final o : h3d.scene.Object = Object.ObjectMap.get(i.objectId);
					var m = o.invPos;
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
					p.transform3x4(o.absPos);
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

	override function clone( ?o : Cloneable ) {
		var s = o == null ? h3d.scene.Scene.createScene() : cast o;
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
		storage.reset();
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
		updateCamera(engine, camera, sceneStorage);
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

		syncChildren(this.children, ctx, this.storage);

		cleanUpMovedObjects();

		processAddedInteractives();
		Object.AddedObjectIds.resize(0);

		// Process deleted objects and then clean them up
		processDeletedInteractives();
		Object.DeletedObjectIds.resize(0);
	}

	static function syncChildren(children: Array<Object>, ctx: RenderContext.SyncContext, storage: SceneStorage): Void {
		// First sync only the immediate children.
		var p = 0;
		while( p < children.length ) {
			final c = children[p];
			if( c == null ) {
				continue;
			}
			if( c.lastFrame != ctx.frame ) {
				setFlags(c);
				animate(c, storage.selectObjectAnimation(c.id), new RenderContext.AnimationContext(ctx));
				if(!c.syncContinueFlag) {
					p++;
					continue;
					// animation removed this most likely
				}
				transform(c);

				// TODO handle named phases extracted out of various syncs.
				switch(c.objectType) {
					case TGraphics | TSphere:
						Graphics.syncGraphics(c.toGraphicsUnsafe().gRow);
					case TBox:
						Box.syncUpdatePrimitive(c.toBoxUnsafe().bRow, c.toGraphicsUnsafe().gRow);
						Graphics.syncGraphics(c.toGraphicsUnsafe().gRow);
					case TSkin if(c.syncVisibleFlag || c.alwaysSync):
						Skin.syncJoints(cast c);
						Skin.syncShowJoints(cast c);
					case TGpuParticles:
						h3d.parts.GpuParticles.syncGpuParticles(c.toGpuParticlesUnsafe(), ctx, c.toGpuParticlesUnsafe().row);
					case TEmitter:
						c.toEmitterUnsafe().update(ctx.elapsedTime);
					case TFwdDirLight:
						h3d.scene.fwd.DirLight.syncShader(c.toFwdDirLightUnsafe().dirState, c.absPos);
					case TFwdPointLight:
						h3d.scene.fwd.PointLight.updateCullingDistance(c.toFwdPointLightUnsafe().pointState);
						h3d.scene.fwd.PointLight.syncShader(c.toFwdPointLightUnsafe().pointState, c.absPos);
					case TPbrDirLight:
						h3d.scene.pbr.DirLight.syncShader(c.toPbrDirLightUnsafe().dirState, c.absPos);
					case TPbrPointLight:
						h3d.scene.pbr.PointLight.syncShader(c.toPbrPointLightUnsafe().pointState, c.absPos);
					case TPbrSpotLight:
						h3d.scene.pbr.SpotLight.syncShader(c.toPbrSpotLightUnsafe().spotState, c.absPos);
					case TPbrDecal:
						h3d.scene.pbr.Decal.syncPbrDecal(c.toPbrDecalUnsafe().mRow, c.getAbsPos());
					case TObject | TWorld | TMesh | TSkin | TParticles | TSkinJoint:
						null;
				}

				c.posChanged = false;
				c.lastFrame = ctx.frame;
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
				syncChildren(c.children, ctx, storage);
			}
			c.postSyncChildren(ctx);
			p++;
		}
	}

	function emitScene( ctx : RenderContext.EmitContext ) {
		emitChildren(this.children, ctx, this.storage);
	}

	static function emitChildren(children: Array<Object>, ctx: RenderContext.EmitContext, storage: SceneStorage) {
		var p = 0;
		while( p < children.length ) {
			final c = children[p];
			p++;

			if( !c.visible || (c.culled && !ctx.computingStatic))
				continue;	// this and children aren't to be emitted

			if( !c.culled || ctx.computingStatic ) {
				emitObject(c, ctx);
			}

			if( c.children.length > 0 ) {
				emitChildren(c.children, ctx, storage);
			}
		}
	}

	static function emitObject(object: Object, ctx: RenderContext.EmitContext) {
		switch(object.objectType) {
			case TGpuParticles:
				final parts = object.toGpuParticlesUnsafe();
				h3d.parts.GpuParticles.emitGpuParticles(parts.row, parts, ctx);
			case TFwdDirLight | TFwdPointLight:
				Light.emitLight(cast object, ctx);
			case TPbrDirLight | TPbrPointLight | TPbrSpotLight if (ctx.computingStatic):
				Light.emitLight(object.toLightUnsafe(),ctx);
			case TPbrDirLight:
				Light.emitLight(object.toPbrDirLightUnsafe(), ctx);
			case TPbrPointLight:
				final light = object.toPbrPointLightUnsafe();
				h3d.scene.pbr.PointLight.emitPbrPointLight(light.pointState, ctx, light, object.absPos);
			case TPbrSpotLight:
				final light = object.toPbrSpotLightUnsafe();
				h3d.scene.pbr.SpotLight.emitPbrSpotLight(light.spotState, ctx, light, object.absPos);
			case TSkin if (object.toSkin().sRow.splitPalette != null):
				final skin = object.toSkin();
				Skin.emitSkin(skin.sRow, skin.mRow, skin, ctx);
			case TSkin | TMesh | TPbrDecal:
				final mesh = object.toMesh();
				Mesh.emitMesh(mesh.mRow, mesh, ctx);
			case TGraphics | TBox | TSphere:
				final gRow = object.toGraphicsUnsafe().gRow;
				if(gRow.material != null)
					ctx.emit(gRow.material, object);
			case TParticles | TEmitter:
				final pRow = object.toParticlesUnsafe().pRow;
				if(pRow.material != null)
					ctx.emit(pRow.material, object);
			case TObject | TWorld | TSkinJoint :
				null;
		}
	}

	@:allow(h3d.pass.Default) private static function drawObject(obj: h3d.pass.DrawObject, ctx: RenderContext.DrawContext) {
		final o = Object.ObjectMap.get(obj.id);
		if (o != null)
			legacyDraw(o, ctx);
	}

	static function legacyDraw(object: Object, ctx: RenderContext.DrawContext) {
		switch(object.objectType) {
			case TSkin if( object.toSkin().sRow.splitPalette != null ):
				final skin = object.toSkin();
				Skin.drawSkin(skin.sRow, skin.mRow, ctx);
			case TGpuParticles:
				h3d.parts.GpuParticles.drawGpuParticles(object.toGpuParticlesUnsafe().row, ctx);
			case TEmitter:
				final emitter = object.toEmitterUnsafe();
				h3d.parts.Emitter.drawEmitter(emitter.eRow, emitter.pRow, emitter);
				h3d.parts.Particles.drawParticles(object.toParticlesUnsafe().pRow, ctx);
			case TParticles:
				h3d.parts.Particles.drawParticles(object.toParticlesUnsafe().pRow, ctx);
			case TMesh | TSkin | TPbrDecal:
				Mesh.drawMesh(object.toMesh().mRow, ctx);
			case TPbrPointLight | TPbrSpotLight:
				final light: Light = cast object;
				light.lRow.primitive.render(ctx.engine);
			case TGraphics | TBox | TSphere:
				Graphics.drawGraphics(object.toGraphicsUnsafe().gRow, ctx);
			case TFwdDirLight | TFwdPointLight | TPbrDirLight:
				// TODO - Confirm that these shouldn't have a draw call
				null;
			case TObject | TWorld | TSkinJoint:
				null;
		}
	}

	/**
		Used to keep various flags for sync/syncChildren up to date.
	**/
	static function setFlags(object: Object): Void {
		object.syncContinueFlag = true;
		final parent = object.parent;
		if( parent != null ) {
			object.syncChangedFlag = parent.syncChangedFlag;
			object.syncVisibleFlag = parent.syncVisibleFlag;
		} else {
			object.syncChangedFlag = object.posChanged;
			object.syncVisibleFlag = object.visible && !object.culled;
		}
	}

	static function animate(object: Object, anim: Animation.AnimationRow, ctx: RenderContext.AnimationContext): Void {
		object.syncChangedFlag = (switch(tryAnimation(object, anim, ctx)) {
			case AnimationResult.Removed: object.syncContinueFlag = false;
			default: object.posChanged || object.syncChangedFlag;
		});
	}

	static function tryAnimation(object: Object, anim: Animation.AnimationRow, ctx: RenderContext.AnimationContext): AnimationResult {
		switch(anim.state) {
			case Removed:
				return AnimationResult.NoAnimation;
			case Remove:
				anim.currentAnimation = null;
				anim.state = Removed;
				return AnimationResult.NoAnimation;
			case Play:
				anim.currentAnimation.bind(object);
				anim.currentAnimation.initInstance();
				anim.state = Playing;
			case Playing:
				null; // do the rest
		}
		final animation = anim.currentAnimation;

		final old = object.parent;
		var dt = ctx.elapsedTime;
		while( dt > 0 && !anim.state.match(Remove) )
			dt = animation.update(dt);

		if( !anim.state.match(Remove) && ((object.syncVisibleFlag && object.visible && !object.culled) || object.alwaysSync)  )
			animation.sync();
		if( object.parent == null && old != null )
			return AnimationResult.Removed; // if we were removed by an animation event

		// Handle animations making a visible object invisible or culled(?)
		object.syncVisibleFlag = object.syncVisibleFlag && object.visible && !object.culled;

		return AnimationResult.Animated;
	}

	static inline function transform(object: Object) {
		if( object.syncChangedFlag ) object.calcAbsPos();
	}

	/**
		Objects that were moved could trigger an onAdd and onRemove. So let's
		just ignore them.
	**/
	function cleanUpMovedObjects() {
		var i = 0;
		while(i < Object.AddedObjectIds.length) {
			final added = Object.AddedObjectIds[i];
			if(Object.DeletedObjectIds.remove(added)) {
				Object.AddedObjectIds.splice(i, 1);
			} else {
				i++;
			}
		}
	}

	function processAddedInteractives() {
		for(id in Object.AddedObjectIds) {
			var i = 0;
			while(i < this.interactives.length) {
				final interactive = this.interactives[i];
				if(interactive.objectId == id) {
					if (!interactive.isAdded) interactive.onAdd(this);
					break;
				}
				i++;
			}
		}
	}

	function processDeletedInteractives() {
		for(id in Object.DeletedObjectIds) {
			var i = 0;
			while(i < this.interactives.length) {
				if(this.interactives[i].objectId == id) {
					this.interactives[i].onRemove();
					this.interactives.splice(i,1);
					break;
				}
				i++;
			}
		}
	}

	/**
		Synchronize the scene without rendering, updating all objects and animations by the given amount of time, in seconds.
	**/
	public function syncOnly( et : Float ) {
		var engine = h3d.Engine.getCurrent();
		setElapsedTime(et);
		updateCamera(engine, camera, sceneStorage);
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
		updateCamera(engine, camera, sceneStorage);
		realRender(engine, this, this.ctx, this.camera, this.renderer, this.lightSystem);
	}

	private static inline function allocateScene(scene: Scene) {
		if( !scene.allocated )
			scene.onAdd();
	}

	private static inline function updateCamera(engine: h3d.Engine, camera: h3d.Camera, sceneStorage: SceneStorage) {
		camera.screenRatio = engine.getTargetScreenRation();
		animateCameraFov(camera, sceneStorage);
		camera.update();
	}

	private static inline function animateCameraFov(camera: h3d.Camera, sceneStorage: SceneStorage) {
		if(camera.follow == null || camera.follow.pos.name != null) {
			return;
		}

		var p = camera.follow.pos;
		var a = null;
		while( p != null ) {
			a = sceneStorage.selectObjectAnimation(p.id);
			if( a != null ) {
				final v = a.currentAnimation.getPropValue(p.name, "FOVY");
				if( v != null ) {
					camera.fovY = v;
					break;
				}
			}
			p = p.parent;
		}
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
			CameraController.sync(scene.storage.selectCameraController(scene.cameraControllerId), camera, ctx.elapsedTime);
		scene.emitScene(new RenderContext.EmitContext(ctx));

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

	// TODO - more than one scene means bugs
	static var cachedScene: Scene = null;
	public static function createScene( ?createRenderer = true, ?createLightSystem = true ) {
		if(cachedScene != null) { return cachedScene; }

		final storage = new SceneStorage();
		final eid = storage.insertEntity();
		storage.insertObject(eid, TObject);
		final oRowRef = new Object.ObjectRowRef(eid, storage);
		
		// allocate the components first so they're ready for the constructor
		Scene.createObjectComponents(storage, eid, TObject, null);

		cachedScene = new Scene(oRowRef, storage, createRenderer, createLightSystem);
		return cachedScene;
	}

	/**
		This is here for supporting new object types

		Should go away.
	**/
	public function createEntity() {
		return this.storage.insertEntity();
	}

	public function createInteractive(objectId: EntityId, ?shape: h3d.col.Collider = null) {
		final obj = Object.ObjectMap.get(objectId);
		final interactive = new h3d.scene.Interactive(objectId, shape);

		if(obj.getScene() != null && Object.AddedObjectIds.indexOf(objectId) < 0) {
			interactive.onAdd(this);
		}

		return interactive;
	}

	public function createObject(?parent : Object = null) {
		parent = parent == null ? this : parent;
		final eid = this.storage.insertEntity();

		final oRowRef = new Object.ObjectRowRef(eid, storage);

		// allocate the components first so they're ready for the constructor
		Scene.createObjectComponents(storage, eid, TObject, parent);

		final o = new Object(oRowRef);

		return o;
	}

	public function createCameraController( ?distance : Float ) {
		this.cameraControllerId = this.storage.insertCameraController(this.cameraControllerSystem, distance);

        // Crappy On Insert Trigger
		final ccr:CameraController.CameraControllerRow = this.storage.selectCameraController(this.cameraControllerId);
        CameraController.onAdd(ccr, this, this.camera);

		return new h3d.scene.CameraController(ccr);
	}

	public function createFwdDirLight( ?dir : h3d.Vector = null, ?parent : Object = null ) {
		parent = parent == null ? this : parent;
		final eid = this.storage.insertEntity();
		final id = this.storage.insertLight(eid, h3d.scene.Light.Type.FwdDir, new h3d.shader.DirLight());

		final oRowRef = new Object.ObjectRowRef(eid, this.storage);
		final rowRef = new h3d.scene.Light.LightRowRef(id, this.storage);

		// allocate the components first so they're ready for the constructor
		Scene.createObjectComponents(storage, eid, TFwdDirLight, parent);

		return new h3d.scene.fwd.DirLight(oRowRef, rowRef, dir);
	}

	public function createFwdPointLight( ?parent : Object = null ) {
		parent = parent == null ? this : parent;
		final eid = this.storage.insertEntity();
		final id = this.storage.insertLight(eid, h3d.scene.Light.Type.FwdPoint, new h3d.shader.PointLight());

		final oRowRef = new Object.ObjectRowRef(eid, this.storage);
		final rowRef = new h3d.scene.Light.LightRowRef(id, this.storage);

		// allocate the components first so they're ready for the constructor
		Scene.createObjectComponents(storage, eid, TFwdPointLight, parent);

		return new h3d.scene.fwd.PointLight(oRowRef, rowRef);
	}

	public function createPbrDirLight( ?dir : h3d.Vector = null, ?parent : Object = null ) {
		parent = parent == null ? this : parent;
		final eid = this.storage.insertEntity();
		final id = this.storage.insertLight(eid, h3d.scene.Light.Type.PbrDir, new h3d.shader.pbr.Light.DirLight());

		final oRowRef = new Object.ObjectRowRef(eid, this.storage);
		final rowRef = new h3d.scene.Light.LightRowRef(id, this.storage);

		// allocate the components first so they're ready for the constructor
		Scene.createObjectComponents(storage, eid, TPbrDirLight, parent);

		return new h3d.scene.pbr.DirLight(oRowRef, rowRef, dir);
	}

	public function createPbrPointLight( ?parent : Object = null ) {
		parent = parent == null ? this : parent;
		final eid = this.storage.insertEntity();
		final id = this.storage.insertLight(eid, h3d.scene.Light.Type.PbrPoint, new h3d.shader.pbr.Light.PointLight());

		final oRowRef = new Object.ObjectRowRef(eid, this.storage);
		final rowRef = new h3d.scene.Light.LightRowRef(id, this.storage);

		// allocate the components first so they're ready for the constructor
		Scene.createObjectComponents(storage, eid, TPbrPointLight, parent);

		return new h3d.scene.pbr.PointLight(oRowRef, rowRef);
	}

	public function createPbrSpotLight( ?parent : Object = null ) {
		parent = parent == null ? this : parent;
		final eid = this.storage.insertEntity();
		final id = this.storage.insertLight(eid, h3d.scene.Light.Type.PbrSpot, new h3d.shader.pbr.Light.SpotLight());

		final oRowRef = new Object.ObjectRowRef(eid, this.storage);
		final rowRef = new h3d.scene.Light.LightRowRef(id, this.storage);

		// allocate the components first so they're ready for the constructor
		Scene.createObjectComponents(storage, eid, TPbrSpotLight, parent);

		return new h3d.scene.pbr.SpotLight(oRowRef, rowRef);
	}

	public function createMesh( primitive : h3d.prim.Primitive, ?material : h3d.mat.Material = null, ?parent : Object = null ) {
		parent = parent == null ? this : parent;
		final eid = this.storage.insertEntity();
		final id = this.storage.insertMesh(eid, primitive, material == null ? [] : [material]);

		final oRowRef = new Object.ObjectRowRef(eid, this.storage);
		final rowRef = new h3d.scene.Mesh.MeshRowRef(id, this.storage);

		// allocate the components first so they're ready for the constructor
		Scene.createObjectComponents(storage, eid, TMesh, parent);

		return new h3d.scene.Mesh(oRowRef, rowRef);
	}

	public function createMeshWithMaterials( primitive : h3d.prim.Primitive, ?materials : Array<h3d.mat.Material> = null, ?parent : Object = null ) {
		parent = parent == null ? this : parent;
		final eid = this.storage.insertEntity();
		final id = this.storage.insertMesh(eid, primitive, materials == null ? [] : materials);

		final oRowRef = new Object.ObjectRowRef(eid, this.storage);
		final rowRef = new h3d.scene.Mesh.MeshRowRef(id, this.storage);

		// allocate the components first so they're ready for the constructor
		Scene.createObjectComponents(storage, eid, TMesh, parent);

		return new h3d.scene.Mesh(oRowRef, rowRef);
	}

	public function createGraphics( ?parent : Object = null ) {
		parent = parent == null ? this : parent;
		final eid = this.storage.insertEntity();
		final id = this.storage.insertGraphics(eid);

		final oRowRef = new Object.ObjectRowRef(eid, this.storage);
		final rowRef = new h3d.scene.Graphics.GraphicsRowRef(id, this.storage);
		
		// TODO - hacky, but the primitive is setup in the GraphicsRow
		final mid = this.storage.insertMesh(eid, rowRef.getRow().bprim, null);

		// allocate the components first so they're ready for the constructor
		Scene.createObjectComponents(storage, eid, TGraphics, parent);

		return new h3d.scene.Graphics(oRowRef, rowRef);
	}

	public function createBox( ?colour = 0xFFFF0000, ?bounds : h3d.col.Bounds = null, ?depth : Bool = true, ?parent : Object = null ) {
		parent = parent == null ? this : parent;
		final eid = this.storage.insertEntity();
		final gid = this.storage.insertGraphics(eid);
		final id = this.storage.insertBox(eid, colour, bounds);
		
		final oRowRef = new Object.ObjectRowRef(eid, this.storage);
		final rowRef = new h3d.scene.Box.BoxRowRef(id, this.storage);
		final gRowRef = new h3d.scene.Graphics.GraphicsRowRef(gid, this.storage);

		// allocate the components first so they're ready for the constructor
		Scene.createObjectComponents(storage, eid, TBox, parent);

		return new h3d.scene.Box(oRowRef, rowRef, gRowRef, depth);
	}

	public function createSphere( ?colour = 0xFFFF0000, ?radius : Float = 1.0, ?depth : Bool = true, ?parent : Object = null ) {
		parent = parent == null ? this : parent;
		final eid = this.storage.insertEntity();
		final gid = this.storage.insertGraphics(eid);
		final id = this.storage.insertSphere(eid, colour, radius);
		
		final oRowRef = new Object.ObjectRowRef(eid, this.storage);
		final rowRef = new h3d.scene.Sphere.SphereRowRef(id, this.storage);
		final gRowRef = new h3d.scene.Graphics.GraphicsRowRef(gid, this.storage);
		
		// allocate the components first so they're ready for the constructor
		Scene.createObjectComponents(storage, eid, TSphere, parent);

		return new h3d.scene.Sphere(oRowRef, rowRef, gRowRef, depth);
	}

	public function createSkin( ?skinData:h3d.anim.Skin = null, ?materials : Array<h3d.mat.Material> = null, ?parent : Object = null ) {
		parent = parent == null ? this : parent;
		final eid = this.storage.insertEntity();
		final mid = this.storage.insertMesh(eid, null, materials);
		final id = this.storage.insertSkin(eid, skinData);

		final oRowRef = new Object.ObjectRowRef(eid, this.storage);
		final rowRef = new h3d.scene.Skin.SkinRowRef(id, this.storage);
		final mRowRef = new h3d.scene.Mesh.MeshRowRef(mid, this.storage);

		// allocate the components first so they're ready for the constructor
		Scene.createObjectComponents(storage, eid, TSkin, parent);

		return new h3d.scene.Skin(oRowRef, rowRef, mRowRef);
	}

	@:allow(h3d.scene.Skin.getObjectByName)
	public function createSkinJoint( skin : h3d.scene.Skin, name : String, index : Int  ) {
		final eid = this.storage.insertEntity();
		final id = this.storage.insertSkinJoint(eid, skin, name, index);

		// allocate the components first so they're ready for the constructor
		Scene.createObjectComponents(storage, eid, TSkinJoint, null);

		final oRowRef = new Object.ObjectRowRef(eid, this.storage);
		final rowRef = new h3d.scene.Skin.SkinJointRowRef(id, this.storage);

		return new h3d.scene.Skin.Joint(oRowRef, rowRef);
	}

	public function createWorld( chunkSize : Int, worldSize : Int, ?autoCollect : Bool = true, ?parent : Object = null ) {
		parent = parent == null ? this : parent;
		final eid = this.storage.insertEntity();
		final id  = this.storage.insertWorld(eid, chunkSize, worldSize, autoCollect);
		
		final rowRef = new h3d.scene.World.WorldRowRef(id, this.storage);
		final oRowRef = new Object.ObjectRowRef(eid, this.storage);

		// allocate the components first so they're ready for the constructor
		Scene.createObjectComponents(storage, eid, TWorld, parent);

		return new h3d.scene.World(oRowRef, rowRef);
	}

	public function createPbrDecal( primitive : h3d.prim.Primitive, materials : Array<h3d.mat.Material> = null, parent : Object = null ) {
		parent = parent == null ? this : parent;
		final eid = this.storage.insertEntity();
		final mid = this.storage.insertMesh(eid, primitive, materials);
		final id  = this.storage.insertDecal(eid);

		final rowRef = new h3d.scene.pbr.Decal.DecalRowRef(id, this.storage);
		final mRowRef = new h3d.scene.Mesh.MeshRowRef(mid, this.storage);
		final oRowRef = new Object.ObjectRowRef(eid, this.storage);

		// allocate the components first so they're ready for the constructor
		Scene.createObjectComponents(storage, eid, TPbrDecal, parent);

		return new h3d.scene.pbr.Decal(oRowRef, rowRef, mRowRef);
	}

	public function createParticles( ?texture : h3d.mat.Texture = null, parent : Object = null ) {
		parent = parent == null ? this : parent;
		final eid = this.storage.insertEntity();
		final id  = this.storage.insertParticles(eid, texture);

		final rowRef = new h3d.parts.Particles.ParticlesRowRef(id, this.storage);
		final oRowRef = new Object.ObjectRowRef(eid, this.storage);

		// allocate the components first so they're ready for the constructor
		Scene.createObjectComponents(storage, eid, TParticles, parent);
		
		return new h3d.parts.Particles(oRowRef, rowRef);
	}

	public function createEmitter( ?state : h3d.parts.Data.State = null, parent : Object = null ) {
		parent = parent == null ? this : parent;
		final eid = this.storage.insertEntity();
		final pid = this.storage.insertParticles(eid);
		final id  = this.storage.insertEmitter(eid, state);

		// allocate the components first so they're ready for the constructor
		Scene.createObjectComponents(storage, eid, TEmitter, parent);

		final rowRef = new h3d.parts.Emitter.EmitterRowRef(id, this.storage);
		final pRowRef = new h3d.parts.Particles.ParticlesRowRef(pid, this.storage);
		final oRowRef = new Object.ObjectRowRef(eid, this.storage);
		
		return new h3d.parts.Emitter(oRowRef, rowRef, pRowRef);
	}

	public function createGpuParticles( parent : Object = null ) {
		parent = parent == null ? this : parent;
		final eid = this.storage.entityStorage.allocateRow();
		final gid = this.storage.insertGpuParticles(eid);

		// allocate the components first so they're ready for the constructor
		Scene.createObjectComponents(storage, eid, TGpuParticles, parent);

		final oRowRef = new Object.ObjectRowRef(eid, this.storage);
		final gpuRowRef = new h3d.parts.GpuParticles.GpuParticlesRowRef(gid, this.storage);

		return new h3d.parts.GpuParticles(oRowRef, gpuRowRef);
	}

	private inline static function createObjectComponents(storage: SceneStorage, eid: EntityId, objectType: Object.ObjectType, parent: Object = null, ?name: String = null) {
		storage.insertObject(eid, objectType, parent, name);
		storage.insertRelativePosition(eid);
		storage.insertObjectAnimation(eid);
	}
}

enum abstract AnimationResult(Int) {
	var Removed;
	var Animated;
	var NoAnimation;
}