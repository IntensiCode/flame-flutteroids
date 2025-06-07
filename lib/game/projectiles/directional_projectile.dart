import 'dart:math';

import 'package:flame/components.dart';
import 'package:flutteroids/game/common/kinds.dart';
import 'package:flutteroids/game/world/world_entity.dart';

mixin DirectionalProjectile on PositionComponent, WorldEntity {
  static late double Function() world_size;

  double _travelled_distance = 0;

  late double max_distance;

  double get base_speed => 500;

  void reset(Player origin, double angle) {
    set_direction_angle(angle);
    velocity.add(origin.velocity);
    world_pos.setZero();
    _travelled_distance = 0;
  }

  void change_direction(double relative_angle) {
    velocity.rotate(relative_angle);
  }

  void set_direction_angle(double angle) {
    velocity.x = cos(angle) * base_speed;
    velocity.y = sin(angle) * base_speed;
  }

  @override
  void update(double dt) {
    super.update(dt);

    final distance_this_frame = velocity.length * dt;
    _travelled_distance += distance_this_frame;
    if (_travelled_distance >= max_distance) recycle();
  }
}
