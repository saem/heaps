package h3d.scene;

class Light extends h3d.scene.Object {

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

	private function new(state, ?parent) {
		this._state = state;
		super(parent);
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

class State {
	public function new(type:Type, shader:hxsl.Shader) {
		this.type = type;
		this.shader = shader;
	}

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
}

enum abstract Type(Int) {
	var FwdDir;
	var FwdPoint;
	var PbrDir;
	var PbrPoint;
	var PbrSpot;
}