package h3d.scene.pbr;

import h3d.scene.SceneStorage.EntityId;
import h3d.scene.Light.State as LightState;

class SpotLight extends Light {

	@:allow(h3d.scene.Scene)
	var spotState(get,never): State;
	inline function get_spotState() return this._state;

	public var range(get,set) : Float;
	public var maxRange(get,set) : Float;
	public var angle(get,set) : Float;
	public var fallOff(get,set) : Float;
	public var cookie(get,set) : h3d.mat.Texture;
	var lightProj(get,set) : h3d.Camera;

	@:allow(h3d.scene.Scene.createPbrSpotLight)
	private function new(oRowRef: h3d.scene.Object.ObjectRowRef, lRowRef: h3d.scene.Light.LightRowRef) {
		State.init(lRowRef.getRow(), this);
		super(oRowRef, lRowRef);
		maxRange = 10;
		angle = 45;
	}

	public override function clone( ?o : h3d.scene.Cloneable ) : h3d.scene.Cloneable {
		var sl = o == null ? this.getScene().createPbrSpotLight(null) : cast o;
		super.clone(sl);
		sl.range = range;
		sl.maxRange = maxRange;
		sl.angle = angle;
		sl.fallOff = fallOff;
		sl.cookie = cookie;
		sl.lightProj.load(lightProj);
		return sl;
	}

	inline function get_range() return this.spotState.range;
	inline function set_range(r) return this.spotState.range = r;

	function get_maxRange() {
		return cullingDistance;
	}

	function set_maxRange(v:Float) {
		scaleX = v;
		lightProj.zFar = v;
		return cullingDistance = v;
	}

	inline function get_angle() return this.spotState.angle;
	function set_angle(v:Float) {
		scaleY = hxd.Math.tan(hxd.Math.degToRad(v/2.0)) * maxRange;
		scaleZ = scaleY;
		lightProj.fovY = v;
		return this.spotState.angle = v;
	}

	inline function get_fallOff() return this.spotState.fallOff;
	inline function set_fallOff(f) return this.spotState.fallOff = f;

	inline function get_cookie() return this.spotState.cookie;
	inline function set_cookie(c) return this.spotState.cookie = c;

	inline function get_lightProj() return this.spotState.lightProj;
	inline function set_lightProj(l) return this.spotState.lightProj = l;

	public static function spotLightPrim() {
		var engine = h3d.Engine.getCurrent();
		var p : h3d.prim.Polygon = @:privateAccess engine.resCache.get(SpotLight);
		if( p != null )
			return p;

		var points = new Array<h3d.col.Point>();
		// Left
		points.push(new h3d.col.Point(0,0,0));
		points.push(new h3d.col.Point(1,-1,-1));
		points.push(new h3d.col.Point(1,-1,1));
		// Right
		points.push(new h3d.col.Point(0,0,0));
		points.push(new h3d.col.Point(1,1,1));
		points.push(new h3d.col.Point(1,1,-1));
		// Up
		points.push(new h3d.col.Point(0,0,0));
		points.push(new h3d.col.Point(1,-1,1));
		points.push(new h3d.col.Point(1,1,1));
		// Down
		points.push(new h3d.col.Point(0,0,0));
		points.push(new h3d.col.Point(1,1,-1));
		points.push(new h3d.col.Point(1,-1,-1));
		// Front
		points.push(new h3d.col.Point(1,-1,-1));
		points.push(new h3d.col.Point(1,1,-1));
		points.push(new h3d.col.Point(1,1,1));
		points.push(new h3d.col.Point(1,1,1));
		points.push(new h3d.col.Point(1,-1,1));
		points.push(new h3d.col.Point(1,-1,-1));
		p = new h3d.prim.Polygon(points);
		p.addNormals();

		@:privateAccess engine.resCache.set(SpotLight, p);
		return p;
	}

	static inline function generateLightProj(lightProj: h3d.Camera, absPos: h3d.Matrix){
		lightProj.pos.set(absPos.tx, absPos.ty, absPos.tz);
		final ldir = absPos.front();
		lightProj.target.set(absPos.tx + ldir.x, absPos.ty + ldir.y, absPos.tz + ldir.z);
		lightProj.update();
	}

	override function getShadowDirection() : h3d.Vector {
		return absPos.front();
	}

	public static function syncShader(state: State, absPos: h3d.Matrix): Void {
		final pbr = state.shader;
		final power = state.power;
		final angle = state.angle;
		final maxRange = state.cullingDistance;

		pbr.lightColor.load(state.color);
		pbr.lightColor.scale3(power * power);
		pbr.lightPos.set(absPos.tx, absPos.ty, absPos.tz);
		pbr.spotDir.load(absPos.front());
		pbr.angle = hxd.Math.cos(hxd.Math.degToRad(angle/2.0));
		pbr.fallOff = hxd.Math.cos(hxd.Math.degToRad(hxd.Math.min(angle/2.0, state.fallOff)));
		pbr.range = hxd.Math.min(state.range, maxRange);
		pbr.invLightRange4 = 1 / (maxRange * maxRange * maxRange * maxRange);
		pbr.occlusionFactor = state.occlusionFactor;

		if( state.cookie != null ) {
			pbr.useCookie = true;
			pbr.cookieTex = state.cookie;
			generateLightProj(state.lightProj, absPos);
			pbr.lightProj.load(state.lightProj.m);
		} else {
			pbr.useCookie = false;
		}
	}

	public static function emitPbrSpotLight(state: State, ctx:RenderContext.EmitContext, light: SpotLight, absPos: h3d.Matrix) {
		if( ctx.pbrLightPass == null )
			throw "Rendering a pbr light require a PBR compatible scene renderer";

		final s = state.s;
		final d = state.d;
		final maxRange = state.cullingDistance;
		d.load(absPos.front());
		d.scale3(maxRange / 2.0);
		s.x = absPos.tx + d.x;
		s.y = absPos.ty + d.y;
		s.z = absPos.tz + d.z;
		s.r = maxRange / 2.0;

		if( !ctx.camera.frustum.hasSphere(s) )
			return;

		h3d.scene.Light.emitLight(light, ctx);
		ctx.emitPass(ctx.pbrLightPass, light);
	}
}

@:forward(range, angle, fallOff, cookie, lightProj, s, d, primitive, color, power, cullingDistance, occlusionFactor)
private abstract State(LightState) to LightState from LightState {
	public var shader(get,never): h3d.shader.pbr.Light.SpotLight;
	inline function get_shader() return cast this.shader;

	private function new(s) { this = s; }

	public static inline function init(s: LightState, l: SpotLight): State {
		s.shadows = new h3d.pass.SpotShadowMap(l);
		s.primitive = SpotLight.spotLightPrim();
		
		s.lightProj.screenRatio = 1.0;

		return s;
	}
}
