package h3d.shader;

class DirLight extends Light {

	static var SRC = {

		@param var direction : Vec3;

		function calcLighting() : Vec3 {
			var diff = transformedNormal.dot(-direction).max(0.);
			if( !enableSpecular )
				return color * diff;
			var r = reflect(direction, transformedNormal).normalize();
			var specValue = r.dot((camera.position - transformedPosition).normalize()).max(0.);
			return color * (diff + specColor * pow(specValue, specPower));
		}

		function vertex() {
			lightColor.rgb += calcLighting();
		}

		function fragment() {
			lightPixelColor.rgb += calcLighting();
		}

	}

	public function new() {
		super();
	}

}