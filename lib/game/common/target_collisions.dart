import 'package:flame/collisions.dart';
import 'package:flame/components.dart';
import 'package:flutteroids/game/common/kinds.dart';
import 'package:flutteroids/util/component_recycler.dart';
import 'package:flutteroids/util/log.dart';

mixin TargetCollisions on Component, CollisionCallbacks, Recyclable, Target {
  final _collision_normal = Vector2.zero();
  final _relative_velocity = Vector2.zero();
  final _temp = Vector2.zero();

  @override
  void onCollisionStart(Set<Vector2> intersectionPoints, PositionComponent other) {
    super.onCollisionStart(intersectionPoints, other);

    if (recycled) return;

    if (other case Target it) {
      // Let the bigger one handle the collision
      if (this.fake_mass < it.fake_mass) return;

      _apply_collision_damage(it, intersectionPoints);
      _elastic_collision_with(it);
    }
  }

  void _apply_collision_damage(Target other, Set<Vector2> intersectionPoints) {
    final mass1 = fake_mass * fake_mass;
    final mass2 = other.fake_mass * other.fake_mass;
    final total_mass = mass1 + mass2;

    final mass_ratio_1 = mass2 / total_mass;
    final mass_ratio_2 = mass1 / total_mass;

    final max_damage = 1.2;
    final damage_1 = (mass_ratio_1 * max_damage).clamp(0.1, max_damage);
    final damage_2 = (mass_ratio_2 * max_damage).clamp(0.1, max_damage);

    log_debug('Asteroid collision with ${other.runtimeType}');
    log_debug('Asteroid ($fake_mass) hit other (${other.fake_mass})');
    log_debug('Asteroid damage: $damage_1 Other damage: $damage_2');
    log_debug('Asteroid max-hp: $max_hit_points Other max-hp: ${other.max_hit_points}');

    final hit_point = calculate_hit_point(other, intersectionPoints);
    on_hit(damage_1 * max_hit_points, hit_point);
    other.on_hit(damage_2 * other.max_hit_points, hit_point);
  }

  void _elastic_collision_with(Target other) {
    final mass1 = fake_mass * fake_mass;
    final mass2 = other.fake_mass * other.fake_mass;
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
    _temp.scale(elastic_factor);
    velocity.add(_temp);

    _temp.setFrom(_collision_normal);
    _temp.scale(1 / mass2);
    _temp.scale(other.elastic_factor);

    other.velocity.sub(_temp);
  }
}
