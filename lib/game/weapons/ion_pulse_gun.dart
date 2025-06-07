import 'dart:math';

import 'package:flame/components.dart';
import 'package:flutteroids/game/common/extra_id.dart';
import 'package:flutteroids/game/common/extras.dart';
import 'package:flutteroids/game/common/game_context.dart';
import 'package:flutteroids/game/common/kinds.dart';
import 'package:flutteroids/game/common/sound.dart';
import 'package:flutteroids/game/projectiles/ion_pulse.dart';
import 'package:flutteroids/game/weapons/auto_target.dart';
import 'package:flutteroids/game/world/world.dart';
import 'package:flutteroids/util/component_recycler.dart';

class IonPulseGun extends Component with GameContext, PrimaryWeapon, AutoTarget {
  IonPulseGun(this._player);

  final Player _player;

  final _projectiles = ComponentRecycler(() => IonPulse())..precreate(64);

  double _cool_down = 0;

  @override
  String get display_name => 'Ion Pulse';

  @override
  Sprite get icon => extras.icon_for(ExtraId.ion_pulse);

  @override
  double get heat => -1.0;

  @override
  void update(double dt) {
    if (_cool_down > 0) {
      _cool_down -= dt;
      return;
    }

    if (keys.a_button && _player.weapons_hot) {
      final cooldown_factor = 1.0 - 0.5 * (boost / PrimaryWeapon.max_boosts);
      _cool_down += 0.8 * cooldown_factor;

      for (var i = 0; i < 5; i++) {
        final (_, angle) = auto_target_angle(_player.world_pos, _player.angle, max_spread: pi / 16);
        world.add(_projectiles.acquire()
          ..reset_with_delay(
            _player,
            angle ?? _player.angle,
            (i + 1) * 0.05,
            boost,
          ));
      }

      play_sound(Sound.pulse, volume_factor: 0.5);
    }
  }
}
