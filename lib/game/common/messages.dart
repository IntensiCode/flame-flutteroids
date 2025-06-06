import 'package:flutteroids/core/common.dart';
import 'package:flutteroids/game/asteroids/asteroid.dart';
import 'package:flutteroids/game/common/extra_id.dart';
import 'package:flutteroids/game/common/game_phase.dart';
import 'package:flutteroids/game/common/kinds.dart';

class AsteroidDestroyed with Message {
  final Asteroid asteroid;

  AsteroidDestroyed(this.asteroid);
}

class AsteroidSplit with Message {
  final Asteroid asteroid;

  AsteroidSplit(this.asteroid);
}

class EnemyDestroyed with Message {
  EnemyDestroyed(this.target, {required this.score});

  final Hostile target;
  final bool score;
}

class EnteringLevel with Message {
  EnteringLevel(this.number);

  final int number;
}

class ExtraCollected with Message {
  ExtraCollected(this.which);

  final ExtraId which;
}

class GamePhaseUpdate with Message {
  GamePhaseUpdate(this.phase);

  final GamePhase phase;
}

class LeavingLevel with Message {
  LeavingLevel(this.next);

  final int next;
}

class LevelComplete with Message {
  LevelComplete(this.message);

  final String message;
}

class PlayerDestroyed with Message {
  PlayerDestroyed({required this.game_over});

  final bool game_over;
}

class PlayerLeft with Message {}

class PlayingLevel with Message {
  PlayingLevel(this.number);

  final int number;
}

class PlayerReady with Message {}

class Rumble with Message {
  Rumble({this.duration = 1, this.haptic = true});

  final double duration;
  final bool haptic;
}
