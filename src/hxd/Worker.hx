package hxd;

class Worker<T:EnumValue> {

	public static var ENABLE = false;
	var enumValue : Enum<T>;
	var isWorker : Bool;
	var debugPeer : Worker<T>;
	var useWorker : Bool;

	public function new( e : Enum<T> ) {
		this.enumValue = e;
		this.useWorker = ENABLE;
	}

	function clone() : Worker<T> {
		throw "Not implemented";
		return null;
	}

	public function send( msg : T ) {
		if( !useWorker ) {
			#if debug
			// emulate delay
			haxe.Timer.delay(debugPeer.handleMessage.bind(msg), 1);
			#else
			debugPeer.handleMessage(msg);
			#end
			return;
		}
		throw "TODO";
	}

	function readMessage() : T {
		throw "TODO";
	}

	function handleMessage( msg : T ) {
		throw "TODO";
	}

	function setupMain() {
	}

	function setupWorker() {
	}

	public function start() {
		if( !useWorker ) {
			isWorker = false;
			setupMain();
			debugPeer = clone();
			debugPeer.isWorker = true;
			debugPeer.setupWorker();
			debugPeer.debugPeer = this;
			return false;
		}
		throw "Native worker not supported for this platform";
	}

}