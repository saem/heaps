package hxd.net;

private class SocketOutput extends haxe.io.Output {

	public function new() {
	}

	/**
		Delay sending data until flush() is called
	**/
	public function wait() {
	}

	override function writeByte( c : Int ) {
	}

	override function writeBytes( s : haxe.io.Bytes, pos : Int, len : Int ) : Int {
		return len;
	}

}

private class SocketInput extends haxe.io.Input {

	public var available(get, never) : Int;

	function get_available() {
		return 0;
	}

}

class Socket {

	static var openedSocks = [];
	#if hl
	var s : #if (haxe_ver >= 4) hl.uv.Stream #else Dynamic #end;
	#end
	public var out(default, null) : SocketOutput;
	public var input(default, null) : SocketInput;
	public var timeout(default, set) : Null<Float>;

	public function new() {
		out = new SocketOutput();
		#if hl
			#if (haxe_ver < 4)
			throw "Not supported in Haxe 3.x";
			#end
		#end
	}

	public function set_timeout(t:Null<Float>) {
		return this.timeout = t;
	}

	public function connect( host : String, port : Int, onConnect : Void -> Void ) {
		close();
		openedSocks.push(this);
		#if (hl && haxe_ver >= 4)
		var tcp = new hl.uv.Tcp();
		s = tcp;
		tcp.connect(new sys.net.Host(host), port, function(b) {
			if( !b ) {
				close();
				onError("Failed to connect");
				return;
			}
			out = new HLSocketOutput(this);
			input = new HLSocketInput(this);
			onConnect();
		});
		#else
		throw "Not implemented";
		#end
	}

	public static inline var ALLOW_BIND = false;

	public function bind( host : String, port : Int, onConnect : Socket -> Void, listenCount = 5 ) {
		close();
		openedSocks.push(this);
		#if (hl && haxe_ver >= 4)
		var tcp = new hl.uv.Tcp();
		s = tcp;
		try {
			tcp.bind(new sys.net.Host(host), port);
			tcp.listen(10, function() {
				var sock = tcp.accept();
				var s = new Socket();
				s.s = sock;
				s.out = new HLSocketOutput(s);
				s.input = new HLSocketInput(s);
				openedSocks.push(s);
				onConnect(s);
			});
		} catch( e : Dynamic ) {
			close();
			throw e;
		}
		#else
		throw "Not implemented";
		#end
	}

	public function close() {
		openedSocks.remove(this);
		#if hl
		if( s != null ) {
			try s.close() catch( e : Dynamic ) { };
			out = new SocketOutput();
			s = null;
		}
		#end
	}

	public dynamic function onError(msg:String) {
		throw "Socket Error " + msg;
	}

	public dynamic function onData() {
	}
}

#if hl

class HLSocketOutput extends SocketOutput {

	var tmpBuf : haxe.io.Bytes;
	var s : Socket;
	var onWriteResult : Bool -> Void;

	public function new(s) {
		super();
		this.s = s;
		onWriteResult = writeResult;
	}

	function writeResult(b) {
		if( !b ) {
			s.close();
			s.onError("Failed to write data");
		}
	}

	override function writeByte(c:Int) {
		if( tmpBuf == null )
			tmpBuf = haxe.io.Bytes.alloc(1);
		tmpBuf.set(0, c);
		@:privateAccess s.s.write(tmpBuf, onWriteResult);
	}

	override function writeBytes(buf:haxe.io.Bytes, pos:Int, len:Int):Int {
		@:privateAccess s.s.write(buf, onWriteResult, pos, len);
		return len;
	}

}

class HLSocketInput extends SocketInput {

	var s : Socket;
	var data : hl.Bytes;
	var pos : Int;
	var len : Int;
	var size : Int;

	public function new(sock) {
		this.s = sock;
		@:privateAccess s.s.readStartRaw(onData);
	}

	function onData(recvData:hl.Bytes, recv:Int) {
		if( recv < 0 ) {
			s.close();
			s.onError("Connection closed");
			return;
		}
		var req = pos + len + recv;
		if( req > size && pos >= (size >> 1) ) {
			data.blit(0, data, pos, len);
			pos = 0;
			req -= pos;
		}
		if( req > size ) {
			var nsize = size == 0 ? 1024 : size;
			while( nsize < req ) nsize = (nsize * 3) >> 1;
			var ndata = new hl.Bytes(nsize);
			ndata.blit(0, data, pos, len);
			data = ndata;
			size = nsize;
			pos = 0;
		}
		data.blit(pos + len, recvData, 0, recv);
		len += recv;
		s.onData();
	}

	override function get_available() {
		return len;
	}

	override function readByte():Int {
		if( len == 0 ) throw new haxe.io.Eof();
		var c = data[pos++];
		len--;
		return c;
	}

	override function readBytes(s:haxe.io.Bytes, pos:Int, len:Int):Int {
		if( pos < 0 || len < 0  || pos + len > s.length ) throw haxe.io.Error.OutsideBounds;
		var max = len < this.len ? len : this.len;
		@:privateAccess s.b.blit(pos, data, this.pos, max);
		this.pos += max;
		this.len -= max;
		return max;
	}

}

#end