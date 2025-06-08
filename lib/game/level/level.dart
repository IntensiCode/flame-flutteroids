import 'dart:math';

import 'package:flame/components.dart';
import 'package:flutteroids/core/common.dart';
import 'package:flutteroids/game/common/extra_id.dart';
import 'package:flutteroids/game/common/game_context.dart';
import 'package:flutteroids/game/common/game_phase.dart';
import 'package:flutteroids/game/common/messages.dart';
import 'package:flutteroids/game/enemies/ufo_enemy.dart';
import 'package:flutteroids/game/level/acquire_ion_pulse_gun.dart';
import 'package:flutteroids/game/level/boost_plasma_gun.dart';
import 'package:flutteroids/game/level/level_goal.dart';
import 'package:flutteroids/game/world/world.dart';
import 'package:flutteroids/util/log.dart';

extension GameContextExtensions on GameContext {
  Level get level => cache.putIfAbsent('level', () => Level());
}

class Level extends Component with GameContext {
  late int current_level;
  late double max_asteroid_mass;
  late int max_total_asteroids;
  late double asteroid_speed_multiplier;

  LevelGoal? primary_goal;
  bool _notified = false;

  bool get completed => primary_goal?.completed ?? false;

  // /// Message containing the taglines of all goals in the level.
  // String get tagline => children.map((it) => it is LevelGoal ? it.tagline : '').join('\n');

  /// Message containing the tagline of the primary goal in the level.
  String get tagline => primary_goal?.tagline ?? '';

  /// Message containing the messages of all completed goals in the level.
  String get message => children.map((it) => it is LevelGoal && it.completed ? it.message : '').join('\n');

  /// Iterable of all completed goals in the level.
  Iterable<LevelGoal> get completed_goals => children.whereType<LevelGoal>().where((goal) => goal.completed);

  void set_level(int level) {
    log_debug('Setting level to $level');

    level_rng = Random(level);

    current_level = level;
    max_asteroid_mass = 5000;
    max_total_asteroids = 12;
    asteroid_speed_multiplier = 1.0;
    _notified = false;

    removeAll(children);

    // TODO Add more primary goals
    // TODO Add secondary goals
    // TODO How to handle enemies? Here? Or dedicated spawner? Linked to the level somehow?

    switch (level) {
      case 1:
        add(primary_goal = BoostPlasmaGun());

      case 2:
        add(SpawnIonPulseGunCarryingUfos());
        add(primary_goal = AcquireIonPulseGun());

      default:
        add(SpawnIonPulseGunCarryingUfos());
        add(BoostPlasmaGun());
        add(AcquireIonPulseGun());
    }
  }

  @override
  void update(double dt) {
    if (completed && !_notified) {
      log_debug('Level $current_level completed');
      send_message(LevelComplete(message));
      _notified = true;
    }
  }
}

class SpawnIonPulseGunCarryingUfos extends Component with GameContext {
  UfoEnemy? _spawned;

  @override
  void update(double dt) {
    super.update(dt);

    if (stage.phase != GamePhase.play_level) return;

    if (_spawned == null || _spawned!.recycled) {
      log_debug('Spawning UFO Enemy from $this $hashCode');
      world.add(_spawned = UfoEnemy()..spawning = {ExtraId.ion_pulse});
    }
  }
}
