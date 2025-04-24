import 'dart:math';

import 'package:flame/components.dart';
import 'package:flutteroids/game/common/kinds.dart';
import 'package:flutteroids/game/world/world_entity.dart';

mixin DirectionalProjectile on PositionComponent, WorldEntity {
  double get base_speed => 500;

  void reset(Player origin, double angle) {
    set_direction_angle(angle);
    velocity.add(origin.velocity);
    world_pos.setZero();
  }

  void change_direction(double relative_angle) {
    velocity.rotate(relative_angle);
  }

  void set_direction_angle(double angle) {
    velocity.x = cos(angle) * base_speed;
    velocity.y = sin(angle) * base_speed;
    // velocity.setValues(1, 0);
    // velocity.rotate(angle);
    // velocity.scale(base_speed);
  }
}
