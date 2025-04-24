part of 'player.dart';

enum UTurnPhase { none, turning }

mixin _PlayerUTurn on _PlayerMovement {
  final _uturn_rotation_speed = 6.0;

  UTurnPhase _uturn_phase = UTurnPhase.none;
  double _uturn_progress = 0.0;
  double _uturn_target_rot_x = 0.0;

  bool get is_turning => _uturn_phase != UTurnPhase.none;

  @override
  void handle_input(double dt) {
    if (_uturn_phase == UTurnPhase.none && keys.check(GameKey.down)) {
      _start_uturn();
    } else if (_uturn_phase == UTurnPhase.none) {
      super.handle_input(dt);
    }
  }

  void _start_uturn() {
    controls_locked = true;
    target_rotation_speed = 0.0;
    _uturn_target_rot_x = rot_x + pi;
    _uturn_phase = UTurnPhase.turning;
  }

  @override
  void update(double dt) {
    if (_uturn_phase == UTurnPhase.turning) {
      _uturn_progress += dt;
      if (_uturn_progress > 1.0) {
        _complete_uturn();
      } else {
        _on_uturn(dt);
      }
    }
    controls_locked = _uturn_progress > 0.0 && _uturn_progress < 0.9;
    super.update(dt);
  }

  void _complete_uturn() {
    _uturn_progress = 0.0;

    movement_angle += pi;
    angle = movement_angle;
    rot_x -= pi;

    final escape_velocity = velocity.length * 0.8;
    _thrust.x = cos(movement_angle) * escape_velocity;
    _thrust.y = sin(movement_angle) * escape_velocity;
    velocity.setValues(_thrust.x, _thrust.y);

    _uturn_phase = UTurnPhase.none;
  }

  void _on_uturn(double dt) {
    rot_x += _uturn_rotation_speed * dt;
    if (rot_x >= _uturn_target_rot_x) rot_x = _uturn_target_rot_x;

    if (_uturn_progress >= 0.5) {
      rot_y += _uturn_rotation_speed * dt;
    } else {
      rot_y = 0;
    }

    final offset_amount = sin(_uturn_progress * pi);
    final sprite_diagonal = sqrt(size.x * size.x + size.y * size.y) * 1.0;
    final compensation_distance = offset_amount * sprite_diagonal;

    final move_x = cos(movement_angle) * compensation_distance / 2;
    final move_y = sin(movement_angle) * compensation_distance / 2;

    position.x += move_x;
    position.y += move_y;
  }
}
