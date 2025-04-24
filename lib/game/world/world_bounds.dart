import 'package:flame/components.dart';

const double cull_distance = 800;
const double cull_distance_squared = cull_distance * cull_distance;

const double min_spawn_distance = 400;
const double max_spawn_distance = 600;

const double active_buffer = 100;

const double active_dist = min_spawn_distance + active_buffer;
const double active_dist_squared = active_dist * active_dist;

bool is_in_active_area(Vector2 world_pos) {
  return world_pos.x.abs() <= active_dist && world_pos.y.abs() <= active_dist;
}
