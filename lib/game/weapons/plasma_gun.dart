import 'dart:math';

import 'package:flame/components.dart';
import 'package:flutteroids/aural/audio_system.dart';
import 'package:flutteroids/game/common/extra_id.dart';
import 'package:flutteroids/game/common/extras.dart';
import 'package:flutteroids/game/common/game_context.dart';
import 'package:flutteroids/game/common/kinds.dart';
import 'package:flutteroids/game/projectiles/plasma_shot.dart';
import 'package:flutteroids/game/weapons/auto_target.dart';
import 'package:flutteroids/game/world/world.dart';
import 'package:flutteroids/util/component_recycler.dart';

class PlasmaGun extends Component with GameContext, PrimaryWeapon, AutoTarget {
  PlasmaGun(this._player);

  final Player _player;

  late final _projectiles = ComponentRecycler(() => PlasmaShot())..precreate(128);

  static const max_heat = 100.0;
  static const heat_per_shot = 25.0;
  static const heat_dissipation_rate = 60.0;
  static const normal_fire_rate = 0.15;

  double _current_heat = 0.0;
  double _cool_down = 0.0;

  @override
  String get display_name => 'Plasma Gun';

  @override
  Sprite get icon => extras.icon_for(ExtraId.plasma_gun);

  @override
  void on_boost() {
    super.on_boost();
    PlasmaShot.power_boost = min(5, PlasmaShot.power_boost + 0.25);
  }

  @override
  double get heat => _current_heat / max_heat;

  @override
  onLoad() => PlasmaShot.power_boost = 0;

  @override
  void update(double dt) {
    _update_heat_system(dt);
    _handle_firing();
  }

  void _update_heat_system(double dt) {
    _current_heat = (_current_heat - heat_dissipation_rate * dt).clamp(0.0, max_heat);
    if (_cool_down > 0) _cool_down -= dt;
  }

  void _handle_firing() {
    if (_cool_down > 0) return;

    if (keys.a_button && _can_fire() && _player.weapons_hot) {
      _fire_shot();
    }
  }

  bool _can_fire() => _current_heat + heat_per_shot <= max_heat;

  void _fire_shot() {
    _cool_down = normal_fire_rate;
    _current_heat = (_current_heat + heat_per_shot).clamp(0.0, max_heat);

    final (_, angle) = auto_target_angle(_player.world_pos, _player.angle);
    final count = 1 + PlasmaShot.power_boost.round();
    // log_debug('Firing Plasma Gun: count=$count boost=${PlasmaShot.power_boost}');
    for (var i = 0; i < count; i++) {
      final d = pi / 48 * (i - (count - 1) / 2);
      world.add(_projectiles.acquire()
        ..reset(_player, angle ?? _player.angle)
        ..speed_buff = -d.abs() * 250
        ..change_direction(d));
    }

    audio.play(Sound.shot, volume_factor: 0.5);
  }
}
