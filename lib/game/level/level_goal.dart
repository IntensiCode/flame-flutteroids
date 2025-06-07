import 'package:flame/components.dart';

mixin LevelGoal on Component {
  bool completed = false;

  String get tagline;

  String get message;

  int get bonus;
}
