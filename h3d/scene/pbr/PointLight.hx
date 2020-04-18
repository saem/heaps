package h3d.scene.pbr;

class PointLight extends Light<h3d.shader.pbr.Light.PointLight> {

	public var size : Float;
	public var zNear : Float = 0.02;
	/**
		Alias for uniform scale.
	**/
	public var range(get,set) : Float;

	@:allow(h3d.scene.Object.createPbrPointLight)
	private function new(?parent) {
		shadows = new h3d.pass.PointShadowMap(this, true);
		super(new h3d.shader.pbr.Light.PointLight(),parent);
		range = 10;
		primitive = h3d.prim.Sphere.defaultUnitSphere();
	}

	public override function clone( ?o : h3d.scene.Object ) : h3d.scene.Object {
		var pl = o == null ? h3d.scene.Object.createPbrPointLight(null) : cast o;
		super.clone(pl);
		pl.size = size;
		pl.range = range;
		return pl;
	}

	function get_range() {
		return cullingDistance;
	}

	function set_range(v:Float) {
		setScale(v);
		return cullingDistance = v;
	}

	override function draw(ctx:RenderContext.DrawContext) {
		primitive.render(ctx.engine);
	}

	override function sync(ctx) {
		super.sync(ctx);

		pbr.lightColor.load(_color);
		var range = hxd.Math.max(range, 1e-10);
		var size = hxd.Math.min(size, range);
		var power = power * 10; // base scale
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