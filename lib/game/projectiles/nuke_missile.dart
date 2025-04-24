import 'dart:math';

import 'package:flame/collisions.dart';
import 'package:flame/components.dart';
import 'package:flame/sprite.dart';
import 'package:flutteroids/core/atlas.dart';
import 'package:flutteroids/game/common/decals.dart';
import 'package:flutteroids/game/common/game_context.dart';
import 'package:flutteroids/game/common/kinds.dart';
import 'package:flutteroids/game/projectiles/directional_projectile.dart';
import 'package:flutteroids/game/world/world_entity.dart';
import 'package:flutteroids/util/component_recycler.dart';

class NukeMissile extends SpriteComponent
    with GameContext, CollisionCallbacks, Recyclable, WorldEntity, DirectionalProjectile, HasVisibility {
  //

  late final Decals decals;
  late final Function(WorldEntity) _emit_nuke;
  late final SpriteSheet _sprites;

  double _speed = 100;
  double _anim_time = 0;
  double _smoke_time = 0;

  NukeMissile(this.decals, this._emit_nuke) {
    anchor = Anchor.center;
    size.setAll(30);
    _sprites = atlas.sheetI('missile.png', 4, 1);
    sprite = _sprites.getSprite(0, 0);
    add(CircleHitbox(radius: 15, isSolid: true));
    priority = 100;
  }

  @override
  double get base_speed => _speed;

  @override
  void reset(Player origin, double angle) {
    super.reset(origin, angle);
    _speed = 100;

    this.angle = angle + pi / 2; // missile sprite is facing up, player is facing right
  }

  @override
  void update(double dt) {
    super.update(dt);

    _speed += 50 * dt + pow(_speed, 0.9) * dt;
    _anim_time = (_anim_time + dt * 4) % 1;
    _smoke_time += dt;
    if (_smoke_time > 0.01) {
      _smoke_time = 0;
      decals.spawn(DecalKind.smoke, this);
    }

    final sprite_index = (_anim_time * (_sprites.columns - 1)).toInt();
    sprite = _sprites.getSprite(0, sprite_index);
  }

  @override
  void onCollision(Set<Vector2> intersectionPoints, PositionComponent other) {
    super.onCollision(intersectionPoints, other);
    if (recycled) return;
    if (other case Hostile it when it.susceptible) {
      it.on_hit(50);
      _emit_nuke(this);
      recycle();
    }
  }
}
