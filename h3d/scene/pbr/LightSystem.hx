package h3d.scene.pbr;

@:access(h3d.scene.pbr.Light)
class LightSystem extends h3d.scene.LightSystem {

	override function computeLight( obj : h3d.pass.DrawObject, shaders : hxsl.ShaderList ) : hxsl.ShaderList {
		var light = ctx.pbrLightIndex.get(obj.id);
		if( light != null ) {
			shaders = ctx.allocShaderList(light.shader, shaders);
			if( light.shadows.shader != null && light.shadows.mode != None )
				shaders = ctx.allocShaderList(light.shadows.shader, shaders);
		}
		return shaders;
	}


	public function drawLight( light : Light, passes : h3d.pass.PassList ) {
		light.shadows.setContext(ctx);
		light.shadows.draw(passes);
		passes.reset();
	}

	public function drawScreenLights( r : h3d.scene.Renderer, lightPass : h3d.pass.ScreenFx<Dynamic> ) {
		var plight = @:privateAccess ctx.lights;
		while( plight != null ) {
			var light = hxd.impl.Api.downcast(plight, h3d.scene.pbr.Light);
			if( light != null && light.primitive == null ) {
				if( light.shadows.shader != null ) lightPass.addShader(light.shadows.shader);
				lightPass.addShader(light.shader);
				lightPass.render();
				lightPass.removeShader(light.shader);
				if( light.shadows.shader != null ) lightPass.removeShader(light.shadows.shader);
			}
			plight = plight.next;
		}
	}
}
