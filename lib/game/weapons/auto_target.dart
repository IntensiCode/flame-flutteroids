import 'dart:math';

import 'package:flame/components.dart';
import 'package:flutteroids/game/common/game_context.dart';
import 'package:flutteroids/game/common/kinds.dart';
import 'package:flutteroids/game/world/world.dart';

mixin AutoTarget on GameContext {
  final Vector2 _target_dir = Vector2.zero();

  (Hostile?, double?) auto_target_angle(
    Vector2 origin,
    double angle, {
    double max_spread = pi / 32,
    double? max_range,
  }) {
    final enemies = world.hostiles;
    if (enemies.isEmpty) return (null, null);

    max_range ??= world.world_viewport_size * 2;

    Hostile? closest;
    double closest_distance = max_range * max_range;

    for (final enemy in enemies) {
      _target_dir.setFrom(enemy.position);
      _target_dir.sub(origin);

      final distance_sq = _target_dir.length2;
      if (distance_sq > closest_distance) continue;

      final angle_to_enemy = _target_dir.screenAngle() - (pi / 2);
      final angular_difference = atan2(sin(angle_to_enemy - angle), cos(angle_to_enemy - angle));

      if (angular_difference.abs() <= max_spread) {
        closest_distance = distance_sq;
        closest = enemy;
      }
    }

    if (closest != null) {
      _target_dir.setFrom(closest.position);
      _target_dir.sub(origin);
      return (closest, _target_dir.screenAngle() - (pi / 2));
    }

    return (null, null);
  }
}
