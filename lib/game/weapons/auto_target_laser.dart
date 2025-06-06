import 'dart:math';
import 'dart:ui';

import 'package:flame/components.dart';
import 'package:flutteroids/game/common/extra_id.dart';
import 'package:flutteroids/game/common/extras.dart';
import 'package:flutteroids/game/common/game_context.dart';
import 'package:flutteroids/game/common/kinds.dart';
import 'package:flutteroids/game/weapons/auto_target.dart';
import 'package:flutteroids/game/world/world.dart';
import 'package:flutteroids/game/world/world_entity.dart';
import 'package:flutteroids/input/game_keys.dart';
import 'package:flutteroids/util/mutable.dart';

class AutoTargetLaser extends PositionComponent with GameContext, PrimaryWeapon, AutoTarget {
  AutoTargetLaser(this.player);

  static const double _base_laser_damage = 0.1;
  static const double _max_scan_spread = pi / 8;
  static const double _scanner_sweep_speed = pi * 4;

  final Paint _line_paint_dark = Paint()
    ..color = const Color(0x80FF0000) // Dark red, 50% alpha
    ..strokeWidth = 2.0
    ..style = PaintingStyle.stroke;

  final Paint _line_paint_bright = Paint()
    ..color = const Color(0xFF00FF00) // Full red, 100% alpha
    ..strokeWidth = 0.75
    ..style = PaintingStyle.stroke;

  final Paint _scanner_paint = Paint()
    ..color = const Color(0x40FF0000) // Dark red, 50% alpha
    ..strokeWidth = 1.0
    ..style = PaintingStyle.stroke;

  final _target = MutableOffset.zero();
  final _sweep = MutableOffset.zero();

  final Player player;

  (Hostile?, double?) _current_target = (null, null);
  double _scanner_sweep_angle_offset = 0.0;
  int _scanner_sweep_direction = 1;
  double _max_scan_range = 0.0;

  bool _scanning = false;

  @override
  String get display_name => 'Auto Target Laser';

  @override
  Sprite get icon => extras.icon_for(ExtraId.auto_laser);

  @override
  double get heat => -1.0; // No overheating

  @override
  void update(double dt) {
    super.update(dt);

    if (!player.weapons_hot || !keys.check(GameKey.a_button)) {
      _current_target = (null, null);
      _scanning = false;
      return;
    }

    final range_factor = 1.0 + 0.25 * (boost / PrimaryWeapon.max_boosts);
    _max_scan_range = world.world_viewport_size / 2 * range_factor;

    _current_target = auto_target_angle(
      player.world_pos,
      player.angle,
      max_spread: pi / 8,
      max_range: world.world_viewport_size / 2 * range_factor,
    );

    final target = _current_target.$1;
    if (target == null) {
      // No target, but player is attempting to fire (checked at the start of update):
      // update scanner animation and then return.
      _update_scanner_sweep(dt);
      _scanning = true;
      return;
    }

    final dmg = _base_laser_damage + 0.2 * (boost / PrimaryWeapon.max_boosts);
    target.on_hit(dmg);
    _target.setFrom((target as WorldEntity).world_pos);
  }

  void _update_scanner_sweep(double dt) {
    _scanner_sweep_angle_offset += _scanner_sweep_direction * _scanner_sweep_speed * dt;
    if (_scanner_sweep_angle_offset.abs() > _max_scan_spread) {
      _scanner_sweep_angle_offset = _max_scan_spread * _scanner_sweep_direction;
      _scanner_sweep_direction *= -1;
    }
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);

    canvas.translate(player.size.x * 0.5, player.size.y * 0.5);
    canvas.rotate(-player.angle);

    final target_entity = _current_target.$1;
    if (target_entity != null) {
      canvas.drawLine(Offset.zero, _target, _line_paint_dark);
      canvas.drawLine(Offset.zero, _target, _line_paint_bright);
    } else if (_scanning) {
      _sweep.dx = _max_scan_range * cos(_scanner_sweep_angle_offset + player.angle);
      _sweep.dy = _max_scan_range * sin(_scanner_sweep_angle_offset + player.angle);
      canvas.drawLine(Offset.zero, _sweep, _scanner_paint);
    }

    canvas.rotate(player.angle);
    canvas.translate(-player.size.x * 0.5, -player.size.y * 0.5);
  }
}
