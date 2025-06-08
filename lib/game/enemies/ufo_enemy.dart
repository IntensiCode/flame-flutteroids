import 'dart:math';
import 'dart:ui';

import 'package:flame/collisions.dart';
import 'package:flame/components.dart';
import 'package:flutteroids/core/common.dart';
import 'package:flutteroids/game/common/kinds.dart';
import 'package:flutteroids/game/common/voxel_entity.dart';
import 'package:flutteroids/game/enemies/enemy_base.dart';
import 'package:flutteroids/game/enemies/enemy_weapon.dart';
import 'package:flutteroids/game/player/player.dart';
import 'package:flutteroids/game/world/world.dart';
import 'package:flutteroids/util/log.dart';
import 'package:flutteroids/util/random.dart';

class UfoEnemy extends EnemyBase {
  static const _target_acquisition_range = 100.0;
  static const _target_tracking_range = 150.0;
  static const _rapid_fire_range = 50.0;

  late final weapon = EnemyWeapon(this);

  Target? _current_target;

  @override
  Future on_load_once() async {
    voxel = VoxelEntity(
      voxel_image: await images.load('voxel/tanker50.png'),
      height_frames: 50,
      exhaust_color: Color(0xFF00ff37),
      parent_size: size,
    );
    voxel.model_scale.setValues(0.8, 0.8, 0.8);
    voxel.exhaust_length = 2;

    await add(weapon);
    await add(voxel..priority = 10);
    await add(health_bar..priority = 20);

    await add(CircleHitbox(
      radius: size.x * 0.35,
      collisionType: CollisionType.passive,
    )
      ..position.setAll(size.x * 0.15)
      ..x += 4);

    voxel.set_exhaust_gradient(0, const Color(0xFF80ffff));
    voxel.set_exhaust_gradient(1, const Color(0xF000ffff));
    voxel.set_exhaust_gradient(2, const Color(0xE00080ff));
    voxel.set_exhaust_gradient(3, const Color(0xD00000ff));
    voxel.set_exhaust_gradient(4, const Color(0xC0000080));

    rot_x = -pi / 2;
  }

  @override
  void on_pick_start_position() {
    log_debug('$runtimeType picking start position');
    world_pos.x = -world.world_viewport_size * 0.7;
    world_pos.y = level_rng.nextDoublePM(world.world_viewport_size * 0.4);
    position.setFrom(world_pos);
    velocity.setZero();
    log_debug('$runtimeType start position: $world_pos');
  }

  @override
  void on_playing(double dt) {
    // Move the UFO from left to right
    if (_current_target == player) {
      rot_z += dt;
      velocity.x = max(25, velocity.x - 50 * dt);
      weapon.fire_rate = 0.5; // Faster fire rate when targeting player
    } else {
      velocity.x = min(50, velocity.x + 50 * dt);
      weapon.fire_rate = 1.0;
    }

    // If we are close enough to the target, increase fire rate
    if (_current_target?.within_distance(this, _rapid_fire_range / 2) == true) {
      weapon.fire_rate = 0.1; // Rapid fire rate
    } else if (_current_target?.within_distance(this, _rapid_fire_range) == true) {
      weapon.fire_rate = 0.2; // Rapid fire rate
    }

    if (weapon.can_fire) _find_target();
  }

  void _find_target() {
    // If we have a current target, check if it's still valid and in range
    final it = _current_target;
    if (it != null) {
      // Check if target is still valid (not removed and still in tracking range)
      if (it.isRemoved || it.isRemoving) {
        _current_target = null;
      } else if (world_pos.distanceToSquared(it.world_pos) > _target_tracking_range * _target_tracking_range) {
        // Target is no longer valid, clear it
        _current_target = null;
      } else {
        // Target is still valid, fire at it
        weapon.fire_at_target(it);
        return;
      }
    }

    // No current target or target lost, find a new one
    Target? closest_target;
    double closest_distance_squared = _target_acquisition_range * _target_acquisition_range;

    for (final child in world.children) {
      if (child == this) continue;
      if (child is Enemy) continue;
      if (child is! Target) continue;

      // log_debug('UFO Enemy found child: $child');

      final distance_squared = world_pos.distanceToSquared(child.world_pos);
      if (distance_squared < closest_distance_squared) {
        closest_target = child;
        closest_distance_squared = distance_squared;
      }
    }

    if (closest_target != null) {
      _current_target = closest_target;
    }
  }
}
