package h3d.pass;

typedef LightObject = {
    var shadows(get, never): h3d.pass.Shadows;
    var shader(get, never): hxsl.Shader;
};