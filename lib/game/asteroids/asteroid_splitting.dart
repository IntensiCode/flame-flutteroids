import 'dart:math';

import 'package:flame/components.dart';
import 'package:flutteroids/core/common.dart';
import 'package:flutteroids/game/world/world_entity.dart';

const double min_split_radius = 20.0;
const double min_split_ratio = 0.3;
const double split_ratio_range = 0.2;
const double split_distance_factor = 0.5;
const double split_velocity = 30.0;

typedef SpawnFunc = dynamic Function(Vector2 world_position, double asteroid_radius, Vector2? direction);

mixin AsteroidSplitting on Component, WorldEntity {
  double asteroid_radius = 40.0;
  int split_count = 0;

  bool get is_split => split_count > 0;

  final _split_dir_1 = Vector2.zero();
  final _split_dir_2 = Vector2.zero();
  final _split_pos_1 = Vector2.zero();
  final _split_pos_2 = Vector2.zero();
  final _split_vel_1 = Vector2.zero();
  final _split_vel_2 = Vector2.zero();

  late SpawnFunc spawn;

  void do_split() {
    final child_split_count = split_count + 1;

    final split_ratio_1 = min_split_ratio + level_rng.nextDouble() * split_ratio_range;
    final split_ratio_2 = min_split_ratio + level_rng.nextDouble() * split_ratio_range;

    final radius_1 = asteroid_radius * split_ratio_1;
    final radius_2 = asteroid_radius * split_ratio_2;

    final split_angle = level_rng.nextDouble() * 2 * pi;
    final split_distance = asteroid_radius * split_distance_factor;

    _split_dir_1.setValues(cos(split_angle), sin(split_angle));
    _split_dir_2.setValues(cos(split_angle + pi), sin(split_angle + pi));
    _calc_split_pos(world_pos, _split_dir_1, split_distance, _split_pos_1);
    _calc_split_pos(world_pos, _split_dir_2, split_distance, _split_pos_2);
    _calc_split_velocity(_split_dir_1, split_velocity, _split_vel_1);
    _calc_split_velocity(_split_dir_2, split_velocity, _split_vel_2);

    final child1 = spawn(_split_pos_1, radius_1, _split_dir_1);
    final child2 = spawn(_split_pos_2, radius_2, _split_dir_2);
    if (child1 != null) child1.split_count = child_split_count;
    if (child2 != null) child2.split_count = child_split_count;
  }

  void _calc_split_pos(Vector2 pos, Vector2 dir, double distance, Vector2 out) {
    out.setFrom(dir);
    out.scale(distance);
    out.add(pos);
  }

  void _calc_split_velocity(Vector2 dir, double speed, Vector2 out) {
    out.setFrom(dir);
    out.scale(speed);
  }
}
