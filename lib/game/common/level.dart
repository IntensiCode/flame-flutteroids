import 'dart:math';

import 'package:flame/components.dart';
import 'package:flutteroids/core/common.dart';
import 'package:flutteroids/game/common/extra_id.dart';
import 'package:flutteroids/game/common/extras.dart';
import 'package:flutteroids/game/common/game_context.dart';
import 'package:flutteroids/game/common/messages.dart';
import 'package:flutteroids/util/auto_dispose.dart';
import 'package:flutteroids/util/log.dart';
import 'package:flutteroids/util/messaging.dart';
import 'package:flutteroids/util/on_message.dart';

extension GameContextExtensions on GameContext {
  Level get level => cache.putIfAbsent('level', () => Level());
}

class Level extends Component {
  late int current_level;
  late double max_asteroid_mass;
  late int max_total_asteroids;
  late double asteroid_speed_multiplier;

  LevelGoal? primary_goal;
  bool _notified = false;

  bool get completed => primary_goal?.completed ?? false;

  /// Message containing the taglines of all goals in the level.
  String get tagline => children.map((it) => it is LevelGoal ? it.tagline : '').join('\n');

  /// Message containing the messages of all completed goals in the level.
  String get message => children.map((it) => it is LevelGoal && it.completed ? it.message : '').join('\n');

  void set_level(int level) {
    level_rng = Random(level);

    current_level = level;
    max_asteroid_mass = 5000;
    max_total_asteroids = 12;
    asteroid_speed_multiplier = 1.0;
    _notified = false;

    removeAll(children);
    add(primary_goal = primary_goal_for_level(level));

    // TODO Add more primary goals
    // TODO Add secondary goals
  }

  LevelGoal primary_goal_for_level(int level) {
    return BoostPlasmaGun();
  }

  @override
  void update(double dt) {
    if (completed && !_notified) {
      log_debug('Level $current_level completed');
      send_message(LevelComplete(message));
      removeAll(children);
      _notified = true;
    }
  }
}

mixin LevelGoal on Component {
  bool completed = false;

  String get tagline;

  String get message;

  int get bonus;
}

class BoostPlasmaGun extends Component with AutoDispose, GameContext, LevelGoal {
  double level_time = 0.0;
  int collected_extras = 0;

  @override
  String get tagline => 'Collect Plasma Gun Upgrades';

  @override
  String get message => '$collected_extras Plasma Gun Upgrades collected';

  @override
  int get bonus => 1000 * collected_extras + level_time.clamp(0.0, 60.0).toInt() * 100;

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
    level_time += dt;

    if (collected_extras >= 3 || (level_time > 60.0 && collected_extras >= 1)) {
      completed = true;
      log_debug('Boost Plasma Gun goal completed');
    }
  }
}
