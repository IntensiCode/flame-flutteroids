import 'dart:math';

import 'package:flame/components.dart';
import 'package:flutteroids/core/common.dart';
import 'package:flutteroids/game/common/extra_id.dart';
import 'package:flutteroids/game/common/extras.dart';
import 'package:flutteroids/game/common/game_context.dart';
import 'package:flutteroids/game/common/game_phase.dart';
import 'package:flutteroids/game/common/messages.dart';
import 'package:flutteroids/game/level/level_goal.dart';
import 'package:flutteroids/util/auto_dispose.dart';
import 'package:flutteroids/util/log.dart';
import 'package:flutteroids/util/on_message.dart';

class BoostPlasmaGun extends Component with AutoDispose, GameContext, LevelGoal {
  static const level_duration = 180.0;

  double level_time = level_duration;
  int collected_extras = 0;

  @override
  String get tagline => 'Collect Plasma Gun Upgrades';

  @override
  String get message => '$collected_extras Plasma Gun Upgrades collected';

  @override
  int get bonus => 1000 * collected_extras + min(1000, level_time.toInt() * 10);

  @override
  void onMount() {
    on_message<AsteroidDestroyed>((msg) {
      if (level_rng.nextDouble() < 0.25) {
        extras.spawn(msg.asteroid, choices: {ExtraId.plasma_gun}, count: 1);
      }
    });
    on_message<ExtraCollected>((msg) {
      if (msg.which == ExtraId.plasma_gun) {
        log_debug('Plasma gun collected');
        collected_extras++;
      }
    });
  }

  @override
  void update(double dt) {
    super.update(dt);

    if (stage.phase != GamePhase.play_level) return;

    if (level_time > 0) level_time = max(0.0, level_time - dt);

    if (collected_extras >= 3 || (level_time <= 0 && collected_extras >= 1)) {
      completed = true;
      log_debug('Boost Plasma Gun goal completed');
    }
  }
}
