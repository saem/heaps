package h3d.scene;

/**
	h3d.scene.Mesh is the base class for all 3D objects displayed on screen.
	Unlike Object base class, all properties of Mesh only apply to the current object and are not inherited by its children.
**/
class Mesh extends h3d.scene.Object {

	/**
		The primitive of the mesh: the list of vertexes and indices necessary to display the mesh.
	**/
	public var primitive(default, set) : h3d.prim.Primitive;

	public var materials = new Array<h3d.mat.Material>();

	/**
		The material of the mesh: the properties used to display it (texture, color, shaders, etc.)
	**/
	public var material(get, set) : h3d.mat.Material;
	inline function get_material() return this.materials[0];
	inline function set_material(m) return this.materials[0] = m;
	/**
		Creates a new mesh with given primitive, materials, and parent object.
		If material is not specified, a new default material is created for the current renderer.
	**/
	@:allow(h3d.scene.Object.createMesh)
	@:allow(h3d.scene.Object.createMeshWithMaterials)
	private function new( primitive, ?materials : Array<h3d.mat.Material> = null, ?parent = null ) {
		super(parent);
		this.primitive = primitive;
		this.materials = ( materials == null || materials.length == 0 ) ?
			[h3d.mat.MaterialSetup.current.createMaterial()] :
			materials;
		material.props = material.getDefaultProps();
	}

	/**
		Return all materials for the current object.
	**/
	public function getMeshMaterials() {
		return materials.copy();
	}

	override function getBoundsRec( b : h3d.col.Bounds ) {
		b = super.getBoundsRec(b);
		if( primitive == null || ignoreBounds )
			return b;
		var tmp = primitive.getBounds().clone();
		tmp.transform(absPos);
		b.add(tmp);
		return b;
	}

	override function clone( ?o : Object ) : Object {
		var m = o == null ? h3d.scene.Object.createMeshWithMaterials(null) : cast o;
		m.materials = [];
		m.primitive = primitive;
		for( mat in materials )
			m.materials.push(if( mat == null ) null else cast mat.clone());
		super.clone(m);
		return m;
	}

	override function getLocalCollider() : h3d.col.Collider {
		return primitive.getCollider();
	}

	override function draw( ctx : RenderContext.DrawContext ) {
		if( materials.length > 1 )
			primitive.selectMaterial(ctx.drawPass.index);

		primitive.render(ctx.engine);

		super.draw(ctx);
	}

	override function emit( ctx : RenderContext.EmitContext ) {
		for( i in 0...materials.length ) {
			var m = materials[i];
			if( m != null )
				ctx.emit(m, this, i);
		}
	}

	override function getMaterialByName( name : String ) : h3d.mat.Material {
		for( m in materials )
			if( m != null && m.name == name )
				return m;
		return super.getMaterialByName(name);
	}

	override function getMaterials( ?a : Array<h3d.mat.Material> ) {
		if( a == null ) a = [];
		for( m in materials )
			if( m != null && a.indexOf(m) < 0 )
				a.push(m);
		for( o in children )
			o.getMaterials(a);
		return super.getMaterials(a);
	}

	#if (hxbit && !macro && heaps_enable_serialize)
	override function customSerialize(ctx:hxbit.Serializer) {
		super.customSerialize(ctx);
		ctx.addKnownRef(primitive);
		ctx.addInt(materials.length);
		for( m in materials ) ctx.addKnownRef(m);
	}
	override function customUnserialize(ctx:hxbit.Serializer) {
		super.customUnserialize(ctx);
		primitive = ctx.getKnownRef(h3d.prim.Primitive);
		materials = [for( i in 0...ctx.getInt() ) ctx.getKnownRef(h3d.mat.Material)];
	}
	#end

	override private function onAdd()
	{
		super.onAdd();
		if ( primitive != null ) primitive.incref();
	}

	override private function onRemove()
	{
		if ( primitive != null ) primitive.decref();
		super.onRemove();
	}

	function set_primitive( prim : h3d.prim.Primitive ) : h3d.prim.Primitive {
		if ( prim != this.primitive && allocated ) {
			if (this.primitive != null) this.primitive.decref();
			if (prim != null) prim.incref();
		}
		return this.primitive = prim;
	}

}