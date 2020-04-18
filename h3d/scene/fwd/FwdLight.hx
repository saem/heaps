package h3d.scene.fwd;

class FwdLight extends h3d.scene.Light {
    var _shader(get, never): h3d.shader.Light;
    inline function get__shader():h3d.shader.Light return cast this._state.shader;

    private function new(state: h3d.scene.Light.State, parent) {
        super(state, parent);
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