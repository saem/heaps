package hxd.res;

enum Platform {
	HL;
	JS;
	Unknown;
}

/**
	Resources configuration file.
	Should be modified with --macro to be sure it's correctly setup before any code is compiled.
**/
class Config {

	/**
		Maps the extension to a given resource class. Example ["wav,mp3,ogg" => "hxd.res.Sound"]
	**/
	public static var extensions = [
		"jpg,png,jpeg,gif,tga" => "hxd.res.Image",
		"fbx,hmd,obj,gltf,glb" => "hxd.res.Model",
		"ttf" => "hxd.res.Font",
		"fnt" => "hxd.res.BitmapFont",
		"bdf" => "hxd.res.BDFFont",
		"wav,mp3,ogg" => "hxd.res.Sound",
		"tmx" => "hxd.res.TiledMap",
		"atlas" => "hxd.res.Atlas",
		"grd" => "hxd.res.Gradients",
		#if hide
		"prefab,fx,l3d" => "hxd.res.Prefab"
		#end
	];

	/**
		File extensions ignored by the resource scan
	**/
	public static var ignoredExtensions = [
		"gal" => true, // graphics gale source
		"lch" => true, // labchirp source
	];


	/**
		Paired extensions are files that can have the same name but different extensions.
		Only the "main" one will be accessible through hxd.Res.
		Example : ["fbx" => "png,jpg,jpeg,gif"]
	**/
	public static var pairedExtensions = [
		"fnt" => "png",
		"fbx" => "png,jpg,jpeg,gif,tga",
		"cdb" => "img",
		"atlas" => "png",
		"ogg" => "wav",
		"mp3" => "wav",
		"l3d" => "bake",
		"css" => "less",
	];

	#if macro
	static function defined( name : String ) {
		return haxe.macro.Context.defined(name);
	}
	#else
	static function defined(name: String) {
		#if hl
			return name == "hl";
		#elseif js
			return name == "js";
		#else
			return false;
		#end
	}
	#end

	static function init() {
		var pf =
			if( defined("js") ) JS else
			if( defined("hl") ) HL else
			Unknown;
		switch( pf ) {
		case HL:
			#if !heaps_enable_hl_mp3
			ignoredExtensions.set("mp3", true);
			#end
		default:
			#if !stb_ogg_sound
			ignoredExtensions.set("ogg", true);
			#end
		}
		return pf;
	}

	public static var platform : Platform = init();

}
