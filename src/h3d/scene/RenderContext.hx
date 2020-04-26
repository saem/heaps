package h3d.scene;

private class SharedGlobal {
	public var gid : Int;
	public var value : Dynamic;
	public function new(gid, value) {
		this.gid = gid;
		this.value = value;
	}
}

class RenderContext extends h3d.impl.RenderContext {

	public var camera : h3d.Camera;
	public var scene : Scene;

	// Timing: Object::draw, Pass::draw
	public var drawPass : h3d.pass.PassObject;

	// Timing: Object::emit, pbr.Renderer::start, 
	public var pbrLightPass : h3d.mat.Pass;

	// Timing: Scene::computeStatic, pbr.Renderer::process & computeStatic, Object::emitRec computeStatic, LightSystem::initLights, Shadows::draw, World::syncRec, Light::emit
	public var computingStatic : Bool;

	// Timing: Default::draw, hxsl.Macros
	var sharedGlobals : Array<SharedGlobal>;

	// Timing: Pass::draw, Scene::render, Scene::hardwarePick, Renderer:render
	public var lightSystem : h3d.scene.LightSystem;

	// Timing: Pass::draw, Pass::setupShader, HardwarePick::draw, pbr.Renderer::render
	public var extraShaders : hxsl.ShaderList;

	// Timing: Pass::draw
	public var shaderBuffers : h3d.shader.Buffers;

	var allocPool : h3d.pass.PassObject;
	var allocFirst : h3d.pass.PassObject;
	var cachedShaderList : Array<hxsl.ShaderList>;
	var cachedPassObjects : Array<Renderer.PassObjects>;
	var cachedPos : Int;
	// Scene::realRender
	var passIndex: Int;
	var passes : h3d.pass.PassObject;
	var lights : Light;
	var currentManager : h3d.pass.ShaderManager;
	@:allow(h3d.scene.pbr.LightSystem.computeLight)
	var pbrLightIndex: Map<Int, h3d.pass.LightObject> = new Map();

	public function new() {
		super();
		cachedShaderList = [];
		cachedPassObjects = [];
	}

	@:access(h3d.mat.Pass)
	public inline function emit( mat : h3d.mat.Material, obj: h3d.pass.DrawObject, index = 0 ) {
		var p = mat.mainPass;
		while( p != null ) {
			emitPass(p, obj).index = index;
			p = p.nextPass;
		}
	}

	public function start(camera, engine, scene) {
		this.camera = camera;
		this.engine = engine;
		this.scene = scene;
		sharedGlobals = [];
		lights = null;
		drawPass = null;
		passes = null;
		lights = null;
		cachedPos = 0;
		time += elapsedTime;
		passIndex = -1;
		frame++;
	}

	public function done() {
		drawPass = null;
		// move passes to pool, and erase data
		var p = allocFirst;
		while( p != null && p != allocPool ) {
			p.obj = null;
			p.pass = null;
			p.shader = null;
			p.shaders = null;
			p.next = null;
			p.index = 0;
			p.texture = 0;
			p = @:privateAccess p.nextAlloc;
		}
		// one pooled object was not used this frame, let's gc unused one by one
		if( allocPool != null )
			allocFirst = @:privateAccess allocFirst.nextAlloc;
		allocPool = allocFirst;
		for( c in cachedShaderList ) {
			c.s = null;
			c.next = null;
		}
		passes = null;
		lights = null;

		for( i in 0...passIndex ) {
			var p = cachedPassObjects[i];
			p.name = null;
			p.passes.init(null);
		}
		passIndex = -1; // reset for next time Scene::realRender uses it

		pbrLightIndex.clear();

		this.camera = null;
		this.engine = null;
		this.scene = null;
	}

	public inline function nextPass() {
		cachedPos = 0;
		drawPass = null;
	}

	public function getGlobal( name : String ) : Dynamic {
		var id = hxsl.Globals.allocID(name);
		for( g in sharedGlobals )
			if( g.gid == id )
				return g.value;
		return null;
	}

	public inline function setGlobal( name : String, value : Dynamic ) {
		setGlobalID(hxsl.Globals.allocID(name), value);
	}

	public function setGlobalID( gid : Int, value : Dynamic ) {
		for( g in sharedGlobals )
			if( g.gid == gid ) {
				g.value = value;
				return;
			}
		sharedGlobals.push(new SharedGlobal(gid, value));
	}

	public function emitPass( pass : h3d.mat.Pass, obj : h3d.pass.DrawObject ) @:privateAccess {
		var o = allocPool;
		if( o == null ) {
			o = new h3d.pass.PassObject();
			o.nextAlloc = allocFirst;
			allocFirst = o;
		} else
			allocPool = o.nextAlloc;
		o.pass = pass;
		o.obj = obj;
		o.next = passes;
		passes = o;
		return o;
	}

	public function allocShaderList( s : hxsl.Shader, ?next : hxsl.ShaderList ) {
		var sl = cachedShaderList[cachedPos++];
		if( sl == null ) {
			sl = new hxsl.ShaderList(null);
			cachedShaderList[cachedPos - 1] = sl;
		}
		sl.s = s;
		sl.next = next;
		return sl;
	}

	public function emitLight( l : Light ) {
		l.next = lights;
		lights = l;

		final light = hxd.impl.Api.downcast(l, h3d.scene.pbr.Light);
		if (light != null) {
			this.pbrLightIndex.set(light.id, light);
		}
	}

	public function uploadParams() {
		currentManager.fillParams(shaderBuffers, drawPass.shader, drawPass.shaders);
		engine.uploadShaderBuffers(shaderBuffers, Params);
		engine.uploadShaderBuffers(shaderBuffers, Textures);
	}

	/**
		sort by pass id
	**/
	public function sortPasses() {
		passes = haxe.ds.ListSort.sortSingleLinked(passes, function(p1, p2) {
			return p1.pass.passId - p2.pass.passId;
		});
	}
}

@:forward(camera, computingStatic, elapsedTime, frame, time)
abstract SyncContext(RenderContext) {
	public function new(ctx: RenderContext) {
		this = ctx;
	}
}

/**
	Force read-only rather than use forwards
**/
abstract AnimationContext(RenderContext.SyncContext) {
	public var elapsedTime(get, never): Float;

	inline function get_elapsedTime() return this.elapsedTime;

	public function new(ctx: RenderContext.SyncContext) {
		this = ctx;
	}
}

@:forward(camera, computingStatic, emit, emitLight, emitPass, pbrLightPass)
abstract EmitContext(RenderContext) {
	public function new(ctx: RenderContext) {
		this = ctx;
	}
}

@:forward(camera, computingStatic, drawPass, engine, extraShaders, lightSystem, shaderBuffers, sharedGlobals, uploadParams)
abstract DrawContext(RenderContext) {
	public function new(ctx: RenderContext) {
		this = ctx;
	}
}