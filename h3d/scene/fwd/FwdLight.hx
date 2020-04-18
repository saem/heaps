package h3d.scene.fwd;

class FwdLight<S:h3d.shader.Light> extends h3d.scene.Light {
    var _shader(get,set): S;
    inline function get__shader():S return cast this.shader;
    inline function set__shader(s: S):S return cast this.shader = cast s;

    private function new(shader: S, parent) {
        super(shader, parent);
    }

    override function get_color() {
        return _shader.color;
    }

    override function set_color(v) {
        return _shader.color = v;
    }

	override function get_enableSpecular() {
		return _shader.enableSpecular;
	}

	override function set_enableSpecular(b) {
		return _shader.enableSpecular = b;
	}
}