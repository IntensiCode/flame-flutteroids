import 'dart:math';
import 'dart:ui';

import 'package:flame/collisions.dart';
import 'package:flame/components.dart';
import 'package:flutteroids/core/common.dart';
import 'package:flutteroids/game/common/kinds.dart';
import 'package:flutteroids/game/projectiles/directional_projectile.dart';
import 'package:flutteroids/game/world/world_entity.dart';
import 'package:flutteroids/util/component_recycler.dart';

class PlasmaShot extends PositionComponent
    with CollisionCallbacks, Recyclable, WorldEntity, DirectionalProjectile, HasPaint {
  //

  static const _blue1 = Color(0xFFa0a0ff);
  static const _blue2 = Color(0xFF20209f);

  static double power_boost = 1;

  PlasmaShot() {
    size.setAll(2.7);
    add(CircleHitbox(radius: 2.7, anchor: Anchor.center, isSolid: true));
  }

  double _start_time = 1;

  @override
  double get base_speed => 400 + power_boost * 25 + speed_buff;

  double speed_buff = 0;

  @override
  void reset(Player origin, double angle) {
    super.reset(origin, angle);
    _start_time = 1;
  }

  @override
  void update(double dt) {
    super.update(dt);
    if (_start_time > 0) _start_time = max(0, _start_time - dt);
  }

  @override
  void render(Canvas canvas) {
    paint.color = _blue2;
    canvas.drawCircle(Offset.zero, 2.3 + _start_time * 2.7, paint);
    paint.color = _blue1;
    canvas.drawCircle(Offset.zero, 2.0, paint);
    paint.color = white;
    canvas.drawCircle(Offset.zero, 1.3, paint);
  }

  @override
  void onCollision(Set<Vector2> intersectionPoints, PositionComponent other) {
    super.onCollision(intersectionPoints, other);
    if (recycled) return;
    if (other case Hostile it when it.susceptible) {
      it.on_hit(1);
      recycle();
    }
  }
}
