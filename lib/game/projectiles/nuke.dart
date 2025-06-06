import 'dart:ui';

import 'package:flame/collisions.dart';
import 'package:flame/components.dart';
import 'package:flutter/animation.dart';
import 'package:flutteroids/core/common.dart';
import 'package:flutteroids/game/common/kinds.dart';
import 'package:flutteroids/game/world/world_entity.dart';
import 'package:flutteroids/util/component_recycler.dart';
import 'package:flutteroids/util/extensions.dart';

class Nuke extends PositionComponent with CollisionCallbacks, Recyclable, WorldEntity, HasPaint {
  //

  late double life_time;
  late double damage;
  int _boost = 0;

  Nuke() {
    size.setAll(250);
    add(CircleHitbox(anchor: Anchor.center, isSolid: true));

    paint.color = white;
    paint.maskFilter = MaskFilter.blur(BlurStyle.normal, 16);

    priority = 1000;
  }

  void reset(WorldEntity origin, [int boost = 0]) {
    _boost = boost;
    size.setAll(250 + 75 * (1 + (_boost / SecondaryWeapon.max_boosts)));
    life_time = 0;
    damage = 10;
    world_pos.setFrom(origin.world_pos);
  }

  @override
  void update(double dt) {
    super.update(dt);
    life_time += dt;
    if (life_time > 1) recycle();
  }

  @override
  void render(Canvas canvas) {
    final saved = paint.opacity;

    final x = life_time < 0.5 ? life_time * 2 : 1 - (life_time - 0.5) * 2;
    final o = Curves.easeInOutCubic.transform(x.clamp(0, 1));
    paint.opacity *= o;
    canvas.drawCircle(Offset.zero, size.x / 2, paint);

    paint.opacity = saved;
  }

  @override
  void onCollision(Set<Vector2> intersectionPoints, PositionComponent other) {
    super.onCollision(intersectionPoints, other);
    if (recycled || life_time > 0.2) return;
    if (other case Hostile it when it.susceptible) {
      it.on_hit(damage * (1 + (_boost / SecondaryWeapon.max_boosts)));
    }
  }
}
