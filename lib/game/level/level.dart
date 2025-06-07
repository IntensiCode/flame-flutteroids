import 'dart:math';

import 'package:flame/components.dart';
import 'package:flutteroids/core/common.dart';
import 'package:flutteroids/game/common/game_context.dart';
import 'package:flutteroids/game/common/messages.dart';
import 'package:flutteroids/game/level/boost_plasma_gun.dart';
import 'package:flutteroids/game/level/level_goal.dart';
import 'package:flutteroids/util/log.dart';
import 'package:flutteroids/util/messaging.dart';

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
