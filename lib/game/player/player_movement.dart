part of 'player.dart';

mixin _PlayerMovement on GameContext, VoxelRotation {
  var max_rotation_speed = 5.0;
  var rotation_acceleration = 1.0;
  var rotation_drag = 0.99;

  var thrust_acceleration = 200.0;
  var max_velocity = 500.0;
  var drag = 0.99;

  var smoke_spawn_rate = 0.1;
  var smoke_intensity = 2.0;

  double rotation_speed = 0.0;
  double target_rotation_speed = 0.0;
  double thrust_power = 0.0;
  double _smoke_timer = 0.0;

  final velocity = Vector2.zero();
  double movement_angle = 0.0;

  bool controls_locked = false;

  @override
  void update(double dt) {
    if (!controls_locked) {
      handle_input(dt);
      apply_rotation_physics(dt);
    }
    apply_movement_physics(dt);
    super.update(dt);
  }

  void handle_input(double dt) {
    target_rotation_speed = 0.0;
    thrust_power = 0.0;

    if (keys.check(GameKey.left)) target_rotation_speed = -max_rotation_speed;
    if (keys.check(GameKey.right)) target_rotation_speed = max_rotation_speed;
    if (keys.check(GameKey.up)) thrust_power = thrust_acceleration;
  }

  void apply_rotation_physics(double dt) {
    final rotation_diff = target_rotation_speed - rotation_speed;
    rotation_speed += rotation_diff * rotation_acceleration * dt;
    rotation_speed *= rotation_drag;

    movement_angle += rotation_speed * dt;
    angle = movement_angle;

    rot_y = -rotation_speed / 2 / pi;
    rot_z = pi / 2;
  }

  final _thrust = Vector2.zero();

  void apply_movement_physics(double dt) {
    if (thrust_power > 0) {
      _thrust.x = cos(movement_angle) * thrust_power * dt;
      _thrust.y = sin(movement_angle) * thrust_power * dt;
      velocity.add(_thrust);

      if (velocity.length2 > max_velocity * max_velocity) {
        velocity.normalize();
        velocity.scale(max_velocity);
      }

      _spawn_thrust_smoke(dt);
    }

    velocity.scale(drag);

    voxel.exhaust_length = 1 + velocity.length / max_velocity * 16;
  }

  void _spawn_thrust_smoke(double dt) {
    _smoke_timer += dt;

    final thrust_factor = thrust_power / thrust_acceleration;
    final spawn_interval = smoke_spawn_rate / (thrust_factor * smoke_intensity);

    if (_smoke_timer >= spawn_interval) {
      _smoke_timer = 0.0;

      final smoke_offset_x = -cos(movement_angle) * size.x * 0.5;
      final smoke_offset_y = -sin(movement_angle) * size.y * 0.5;
      final smoke_pos = Vector2(smoke_offset_x, smoke_offset_y);

      final it = decals.spawn(
        DecalKind.smoke,
        this,
        pos_override: smoke_pos,
        pos_range: size.x * 0.5,
        vel_range: thrust_factor * 20,
      );
      it.velocity.setValues(
        -cos(movement_angle) * thrust_factor * 20,
        -sin(movement_angle) * thrust_factor * 20,
      );
    }
  }
}
