package h3d.shader;

class Light extends hxsl.Shader {
    static var SRC = {
        @const var enableSpecular : Bool;
        @param var color : Vec3;
        @global var camera : {
			var position : Vec3;
		};

		var lightColor : Vec3;
		var lightPixelColor : Vec3;
		var transformedNormal : Vec3;
		var transformedPosition : Vec3;
		var specPower : Float;
		var specColor : Vec3;
    }

	public function new() {
		super();
		color.set(1, 1, 1);
	}
}