import 'dart:math';

import 'package:flame/collisions.dart';
import 'package:flame/components.dart';
import 'package:flutteroids/core/common.dart';
import 'package:flutteroids/game/asteroids/asteroid_rendering.dart';
import 'package:flutteroids/game/asteroids/asteroid_splitting.dart';
import 'package:flutteroids/game/common/decals.dart';
import 'package:flutteroids/game/common/game_context.dart';
import 'package:flutteroids/game/common/kinds.dart';
import 'package:flutteroids/game/common/messages.dart';
import 'package:flutteroids/game/common/sound.dart';
import 'package:flutteroids/game/common/target_collisions.dart';
import 'package:flutteroids/game/world/world_bounds.dart';
import 'package:flutteroids/game/world/world_entity.dart';
import 'package:flutteroids/util/component_recycler.dart';
import 'package:flutteroids/util/random.dart';

class Asteroid extends PositionComponent
    with
        GameContext,
        CollisionCallbacks,
        Target,
        Hostile,
        Recyclable,
        WorldEntity,
        AsteroidSplitting,
        TargetCollisions,
        AsteroidRendering {
  //

  double rotation_speed = 0.0;

  final _hitbox = CircleHitbox(radius: 0, isSolid: true);

  @override
  double get fake_mass => asteroid_radius * asteroid_radius * 0.5;

  @override
  double get elastic_factor => 1.0;

  @override
  Vector2 get world_size => size;

  @override
  bool get susceptible => is_in_active_area(world_pos);

  Asteroid(SpawnFunc spawn) {
    super.anchor = Anchor.center;
    this.spawn = spawn;
    add(_hitbox);
  }

  void split_into_two() {
    if (asteroid_radius < min_split_radius) {
      // log_debug('Asteroid destroyed (final split count: $split_count)');
      send_message(AsteroidDestroyed(this));
      recycle();
    } else {
      do_split();
      // log_debug('Asteroid split (split count: $split_count)');
      send_message(AsteroidSplit(this));
      recycle();
    }
  }

  void setup_for_spawn(double new_radius, Vector2 world_position) {
    size.setAll(new_radius);
    world_pos.setFrom(world_position);
    position.setFrom(world_position);
    asteroid_radius = new_radius;
    asteroid_hash = level_rng.nextDoubleLimit(800);
    rotation_speed = (level_rng.nextDouble() - 0.5) * 2.0;
    max_hit_points = remaining_hit_points = asteroid_radius / 20.0;
    _hitbox.radius = asteroid_radius / 2 * 0.75;
    _hitbox.position.setAll(asteroid_radius / 2 * 0.25);

    shader_rot_pos.setValues(
      level_rng.nextDoubleLimit(pi * 2.0),
      level_rng.nextDoubleLimit(pi * 2.0),
    );
    shader_rot_speed.randomizedNormal();
  }

  @override
  void on_hit(double damage, Vector2 hit_point) {
    super.on_hit(damage, hit_point);

    if (is_destroyed) {
      split_into_two();
      play_sound(Sound.clash, volume_factor: (asteroid_radius / 50).clamp(0.1, 1.0));
    } else {
      asteroid_hash += 0.03;
      play_sound(Sound.clash, volume_factor: (asteroid_radius / 150).clamp(0.1, 1.0));
    }
  }

  @override
  void spawn_damage_decals(double damage, Vector2 hit_point) {
    // log_debug(
    //   'Asteroid spawn_collision_decals: $damage\n'
    //   'Asteroid wp: $world_pos HP: $hit_point AP: $position\n',
    // );
    final count = (damage / 5).clamp(2, 10).toInt();
    for (int i = 0; i < count; i++) {
      decals.spawn(
        DecalKind.dust,
        this,
        pos_override: hit_point,
        pos_range: asteroid_radius / 3,
        vel_range: 4,
      );
    }
  }
}
