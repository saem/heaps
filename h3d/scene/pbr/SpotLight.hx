package h3d.scene.pbr;

import h3d.scene.SceneStorage.EntityId;
import h3d.scene.Light.State as LightState;

class SpotLight extends Light {

	var spotState(get,never): State;
	inline function get_spotState() return this._state;

	public var range(get,set) : Float;
	public var maxRange(get,set) : Float;
	public var angle(get,set) : Float;
	public var fallOff(get,set) : Float;
	public var cookie(get,set) : h3d.mat.Texture;
	var lightProj(get,set) : h3d.Camera;

	@:allow(h3d.scene.Scene.createPbrSpotLight)
	private function new(eid: EntityId, lRowRef: h3d.scene.Light.LightRowRef, ?parent) {
		State.init(lRowRef.getRow(), this);
		super(eid, lRowRef, parent);
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

	function generateLightProj(){
		lightProj.pos.set(absPos.tx, absPos.ty, absPos.tz);
		var ldir = absPos.front();
		lightProj.target.set(absPos.tx + ldir.x, absPos.ty + ldir.y, absPos.tz + ldir.z);
		lightProj.update();
	}

	override function getShadowDirection() : h3d.Vector {
		return absPos.front();
	}

	override function draw(ctx:RenderContext.DrawContext) {
		this.spotState.primitive.render(ctx.engine);
	}

	override function sync(ctx) {
		super.sync(ctx);

		final pbr = this.spotState.shader;
		pbr.lightColor.load(this.spotState.color);
		var power = power;
		pbr.lightColor.scale3(power * power);
		pbr.lightPos.set(absPos.tx, absPos.ty, absPos.tz);
		pbr.spotDir.load(absPos.front());
		pbr.angle = hxd.Math.cos(hxd.Math.degToRad(angle/2.0));
		pbr.fallOff = hxd.Math.cos(hxd.Math.degToRad(hxd.Math.min(angle/2.0, fallOff)));
		pbr.range = hxd.Math.min(range, maxRange);
		pbr.invLightRange4 = 1 / (maxRange * maxRange * maxRange * maxRange);
		pbr.occlusionFactor = occlusionFactor;

		if(cookie != null){
			pbr.useCookie = true;
			pbr.cookieTex = cookie;
			generateLightProj();
			pbr.lightProj.load(lightProj.m);
		}else{
			pbr.useCookie = false;
		}
	}

	var s(get,never): h3d.col.Sphere;
	var d(get,never): h3d.Vector;
	inline function get_s() return this.spotState.s;
	inline function get_d() return this.spotState.d;
	override function emit(ctx:RenderContext.EmitContext) {
		if( ctx.computingStatic ) {
			super.emit(ctx);
			return;
		}

		if( ctx.pbrLightPass == null )
			throw "Rendering a pbr light require a PBR compatible scene renderer";

		d.load(absPos.front());
		d.scale3(maxRange / 2.0);
		s.x = absPos.tx + d.x;
		s.y = absPos.ty + d.y;
		s.z = absPos.tz + d.z;
		s.r = maxRange / 2.0;

		if( !ctx.camera.frustum.hasSphere(s) )
			return;

		super.emit(ctx);
		ctx.emitPass(ctx.pbrLightPass, this);
	}
}

@:forward(range, angle, fallOff, cookie, lightProj, s, d, primitive, color)
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
