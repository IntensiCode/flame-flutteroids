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

class AcquireIonPulseGun extends Component with AutoDispose, GameContext, LevelGoal {
  static const level_duration = 180.0;

  double level_time = level_duration;
  int collected = 0;

  @override
  String get tagline => 'Acquire Ion Pulse Gun';

  @override
  String get message => '$collected Ion Pulse Gun Upgrades';

  @override
  int get bonus => 500 * collected + min(500, level_time.toInt() * 10);

  @override
  void onMount() {
    // TODO EnemyDestroyed
    // on_message<AsteroidDestroyed>((msg) {
    //   if (level_rng.nextDouble() < 0.25 && collected < 3) {
    //     extras.spawn(msg.asteroid, choices: {ExtraId.plasma_gun}, count: 1);
    //   }
    // });
    on_message<ExtraCollected>((msg) {
      if (msg.which == ExtraId.ion_pulse) {
        log_debug('Ion pulse gun collected');
        collected++;
      }
    });
  }

  @override
  void update(double dt) {
    super.update(dt);

    if (completed || stage.phase != GamePhase.play_level) return;

    if (level_time > 0) level_time = max(0.0, level_time - dt);

    if (collected >= 1 || (level_time <= 0 && collected >= 1)) {
      completed = true;
      log_debug('Acquire Ion Pulse Gun goal completed');
    }
  }
}
