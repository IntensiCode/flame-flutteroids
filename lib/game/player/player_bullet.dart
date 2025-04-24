import 'dart:math';
import 'dart:ui';

import 'package:flame/collisions.dart';
import 'package:flame/components.dart';
import 'package:flutteroids/core/common.dart';
import 'package:flutteroids/game/common/game_context.dart';
import 'package:flutteroids/game/common/kinds.dart';
import 'package:flutteroids/game/world/world_entity.dart';
import 'package:flutteroids/util/component_recycler.dart';
import 'package:flutteroids/util/log.dart';

class PlayerBullet extends PositionComponent
    with GameContext, HasVisibility, CollisionCallbacks, OnHit, Friendly, Recyclable, WorldEntity {
  //

  static const double bullet_speed = 400.0;
  static const double bullet_radius = 3.0;
  static const double bullet_damage = 1.0;

  static const _outer_color = Color(0x80004488); // dark blue 50% alpha
  static const _middle_color = Color(0xFF004488); // dark blue full alpha
  static const _inner_color = Color(0xFFffffff); // white full alpha

  static const _outer_radius = bullet_radius + 4.0; // 7.0
  static const _middle_radius = bullet_radius + 2.0; // 5.0
  static const _inner_radius = bullet_radius; // 3.0

  final _paint = pixel_paint();

  void fire_from(Vector2 origin, double angle) {
    max_hit_points = remaining_hit_points = 1.0;

    world_pos.setZero();

    velocity.setValues(
      cos(angle) * bullet_speed,
      sin(angle) * bullet_speed,
    );

    isVisible = true;
  }

  @override
  Future<void> onLoad() async {
    super.onLoad();

    recycle = () => isVisible = false;

    log_info('PlayerBullet loaded');

    size.setAll(_outer_radius * 2);
    anchor = Anchor.center;
    max_hit_points = remaining_hit_points = 1.0;
    isVisible = false;

    final hb_off = _outer_radius - _middle_radius;
    add(CircleHitbox(radius: _middle_radius, isSolid: true)..position.setAll(hb_off));

    priority = -10;
  }

  final _center = Offset(_outer_radius, _outer_radius);

  @override
  void render(Canvas canvas) {
    if (!isVisible) return;

    _paint.color = _outer_color;
    canvas.drawCircle(_center, _outer_radius, _paint);

    _paint.color = _middle_color;
    canvas.drawCircle(_center, _middle_radius, _paint);

    _paint.color = _inner_color;
    canvas.drawCircle(_center, _inner_radius, _paint);
  }

  @override
  void update(double dt) {
    if (isVisible) super.update(dt);
  }

  @override
  void onCollision(Set<Vector2> intersectionPoints, PositionComponent other) {
    super.onCollision(intersectionPoints, other);

    if (!isVisible) return;

    if (other case OnHit target when target is Hostile && target.susceptible) {
      log_info('hit ${other.runtimeType}');
      target.on_hit(bullet_damage);
      on_hit(max_hit_points);
    }
  }

  @override
  bool get susceptible => true;

  @override
  void on_hit(double damage) {
    super.on_hit(damage);
    if (is_destroyed) recycle();
  }
}
