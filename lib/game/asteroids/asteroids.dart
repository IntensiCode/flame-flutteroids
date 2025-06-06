import 'dart:math';

import 'package:flame/components.dart';
import 'package:flutteroids/core/common.dart';
import 'package:flutteroids/game/asteroids/asteroid.dart';
import 'package:flutteroids/game/common/game_context.dart';
import 'package:flutteroids/game/common/game_phase.dart';
import 'package:flutteroids/game/common/level.dart';
import 'package:flutteroids/game/world/world_bounds.dart';
import 'package:flutteroids/util/component_recycler.dart';
import 'package:flutteroids/util/log.dart';
import 'package:flutteroids/util/random.dart';

extension GameContextExtensions on GameContext {
  Asteroids get asteroids => cache.putIfAbsent('asteroids', () => Asteroids());
}

class Asteroids extends Component with GameContext {
  static const int max_spawn_attempts = 20;
  static const double min_spawn_separation = 100.0;
  static const double min_angle_spacing = pi / 2;

  double _lastSpawnAngle = 0.0;

  late final _pool = ComponentRecycler(() => Asteroid(spawn), _deactivate)..precreate(32);
  late final _active = <Asteroid>[];

  final _direction = v2z();

  void _deactivate(Asteroid asteroid) {
    _active.remove(asteroid);
    _pool.recycle(asteroid);
  }

  Asteroid spawn(Vector2 world_position, double asteroid_radius, [Vector2? direction]) {
    final asteroid = _pool.acquire();
    asteroid.setup_for_spawn(asteroid_radius, world_position);

    if (direction != null) {
      _direction.setFrom(direction);
    } else {
      _direction.x = level_rng.nextDoublePM(50);
      _direction.y = level_rng.nextDoublePM(50);
      _direction.sub(world_position);
      _direction.normalize();
    }

    if (_direction.length2 <= 10) {
      final speed = 20.0 + level_rng.nextDouble() * 30.0;
      final speed_multiplier = level.asteroid_speed_multiplier;
      asteroid.velocity.setFrom(_direction);
      asteroid.velocity.scale(speed * speed_multiplier);
    }

    parent?.add(asteroid);
    _active.add(asteroid);

    return asteroid;
  }

  @override
  Future<void> onLoad() async {
    super.onLoad();
    _pool.precreate(32);
  }

  @override
  void update(double dt) {
    super.update(dt);
    switch (stage.phase) {
      case GamePhase.inactive:
      case GamePhase.level_info:
        return;
      case GamePhase.entering_level:
      case GamePhase.playing_level:
      case GamePhase.level_completed:
      case GamePhase.game_over:
        _maintain_asteroid_count();
    }
  }

  void _maintain_asteroid_count() {
    final total_count = _active.length;
    if (total_count >= level.max_total_asteroids) return;

    // Calculate current mass in counting area using simple r² (not π * r²)
    double current_mass = 0.0;

    for (final asteroid in _active) {
      current_mass += asteroid.asteroid_radius * asteroid.asteroid_radius;
    }

    // Only spawn if we're below the mass threshold
    final should_spawn = current_mass < level.max_asteroid_mass;

    if (should_spawn && total_count < level.max_total_asteroids) {
      // Calculate how much mass we're missing
      final mass_deficit = level.max_asteroid_mass - current_mass;
      final mass_ratio = mass_deficit / level.max_asteroid_mass;

      var cm = current_mass.toInt();
      var mm = level.max_asteroid_mass.toInt();
      var md = mass_deficit.toInt();
      log_verbose('Current: $cm, Target: $mm, Deficit: $md');

      _spawn_random_asteroid(mass_ratio);
    }
  }

  void _spawn_random_asteroid([double size_factor = 1.0]) {
    // Base radius range: 20-60, but adjust based on mass deficit
    final base_radius = 20.0 + level_rng.nextDouble() * 40.0;
    final radius = base_radius * (0.7 + size_factor * 0.6); // Scale between 70%-130% of base

    for (int attempt = 0; attempt < max_spawn_attempts; attempt++) {
      // Spawn in annular region between min and max distance
      final full_delta = max_spawn_distance - min_spawn_distance;
      final delta = _active.length < 5 ? full_delta * 0.25 : full_delta;
      final spawn_distance = min_spawn_distance + level_rng.nextDouble() * delta;

      // Calculate new angle ensuring minimum spacing from last spawn
      double angle = _lastSpawnAngle + min_angle_spacing + level_rng.nextDouble() * (2 * pi - min_angle_spacing * 2);
      angle %= (2 * pi); // Normalize to 0-2π range
      _lastSpawnAngle = angle;

      final x = cos(angle) * spawn_distance;
      final y = sin(angle) * spawn_distance;
      final world_pos = Vector2(x, y);

      if (_is_position_clear(world_pos, radius)) {
        final direction = Vector2(-x, -y);
        direction.x += level_rng.nextDoublePM(0.1);
        direction.y += level_rng.nextDoublePM(0.1);
        direction.normalize();
        spawn(world_pos, radius, direction);
        return;
      }
    }

    log_info('Failed to find clear spawn position after $max_spawn_attempts attempts');
  }

  bool _is_position_clear(Vector2 pos, double radius) {
    for (final asteroid in _active) {
      final distance = (pos - asteroid.world_pos).length;
      final min_distance = min_spawn_separation + radius + asteroid.asteroid_radius;
      if (distance < min_distance) return false;
    }
    return true;
  }
}
