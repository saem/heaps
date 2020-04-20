package h3d.scene;

interface Materialable {
    var materials(get,set): Array<h3d.mat.Material>;
    var material(get,set): h3d.mat.Material;
}