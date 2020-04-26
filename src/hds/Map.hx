package hds;

#if js

abstract Map<K,V>(js.lib.Map<K,V>) {
    public inline function new() {
        this = new js.lib.Map<K,V>();
    }

    @:arrayAccess public inline function get(k:K):V
        return this.get(k);

    public inline function set(key:K, value:V):Void
        this.set(key, value);

    public inline function exists(key:K):Bool
        return this.has(key);

    public inline function remove(key:K):Bool
        return this.delete(key);

    public inline function keys():Iterator<K>
        return new HaxeIterator(this.keys());

    public inline function iterator():Iterator<V>
        return new HaxeIterator(this.values());

    public inline function keyValueIterator():KVIterator<K,V>
        return new HaxeIterator(this.entries());

    public inline function copy():Map<K,V>
        return cast new js.lib.Map<K,V>(this);

    public inline function toString():String {
        final s = new StringBuf();
		s.add("{");
		final it = keys();
		for (i in it) {
			s.add(i);
			s.add(" => ");
			s.add(Std.string(get(i)));
			if (it.hasNext())
				s.add(", ");
		}
		s.add("}");
        return s.toString();
    }

    public inline function clear():Void
        return this.clear();

	@:arrayAccess @:noCompletion public inline function arrayWrite(k:K, v:V):V {
		this.set(k, v);
		return v;
    }
}

typedef KVIterator<K,V> = HaxeIterator<KeyValue<K,V>>;

class HaxeIterator<T> {
    var iter: js.lib.Iterator<T>;
    var step: js.lib.Iterator.IteratorStep<T>;
    
    public inline function new(iter:js.lib.Iterator<T>) {
        this.iter = iter;
        this.step = iter.next();
    }

    public inline function hasNext(): Bool {
        return !step.done;
    }
    public inline function next(): T {
        final v = step.value;
        step = iter.next();
        return v;
    }
}

typedef KeyValue<K,V> = js.lib.Map.MapEntry<K,V>;

#else

typedef Map<K,V> = haxe.ds.Map<K,V>;

#end