package hxd.fs;

#if !macro

@:allow(hxd.fs.EmbedFileSystem)
@:access(hxd.fs.EmbedFileSystem)
private class EmbedEntry extends FileEntry {

	var fs : EmbedFileSystem;
	var relPath : String;
	var data : String;
	var bytes : haxe.io.Bytes;
	var readPos : Int;

	function new(fs, name, relPath, data) {
		this.fs = fs;
		this.name = name;
		this.relPath = relPath;
		this.data = data;
	}

	override function getSign() : Int {
		var old = readPos;
		open();
		readPos = old;
		return bytes.get(0) | (bytes.get(1) << 8) | (bytes.get(2) << 16) | (bytes.get(3) << 24);
	}

	override function getBytes() : haxe.io.Bytes {
		if( bytes == null )
			open();
		return bytes;
	}

	override function open() {
		if( bytes == null ) {
			bytes = haxe.Resource.getBytes(data);
			if( bytes == null ) throw "Missing resource " + data;
		}
		readPos = 0;
	}

	override function skip( nbytes : Int ) {
		readPos += nbytes;
	}

	override function readByte() : Int {
		return bytes.get(readPos++);
	}

	override function read( out : haxe.io.Bytes, pos : Int, size : Int ) : Void {
		out.blit(pos, bytes, readPos, size);
		readPos += size;
	}

	override function close() {
		bytes = null;
		readPos = 0;
	}

	override function load( ?onReady : Void -> Void ) : Void {
		#if js
		if( onReady != null ) haxe.Timer.delay(onReady, 1);
		#end
	}

	override function loadBitmap( onLoaded : LoadedBitmap -> Void ) : Void {
		#if js
		// directly get the base64 encoded data from resources
		var rawData = null;
		for( res in @:privateAccess haxe.Resource.content )
			if( res.name == data ) {
				rawData = res.data;
				break;
			}
		if( rawData == null ) throw "Missing resource " + data;
		var image = new js.html.Image();
		image.onload = function(_) {
			onLoaded(new LoadedBitmap(image));
		};
		var extra = "";
		var bytes = (rawData.length * 6) >> 3;
		for( i in 0...(3-(bytes*4)%3)%3 )
			extra += "=";
		image.src = "data:image/" + extension + ";base64," + rawData + extra;
		#else
		throw "TODO";
		#end
	}

	override function get_isDirectory() {
		return fs.isDirectory(relPath);
	}

	override function get_path() {
		return relPath == "." ? "<root>" : relPath;
	}

	override function exists( name : String ) {
		return fs.exists(relPath == "." ? name : relPath + "/" + name);
	}

	override function get( name : String ) {
		return fs.get(relPath == "." ? name : relPath + "/" + name);
	}

	override function get_size() {
		open();
		return bytes.length;
	}

	override function iterator() {
		return new hxd.impl.ArrayIterator(fs.subFiles(relPath));
	}

}

#end

class EmbedFileSystem #if !macro implements FileSystem #end {

	#if !macro

	var root : Dynamic;

	function new(root) {
		this.root = root;
	}

	public function getRoot() : FileEntry {
		return new EmbedEntry(this,"root",".",null);
	}

	static var invalidChars = ~/[^A-Za-z0-9_]/g;
	static function resolve( path : String ) {
		return "R_" + invalidChars.replace(path, "_");
	}

	function splitPath( path : String ) {
		return path == "." ? [] : path.split("/");
	}

	function  subFiles( path : String ) : Array<FileEntry> {
		var r = root;
		for( p in splitPath(path) )
			r = Reflect.field(r, p);
		if( r == null )
			throw path + " is not a directory";
		var fields = Reflect.fields(r);
		fields.sort(Reflect.compare);
		return [for( name in fields ) get(path == "." ? name : path + "/" + name)];
	}

	function isDirectory( path : String ) {
		var r : Dynamic = root;
		for( p in splitPath(path) )
			r = Reflect.field(r, p);
		return r != null && r != true;
	}

	public function exists( path : String ) {
		var r = root;
		for( p in splitPath(path) ) {
			r = Reflect.field(r, p);
			if( r == null ) return false;
		}
		return true;
	}

	public function get( path : String ) {
		if( !exists(path) )
			throw new NotFound(path);
		var id = resolve(path);
		return new EmbedEntry(this, path.split("/").pop(), path, id);
	}

	#end

	#if macro
	static function makeTree( t : hxd.res.FileTree.FileTreeData ) : Dynamic {
		var o = {};
		for( d in t.dirs )
			Reflect.setField(o, d.name, makeTree(d));
		for( f in t.files )
			Reflect.setField(o, f.file, true);
		return o;
	}
	#end

	public static macro function create( ?basePath : String, ?options : hxd.res.EmbedOptions ) {
		var f = new hxd.res.FileTree(basePath);
		var data = f.embed(options);
		var sdata = haxe.Serializer.run(makeTree(data.tree));
		var types = {
			expr : haxe.macro.Expr.ExprDef.EBlock([for( t in data.types ) haxe.macro.MacroStringTools.toFieldExpr(t.split("."))]),
			pos : haxe.macro.Context.currentPos(),
		};
		return macro { $types; @:privateAccess new hxd.fs.EmbedFileSystem(haxe.Unserializer.run($v { sdata } )); };
	}

	public function dispose() {
	}

	public function dir( path : String ) : Array<FileEntry> {
		throw "Not Supported";
	}

}
