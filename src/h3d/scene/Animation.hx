package h3d.scene;

import h3d.scene.SceneStorage.EntityId;

/**
    TODO - Future consolidation of animation state:
    - h3d.anim.Animation should have one backing state
    - Backing state should include necessary fields for entity association
**/
@:forward(id)
abstract Animation(AnimationRow) from AnimationRow {
    public var currentAnimation(get, never): h3d.anim.Animation;
    inline function get_currentAnimation() return this.state.match(Remove) ? null : this.currentAnimation;

    // Functions to register animations
    public static function scheduleAnimation(storage:SceneStorage, id:EntityId, a:h3d.anim.Animation): Animation {
        final row = storage.objectAnimationStorage.fetchRow(id);
        row.state = Play;
        row.currentAnimation = a.createUnboundInstance();
        return row;
    }

    public static function switchToAnimation(storage:SceneStorage, id:EntityId, a:h3d.anim.Animation) {
        return storage.objectAnimationStorage.fetchRow(id).currentAnimation = a;
    }

    public static function stopAnimation(storage:SceneStorage, id: EntityId) {
        storage.objectAnimationStorage.fetchRow(id).state = Remove;
    }
}

class AnimationRow {
	public final id: AnimationId;

	public var currentAnimation: h3d.anim.Animation = null;
	public var state: AnimationState = Removed;

	public function new(id: AnimationId) {
		this.id = id;
    }
}

enum AnimationState {
    Play;
    Playing;
    Remove;
    Removed;
}

abstract AnimationId(EntityId) from EntityId to EntityId {}

class AnimationStorage {
	final storage = new hds.Map<AnimationId, AnimationRow>();

	public function new() {}

	public function allocateRow(eid: h3d.scene.SceneStorage.EntityId): AnimationId {
		final row = new AnimationRow(eid);
		this.storage.set(eid, row);

		return eid;
	}

	public function deallocateRow(id: AnimationId) {
		return this.storage.remove(id);
	}

	public function fetchRow(id: AnimationId) {
		return this.storage.get(id);
	}

	public function reset() {
		this.storage.clear();
	}
}