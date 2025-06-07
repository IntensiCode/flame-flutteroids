import 'package:flame/collisions.dart';
import 'package:flame/components.dart';
import 'package:flutteroids/game/asteroids/asteroid_splitting.dart' show AsteroidSplitting;
import 'package:flutteroids/game/common/kinds.dart';
import 'package:flutteroids/game/common/sound.dart';
import 'package:flutteroids/game/world/world_entity.dart';

mixin AsteroidCollision on Component, WorldEntity, CollisionCallbacks, AsteroidSplitting, OnHit {
  final _collision_normal = Vector2.zero();
  final _relative_velocity = Vector2.zero();
  final _temp = Vector2.zero();

  void spawn_dust(int count);

  @override
  void onCollisionStart(Set<Vector2> intersectionPoints, PositionComponent other) {
    super.onCollisionStart(intersectionPoints, other);

    if (other case AsteroidSplitting it) {
      final combined = asteroid_radius + it.asteroid_radius;
      spawn_dust(combined.toInt() ~/ 20);

      if (it.asteroid_radius >= 20) {
        play_sound(Sound.clash, volume_factor: it.asteroid_radius / 100);
      }

      _apply_collision_damage(it);
      _elastic_collision_with(it);
    }
  }

  @override
  void onCollision(Set<Vector2> intersectionPoints, PositionComponent other) {
    super.onCollision(intersectionPoints, other);

    if (other is WorldEntity) return;

    if (other case OnHit target when target.susceptible) {
      target.on_hit(asteroid_radius);
      on_hit(max_hit_points / 2);
    }
  }

  void _apply_collision_damage(dynamic other) {
    final mass1 = asteroid_radius * asteroid_radius;
    final mass2 = other.asteroid_radius * other.asteroid_radius;
    final total_mass = mass1 + mass2;

    final mass_ratio_1 = mass2 / total_mass;
    final mass_ratio_2 = mass1 / total_mass;

    final max_damage = 1.0;
    final damage_1 = (mass_ratio_1 * max_damage).clamp(0.1, max_damage);
    final damage_2 = (mass_ratio_2 * max_damage).clamp(0.1, max_damage);

    on_hit(damage_1);
    other.on_hit(damage_2);
  }

  void _elastic_collision_with(dynamic other) {
    final mass1 = asteroid_radius * asteroid_radius;
    final mass2 = other.asteroid_radius * other.asteroid_radius;
    final total_mass = mass1 + mass2;

    _collision_normal.setFrom(world_pos);
    _collision_normal.sub(other.world_pos);
    _collision_normal.normalize();

    _relative_velocity.setFrom(velocity);
    _relative_velocity.sub(other.velocity);

    final velocity_along_normal = _relative_velocity.dot(_collision_normal);
    if (velocity_along_normal > 0) return;

    final restitution = 0.8;
    final impulse_scalar = -(1 + restitution) * velocity_along_normal / total_mass * (mass1 * mass2);
    _collision_normal.scale(impulse_scalar);

    _temp.setFrom(_collision_normal);
    _temp.scale(1 / mass1);
    velocity.add(_temp);

    _temp.setFrom(_collision_normal);
    _temp.scale(1 / mass2);
    other.velocity.sub(_temp);
  }
}
