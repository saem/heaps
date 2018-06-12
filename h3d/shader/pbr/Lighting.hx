package h3d.shader.pbr;

class Indirect extends PropsDefinition {

	static var SRC = {

		@param var irrLut : Sampler2D;
		@param var irrDiffuse : SamplerCube;
		@param var irrSpecular : SamplerCube;
		@param var irrSpecularLevels : Float;
		@param var irrPower : Float;

		function fragment() {
			if( normal.dot(normal) <= 0 ) discard;

			var F0 = pbrSpecularColor;
			var F = F0 + (max(vec3(1 - roughness), F0) - F0) * exp2( ( -5.55473 * NdV - 6.98316) * NdV );

			var diffuse = irrDiffuse.get(normal).rgb * albedo;
			var envSpec = textureCubeLod(irrSpecular, reflect(-view,normal), roughness * irrSpecularLevels).rgb;
			var envBRDF = irrLut.get(vec2(roughness, NdV));
			var specular = envSpec * (F * envBRDF.x + envBRDF.y);
			/*
				// diffuse *= occlusion
				Usually indirect diffuse is multiplied by occlusion, but since our occlusion mosly
				comes from shadow map, we want to keep the diffuse term for colored shadows here.
			*/
			var indirect = (diffuse * (1 - metalness) * (1. - F) + specular) * irrPower;
			pixelColor.rgb += indirect;
		}

	};

}

class Direct extends PropsDefinition {

	static var SRC = {

		var pbrLightDirection : Vec3;
		var pbrLightColor : Vec3;
		@const var doDiscard : Bool = true;

		function fragment() {
			var NdL = normal.dot(pbrLightDirection).max(0.);
			if( pbrLightColor.dot(pbrLightColor) > 0.0001 && NdL > 0 ) {

				var half = (pbrLightDirection + view).normalize();
				var NdH = normal.dot(half).max(0.);
				var VdH = view.dot(half).max(0.);

				// diffuse BRDF
				var direct : Vec3 = vec3(0.);

				// ------------- DIRECT LIGHT -------------------------

				var F0 = pbrSpecularColor;
				var diffuse = albedo * NdL / PI;

				// General Cook-Torrance formula for microfacet BRDF
				// 		f(l,v) = D(h).F(v,h).G(l,v,h) / 4(n.l)(n.v)

				// formulas below from 2013 Siggraph "Real Shading in UE4"
				var alpha = roughness * roughness;

				// D = normal distribution fonction
				// GGX (Trowbridge-Reitz) "Disney"
				var alpha2 = alpha * alpha;
				var denom = NdH * NdH * (alpha2 - 1.) + 1;
				var D = alpha2 / (PI * denom * denom);

				// F = fresnel term
				// Schlick approx
				// pow 5 optimized with Spherical Gaussian
				// var F = F0 + (1 - F0) * pow(1 - v.dot(h).min(1.), 5.);
				var F = F0 + (1. - F0) * exp2( ( -5.55473 * VdH - 6.98316) * VdH );

				// G = geometric attenuation
				// Schlick (modified for UE4 with k=alpha/2)
				// k = (rough + 1)² / 8
				var k = (roughness + 1);
				k *= k;
				k *= 0.125;
				var G = (NdV / (NdV * (1 - k) + k)) * (NdL / (NdL * (1 - k) + k));

				var specular = (D * F * G / (4 * NdL * NdV)).max(0.);
				direct += mix(diffuse * (1 - metalness), specular, F) * pbrLightColor;
				direct *= occlusion;
				pixelColor.rgb += direct;
			} else if( doDiscard )
				discard;
		}
	};

}
