import 'dart:ui';

import 'package:flame/components.dart';
import 'package:flutteroids/core/common.dart';
import 'package:flutteroids/game/common/extra_id.dart';
import 'package:flutteroids/game/common/game_context.dart';
import 'package:flutteroids/game/world/world.dart';
import 'package:flutteroids/game/world/world_camera.dart';
import 'package:flutteroids/input/game_keys.dart';
import 'package:flutteroids/util/log.dart';

mixin Enemy on Hostile {}

mixin Friendly on Target {}

mixin Hostile on Target {}

mixin Player on Target {
  /// Can fire only when this is true.
  bool get weapons_hot;

  void on_collect_extra(ExtraId which);
}

mixin PrimaryWeapon on Component {
  static const int max_boosts = 10;

  int boost = 0;

  String get display_name;

  Sprite get icon;

  // Heat (0.0 to 1.0), or -1.0 if weapon can not overheat.
  double get heat;

  void on_boost() => boost = (boost + 1).clamp(0, max_boosts);
}

mixin SecondaryWeapon on GameContext {
  static const int max_boosts = 10;

  int boost = 0;

  var button = GameKey.b_button;

  String get display_name;

  Sprite get icon;

  double cooldown = 0;
  double cooldown_time = 3;
  double _activation_guard = 0.0;

  Player get player;

  late Function(SecondaryWeapon) on_fired;

  void on_boost() {
    boost = (boost + 1).clamp(0, max_boosts);
  }

  void set_activation_guard() => _activation_guard = 0.2;

  @override
  void update(double dt) {
    if (keys.held[button] == false && _activation_guard > 0) {
      _activation_guard = 0;
    }
    if (_activation_guard > 0) {
      _activation_guard -= dt;
      return;
    }

    if (cooldown > 0) return;
    if (keys.held[button] != true) return;
    if (player.weapons_hot == false) return;
    do_fire();
    on_fired(this);
  }

  void do_fire();
}

mixin Target on GameContext, PositionComponent {
  static const hit_color = Color(0xFFffffff);

  // Reusable vector for collision calculations
  final Vector2 temp_vector = Vector2.zero();

  Vector2 get world_pos;

  Vector2 get velocity;

  Vector2 get world_size;

  double get fake_mass => world_size.x / 2;

  double get elastic_factor => 0.3;

  double hit_time = 0;

  late double max_hit_points;
  late double remaining_hit_points;

  bool get is_destroyed => remaining_hit_points <= 0 || isRemoved;

  /// True if this component can currently be hit by hostile entities.
  ///
  /// May be false if (temporarily) invulnerable. For example due to teleporting or such.
  bool get susceptible;

  /// Integrity (0.0 to 1.0), or -1.0 if indestructible.
  double get integrity => remaining_hit_points / max_hit_points;

  bool within_distance(Target other, double distance) =>
      world_pos.distanceToSquared(other.world_pos) <= distance * distance;

  void on_hit(double damage, Vector2 hit_point) {
    if (is_destroyed) return;
    hit_time = 0.05;
    if (dev) log_verbose('Hit: $runtimeType, damage: $damage, remaining: $remaining_hit_points');
    remaining_hit_points -= damage;
    if (remaining_hit_points < 0) remaining_hit_points = 0;
    spawn_damage_decals(damage, hit_point);
  }

  void spawn_damage_decals(double damage, Vector2 hit_point);

  @override
  void update(double dt) {
    super.update(dt);
    hit_time = (hit_time - dt).clamp(0, 1);
  }
}

extension TargetExtensions on Target {
  /// Calculate a hit point from intersection points
  Vector2 calculate_hit_point(Target other, Set<Vector2> intersections) {
    if (intersections.isEmpty) {
      // If no intersection points, use the midpoint between the two targets
      temp_vector.setFrom(world_pos);
      temp_vector.add(other.world_pos);
      temp_vector.scale(0.5);
      return temp_vector;
    }

    // Calculate center of intersection points
    temp_vector.setZero();
    for (final point in intersections) {
      temp_vector.add(point);
    }
    temp_vector.scale(1 / intersections.length);

    // TODO Camere must set this offset somewhere in shared
    temp_vector.sub(world.position);
    temp_vector.sub(camera.camera_offset);

    return temp_vector;
  }
}
