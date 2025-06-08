import 'dart:math';

import 'package:flame/collisions.dart';
import 'package:flame/components.dart';
import 'package:flame/sprite.dart';
import 'package:flutteroids/core/atlas.dart';
import 'package:flutteroids/game/common/decals.dart';
import 'package:flutteroids/game/common/game_context.dart';
import 'package:flutteroids/game/common/kinds.dart';
import 'package:flutteroids/game/projectiles/directional_projectile.dart';
import 'package:flutteroids/game/weapons/auto_target.dart';
import 'package:flutteroids/game/world/world_entity.dart';
import 'package:flutteroids/util/component_recycler.dart';

enum _NukeState { scanning, turning, boosting }

class NukeMissile extends SpriteComponent
    with GameContext, CollisionCallbacks, Recyclable, WorldEntity, DirectionalProjectile, HasVisibility, AutoTarget {
  //

  late final Decals decals;
  late final Function(WorldEntity, int) _emit_nuke;
  late final SpriteSheet _sprites;

  static const double delay_before_turn = 0.5; // seconds
  static const double turn_duration = 0.2; // seconds
  static const double boosted_speed_target = 500.0;
  static const double boost_acceleration = 2000.0; // units/s^2

  var _time_since_launch = 0.0;
  var _state = _NukeState.scanning;
  var _initial_turn_angle = 0.0; // World angle of missile when turn starts
  var _turn_progress = 0.0;

  double? _world_target_angle; // The actual world angle to aim for
  double _speed = 100;
  double _anim_time = 0;
  double _smoke_time = 0;
  int _boost = 0;

  NukeMissile(this.decals, this._emit_nuke) {
    anchor = Anchor.center;
    size.setAll(30);
    _sprites = atlas.sheetI('missile.png', 4, 1);
    sprite = _sprites.getSprite(0, 0);
    add(CircleHitbox(radius: 15, isSolid: true));
    priority = 100;
  }

  @override
  double get base_speed => _speed;

  @override
  void reset(Target origin, double angle, [int boost = 0]) {
    _speed = 100;
    _boost = boost;
    super.reset(origin, angle);

    // sprite faces up, player faces right, so +pi/2 from player angle:
    this.angle = (angle % (2 * pi)) + pi / 2;

    _world_target_angle = null; // Will be acquired after initial flight
    _time_since_launch = 0.0;
    _state = _NukeState.scanning; // Set initial state to scanning
    _initial_turn_angle = 0.0;
    _turn_progress = 0.0;
    max_distance = DirectionalProjectile.world_size() * 2;
  }

  @override
  void update(double dt) {
    super.update(dt);

    _time_since_launch += dt;

    // State machine for flight behavior
    switch (_state) {
      case _NukeState.scanning:
        _speed += 50 * dt + pow(_speed, 0.9) * dt; // Standard acceleration
        if (_time_since_launch >= delay_before_turn) {
          // Attempt to acquire a target on each frame after the delay
          final current_flight_direction = this.angle - pi / 2;
          final (_, target) = auto_target_angle(
            this.position,
            current_flight_direction,
            max_spread: pi / 3,
            max_range: 800,
          );
          _world_target_angle = target;

          if (_world_target_angle != null) {
            // Target acquired, transition to turning state
            _state = _NukeState.turning;
            _initial_turn_angle = current_flight_direction;
            _turn_progress = 0.0;
          }
          // If no target is found, it remains in the scanning state and continues to accelerate
        }
        break;

      case _NukeState.turning:
        _turn_progress += dt / turn_duration;
        double current_world_angle;

        if (_turn_progress >= 1.0) {
          _turn_progress = 1.0;
          current_world_angle = _world_target_angle!;
          _state = _NukeState.boosting;
        } else {
          // Interpolate the world angle
          final double shortest_angle_delta = atan2(
            sin(_world_target_angle! - _initial_turn_angle),
            cos(_world_target_angle! - _initial_turn_angle),
          );
          current_world_angle = _initial_turn_angle + shortest_angle_delta * _turn_progress;
        }
        set_direction_angle(current_world_angle); // This updates DirectionalProjectile's internal velocity vector
        this.angle = current_world_angle + pi / 2; // Update visual angle for sprite
        break;

      case _NukeState.boosting:
        final potential_new_speed = _speed + boost_acceleration * dt;
        _speed = min(boosted_speed_target, potential_new_speed);
        set_direction_angle(this.angle - pi / 2); // Update velocity with new speed
        break;
    }

    // Animation and smoke
    _anim_time = (_anim_time + dt * 4) % 1;
    _smoke_time += dt;
    if (_smoke_time > 0.02) {
      _smoke_time = 0;
      decals.spawn(DecalKind.smoke, this);
    }

    final sprite_index = (_anim_time * (_sprites.columns - 1)).toInt();
    sprite = _sprites.getSprite(0, sprite_index);
  }

  @override
  void onCollision(Set<Vector2> intersectionPoints, PositionComponent other) {
    super.onCollision(intersectionPoints, other);
    if (recycled) return;
    if (other case Hostile it when it.susceptible) {
      final scale = 1.0 + 0.25 * (_boost / SecondaryWeapon.max_boosts);
      final hit_point = it.calculate_hit_point(it, intersectionPoints);
      it.on_hit(50 * scale, hit_point);
      _emit_nuke(this, _boost);
      recycle();
    }
  }
}
