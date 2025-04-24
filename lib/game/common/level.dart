import 'dart:math';

import 'package:flame/components.dart';
import 'package:flutteroids/core/common.dart';
import 'package:flutteroids/game/common/game_context.dart';

extension GameContextExtensions on GameContext {
  Level get level => cache.putIfAbsent('level', () => Level());
}

class Level extends Component {
  late int current_level;
  late double max_asteroid_mass;
  late int max_total_asteroids;
  late double asteroid_speed_multiplier;

  void set_level(int level) {
    level_rng = Random(level);
    current_level = level;
    max_asteroid_mass = 5000;
    max_total_asteroids = 12;
    asteroid_speed_multiplier = 1.0;
  }
}
