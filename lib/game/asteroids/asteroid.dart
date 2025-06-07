import 'dart:math';

import 'package:flame/collisions.dart';
import 'package:flame/components.dart';
import 'package:flutteroids/core/common.dart';
import 'package:flutteroids/game/asteroids/asteroid_collision.dart';
import 'package:flutteroids/game/asteroids/asteroid_rendering.dart';
import 'package:flutteroids/game/asteroids/asteroid_splitting.dart';
import 'package:flutteroids/game/common/decals.dart';
import 'package:flutteroids/game/common/game_context.dart';
import 'package:flutteroids/game/common/kinds.dart';
import 'package:flutteroids/game/common/messages.dart';
import 'package:flutteroids/game/common/sound.dart';
import 'package:flutteroids/game/world/world_bounds.dart';
import 'package:flutteroids/game/world/world_entity.dart';
import 'package:flutteroids/util/component_recycler.dart';
import 'package:flutteroids/util/random.dart';

class Asteroid extends PositionComponent
    with
        GameContext,
        CollisionCallbacks,
        OnHit,
        Hostile,
        Recyclable,
        WorldEntity,
        AsteroidSplitting,
        AsteroidCollision,
        AsteroidRendering {
  //

  double rotation_speed = 0.0;

  final _hitbox = CircleHitbox(radius: 0, isSolid: true);

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
  void on_hit(double damage) {
    super.on_hit(damage);

    if (is_destroyed) {
      split_into_two();
      spawn_dust(asteroid_radius.toInt() ~/ 10);
      play_sound(Sound.clash, volume_factor: asteroid_radius / 50);
    } else {
      asteroid_hash += 0.03;
      decals.spawn(DecalKind.dust, this, pos_range: asteroid_radius / 3, vel_range: 10);
      // play_sound(Sound.clash, volume_factor: asteroid_radius / 100);
    }
  }

  @override
  void spawn_dust(int count) {
    for (int i = 0; i < count; i++) {
      decals.spawn(DecalKind.dust, this, pos_range: asteroid_radius / 3, vel_range: 10);
    }
  }
}
