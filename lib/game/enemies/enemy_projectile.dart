import 'dart:math';
import 'dart:ui';

import 'package:flame/collisions.dart';
import 'package:flame/components.dart';
import 'package:flutteroids/core/common.dart';
import 'package:flutteroids/game/common/kinds.dart';
import 'package:flutteroids/game/projectiles/directional_projectile.dart';
import 'package:flutteroids/game/world/world_entity.dart';
import 'package:flutteroids/util/component_recycler.dart';

class EnemyProjectile extends PositionComponent
    with CollisionCallbacks, Recyclable, WorldEntity, DirectionalProjectile {
  //

  static const _green1 = Color(0xF080ff80); // Light green (inside)
  static const _green2 = Color(0xA0006000); // Dark green (outside)

  static final _paint = pixel_paint();

  EnemyProjectile() {
    size.setAll(2.7);
    add(CircleHitbox(radius: 2.7, anchor: Anchor.center, isSolid: true));
  }

  double _start_time = 1;

  @override
  double get base_speed => 350;

  // Reset from hostile entity instead of player
  void reset_from_hostile(Target origin, double angle) {
    super.reset(origin, angle);
    _start_time = 1;
    max_distance = DirectionalProjectile.world_size();
  }

  @override
  void update(double dt) {
    super.update(dt);
    if (_start_time > 0) _start_time = max(0, _start_time - dt);
  }

  @override
  void render(Canvas canvas) {
    _paint.color = _green2;
    canvas.drawCircle(Offset.zero, 2.3 + _start_time * 2.7, _paint);
    _paint.color = _green1;
    canvas.drawCircle(Offset.zero, 2.0, _paint);
    _paint.color = white;
    canvas.drawCircle(Offset.zero, 1.3, _paint);
  }

  @override
  void onCollision(Set<Vector2> intersectionPoints, PositionComponent other) {
    super.onCollision(intersectionPoints, other);
    if (recycled) return;
    if (other is Enemy || other is EnemyProjectile) return;
    if (other case Target it when it.susceptible) {
      final hit_point = it.calculate_hit_point(it, intersectionPoints);
      it.on_hit(10, hit_point);
      recycle();
    }
  }
}
