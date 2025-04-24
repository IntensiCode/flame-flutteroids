import 'dart:ui';

import 'package:flame/components.dart';
import 'package:flutter/animation.dart';
import 'package:flutteroids/core/common.dart';
import 'package:flutteroids/game/asteroids/asteroid.dart';
import 'package:flutteroids/game/common/extras.dart';
import 'package:flutteroids/game/common/game_context.dart';
import 'package:flutteroids/game/world/world.dart';
import 'package:flutteroids/util/mutable.dart';

extension GameContextExtensions on GameContext {
  PlayerRadar get player_radar => cache.putIfAbsent('hud', () => PlayerRadar());
}

class PlayerRadar extends PositionComponent with GameContext {
  static const extra_indicator_radius = 3.0;
  static const base_indicator_size = 12.0;
  static const indicator_distance = 0.0;
  static const max_fade_distance = 800.0;

  static final _fade_colors = List.generate(8, (i) {
    final alpha = (255 * (1.0 - i / 7.0)).round();
    return Color.fromARGB(alpha, 255, 255, 255);
  });

  static final _approach_colors = [
    Color(0xFFFFFF00), // yellow
    Color(0xFFFFE000), // yellow-orange
    Color(0xFFFFC000), // orange
    Color(0xFFFFA000), // orange
    Color(0xFFFF8000), // orange-red
    Color(0xFFFF6000), // red-orange
    Color(0xFFFF4000), // red
    Color(0xFFFF0000), // pure red
  ];

  final _offset = MutableOffset(0, 0);
  final _point1 = MutableOffset(0, 0);
  final _point2 = MutableOffset(0, 0);
  final _point3 = MutableOffset(0, 0);
  final _point4 = MutableOffset(0, 0);
  final _triangle_points = <Offset>[];
  final _paint = pixel_paint();
  final _path = Path();

  final _extra_paint = pixel_paint()
    ..color = const Color(0xFF0077FF)
    ..style = PaintingStyle.fill;

  final _pos = Vector2.zero();
  final _direction = Vector2.zero();
  final _perpendicular = Vector2.zero();
  final _to_player = Vector2.zero();

  late double world_half_width;
  late double world_half_height;

  @override
  Future<void> onLoad() async {
    super.onLoad();
    anchor = Anchor.center;
    _triangle_points.addAll([_point1, _point2, _point3, _point4]);
  }

  @override
  void onMount() {
    size.setAll(world.world_viewport_size);
    world_half_width = size.x / 2;
    world_half_height = size.y / 2;
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);

    canvas.translate(world_half_width, world_half_height);

    for (final child in world.children) {
      if (child is PositionComponent && _is_outside_world(child)) {
        if (child is Extra) {
          _draw_extra_indicator(canvas, child);
        } else if (child is Asteroid) {
          _draw_asteroid_indicator(canvas, child);
        }
      }
    }

    canvas.translate(-world_half_width, -world_half_height);
  }

  bool _is_outside_world(PositionComponent component) {
    return component.position.x.abs() > world_half_width || component.position.y.abs() > world_half_height;
  }

  void _draw_asteroid_indicator(Canvas canvas, Asteroid asteroid) {
    final screen_pos = asteroid.position;
    final distance = screen_pos.length;
    final fade_factor = (distance / max_fade_distance).clamp(0.0, 1.0);
    final curved_fade = Curves.easeInCubic.transform(fade_factor);
    final size_factor = 1.0 - (curved_fade * 0.6);
    final radius_factor = (asteroid.asteroid_radius / 60.0).clamp(0.5, 2.0);
    final indicator_size = base_indicator_size * size_factor * radius_factor;

    _to_player.setFrom(screen_pos);
    _to_player.add(asteroid.velocity);
    final is_approaching = _to_player.length < screen_pos.length;

    final color_index = (is_approaching ? (1 - fade_factor) * 12 : curved_fade * 7).round();
    final colors = is_approaching ? _approach_colors : _fade_colors;
    final color = colors[color_index.clamp(0, colors.length - 1)];

    _direction.setFrom(screen_pos);
    _direction.normalize();

    final velocity_direction = asteroid.velocity.normalized();
    final triangle_offset = _calculate_triangle_offset(_direction, velocity_direction, indicator_size);

    _update_boundary_position(_direction, triangle_offset);
    _update_triangle(velocity_direction, indicator_size);

    _paint.color = color;
    _path.reset();
    _path.addPolygon(_triangle_points, true);
    canvas.drawPath(_path, _paint);
  }

  void _update_boundary_position(Vector2 direction, Vector2 offset) {
    final abs_x = direction.x.abs();
    final abs_y = direction.y.abs();

    if (abs_x > abs_y) {
      final x = direction.x > 0 ? world_half_width - indicator_distance : -world_half_width + indicator_distance;
      final y = (direction.y / abs_x) * (world_half_width - indicator_distance);
      _pos.setValues(x + offset.x, y + offset.y);
    } else {
      final y = direction.y > 0 ? world_half_height - indicator_distance : -world_half_height + indicator_distance;
      final x = (direction.x / abs_y) * (world_half_height - indicator_distance);
      _pos.setValues(x + offset.x, y + offset.y);
    }
  }

  void _update_triangle(Vector2 direction, double size) {
    _perpendicular.setValues(-direction.y, direction.x);

    final tip_length = size * 1.2;
    final base_width = size * 0.5;
    final indent_depth = size * 0.3;

    final tip_x = _pos.x + direction.x * tip_length;
    final tip_y = _pos.y + direction.y * tip_length;

    final base1_x = _pos.x + _perpendicular.x * base_width;
    final base1_y = _pos.y + _perpendicular.y * base_width;

    final base2_x = _pos.x - _perpendicular.x * base_width;
    final base2_y = _pos.y - _perpendicular.y * base_width;

    final indent_x = _pos.x + direction.x * indent_depth;
    final indent_y = _pos.y + direction.y * indent_depth;

    _point1.dx = tip_x;
    _point1.dy = tip_y;
    _point2.dx = base1_x;
    _point2.dy = base1_y;
    _point3.dx = indent_x;
    _point3.dy = indent_y;
    _point4.dx = base2_x;
    _point4.dy = base2_y;
  }

  Vector2 _calculate_triangle_offset(Vector2 direction, Vector2 velocity_direction, double size) {
    final perpendicular = Vector2(-velocity_direction.y, velocity_direction.x);

    final tip_length = size * 1.2;
    final base_width = size * 0.5;
    final indent_depth = size * 0.3;

    final tip_offset = velocity_direction * tip_length;
    final base1_offset = perpendicular * base_width;
    final base2_offset = perpendicular * (-base_width);
    final indent_offset = velocity_direction * (indent_depth);

    final inward_direction = -direction;

    final tip_projection = tip_offset.dot(inward_direction);
    final base1_projection = base1_offset.dot(inward_direction);
    final base2_projection = base2_offset.dot(inward_direction);
    final indent_projection = indent_offset.dot(inward_direction);

    final max_outward_extent =
        -[tip_projection, base1_projection, base2_projection, indent_projection, 0.0].reduce((a, b) => a < b ? a : b);

    const buffer = 2.0;
    return inward_direction * (max_outward_extent + buffer);
  }

  void _draw_extra_indicator(Canvas canvas, Extra extra) {
    // extra.position is the camera-compensated position, relative to radar center due to canvas translation.
    _pos.setFrom(extra.position);

    _direction.setFrom(_pos);
    final distance = _direction.normalize();

    // final distance = _pos.length;
    // Don't draw if it's essentially at the center or too far for the radar's effective range.
    if (distance > max_fade_distance) return;
    // if (distance < 1.0 || distance > max_fade_distance) return;

    // Calculate the offset needed to pull the center of the circle inward
    // so that its edge touches the radar boundary.
    final inward_offset = _direction.clone()
      ..negate()
      ..scale(extra_indicator_radius);

    _update_boundary_position(_direction, inward_offset);
    // _pos is now the calculated center for the circle indicator on the boundary.

    _offset.setFrom(_pos);
    canvas.drawCircle(_offset, extra_indicator_radius, _extra_paint);
  }
}
