package h3d.scene.pbr;

import h3d.scene.Light.State as LightState;

class PointLight extends Light {

	var pointState(get,never): State;
	inline function get_pointState() return cast this._state;

	public var size(get,set) : Float;
	public var zNear(get,set) : Float;
	/**
		Alias for uniform scale.
	**/
	public var range(get,set) : Float;

	@:allow(h3d.scene.Scene.createPbrPointLight)
	private function new(lRowRef: h3d.scene.Light.LightRowRef, ?parent) {
		State.init(lRowRef.getRow(), this);
		super(lRowRef, parent);
		range = 10;
		this.pointState.primitive = h3d.prim.Sphere.defaultUnitSphere();
	}

	public override function clone( ?o : h3d.scene.Object ) : h3d.scene.Object {
		var pl = o == null ? this.getScene().createPbrPointLight(null) : cast o;
		super.clone(pl);
		pl.size = size;
		pl.range = range;
		return pl;
	}

	inline function get_size() return this.pointState.size;
	inline function set_size(s) return this.pointState.size = s;
	inline function get_zNear() return this.pointState.zNear;
	inline function set_zNear(z) return this.pointState.zNear = z;
	
	function get_range() {
		return cullingDistance;
	}

	function set_range(v:Float) {
		setScale(v);
		return cullingDistance = v;
	}

	override function draw(ctx:RenderContext.DrawContext) {
		this.pointState.primitive.render(ctx.engine);
	}

	override function sync(ctx) {
		super.sync(ctx);

		final pbr = this.pointState.shader;
		pbr.lightColor.load(this.pointState.color);
		final range = hxd.Math.max(range, 1e-10);
		final size = hxd.Math.min(size, range);
		final power = power * 10; // base scale
		pbr.lightColor.scale3(power * power);
		pbr.lightPos.set(absPos.tx, absPos.ty, absPos.tz);
		pbr.invLightRange4 = 1 / (range * range * range * range);
		pbr.pointSize = size;
		pbr.occlusionFactor = occlusionFactor;
	}

	var s = new h3d.col.Sphere();
	override function emit(ctx:RenderContext.EmitContext) {
		if( ctx.computingStatic ) {
			super.emit(ctx);
			return;
		}

		if( ctx.pbrLightPass == null )
			throw "Rendering a pbr light require a PBR compatible scene renderer";

		s.x = absPos._41;
		s.y = absPos._42;
		s.z = absPos._43;
		s.r = cullingDistance;

		if( !ctx.camera.frustum.hasSphere(s) )
			return;

		super.emit(ctx);
		ctx.emitPass(ctx.pbrLightPass, this);
	}
}

@:forward(size, zNear, s, color, primitive)
private abstract State(LightState) to LightState from LightState {
	public var shader(get,never): h3d.shader.pbr.Light.PointLight;
	inline function get_shader() return cast this.shader;

	private function new(s) { this = s; }

	public static inline function init(s: LightState, l: PointLight): State {
		s.shadows = new h3d.pass.PointShadowMap(l, true);

		return s;
	}
}