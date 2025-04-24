import 'package:flame/components.dart';
import 'package:flutteroids/aural/audio_system.dart';
import 'package:flutteroids/game/common/extra_id.dart';
import 'package:flutteroids/game/common/extras.dart';
import 'package:flutteroids/game/common/game_context.dart';
import 'package:flutteroids/game/common/kinds.dart';
import 'package:flutteroids/game/projectiles/ion_pulse.dart';
import 'package:flutteroids/game/world/world.dart';
import 'package:flutteroids/util/component_recycler.dart';

class IonPulseGun extends Component with GameContext, PrimaryWeapon {
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

    if (keys.a_button) {
      _cool_down += 0.8;

      for (var i = 0; i < 5; i++) {
        world.add(_projectiles.acquire()..reset_(_player, _player.angle, (i + 1) * 0.05));
      }

      audio.play(Sound.pulse, volume_factor: 0.5);
    }
  }
}
