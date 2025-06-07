import 'dart:math';

import 'package:flame/collisions.dart';
import 'package:flame/components.dart';
import 'package:flame/sprite.dart';
import 'package:flutteroids/core/atlas.dart';
import 'package:flutteroids/core/common.dart';
import 'package:flutteroids/game/common/kinds.dart';
import 'package:flutteroids/game/projectiles/directional_projectile.dart';
import 'package:flutteroids/game/world/world_entity.dart';
import 'package:flutteroids/util/component_recycler.dart';
import 'package:flutteroids/util/random.dart';

class IonPulse extends SpriteComponent
    with CollisionCallbacks, Recyclable, WorldEntity, DirectionalProjectile, HasVisibility {
  //

  static SpriteSheet? _sprites;

  double appear_delay = 0;
  double size_anim = 1;

  late double damage = 1.0;

  IonPulse() {
    anchor = Anchor.center;
    size.setAll(16);
    _sprites ??= atlas.sheetI('melt.png', 5, 1);
    sprite = _sprites!.getSprite(0, 0);
    add(CircleHitbox(radius: 8, isSolid: true));
  }

  void reset_with_delay(Player origin, double angle, double delay, [int boost = 0]) {
    damage = 1.0 * (1 + 0.5 * (boost / PrimaryWeapon.max_boosts));
    super.reset(origin, angle);
    appear_delay = delay;
    size_anim = 1;
    max_distance = DirectionalProjectile.world_size();
  }

  @override
  void update(double dt) {
    isVisible = appear_delay <= 0;

    if (appear_delay > 0) {
      appear_delay = max(0, appear_delay - dt);
      world_pos.setZero();
      return;
    }

    super.update(dt);

    if (size_anim > 0) {
      size_anim = max(0, size_anim - dt * 5);
      final which = (size_anim * (_sprites!.columns - 1)).toInt();
      sprite = _sprites!.getSprite(0, which);
    }

    if (size_anim < 0) {
      size_anim = min(0, size_anim + dt * 5);
      final which = ((1 + size_anim) * (_sprites!.columns - 1)).toInt();
      sprite = _sprites!.getSprite(0, which.clamp(0, _sprites!.columns - 1));
      if (size_anim == 0) recycle();
    }
  }

  @override
  void onCollision(Set<Vector2> intersectionPoints, PositionComponent other) {
    super.onCollision(intersectionPoints, other);
    if (recycled) return;
    if (other case Hostile it when it.susceptible) {
      it.on_hit(damage * size_anim.abs());
      size_anim = -1;
      change_direction(level_rng.nextDoublePM(pi / 4));
    }
  }
}
