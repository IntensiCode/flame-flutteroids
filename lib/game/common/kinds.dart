import 'dart:ui';

import 'package:flame/components.dart';
import 'package:flame/game.dart';
import 'package:flutteroids/game/common/extra_id.dart';
import 'package:flutteroids/game/common/game_context.dart';
import 'package:flutteroids/input/game_keys.dart';

mixin Integrity {
  // Integrity (0.0 to 1.0), or -1.0 if indestructible.
  double get integrity;
}

mixin Player implements Integrity {
  Vector2 get world_pos;

  Vector2 get velocity;

  NotifyingVector2 get size;

  double get angle;

  bool get weapons_hot;

  void on_collect_extra(ExtraId which);
}

mixin PrimaryWeapon on Component {
  static const int max_boosts = 10;

  int boost = 0;

  String get display_name;

  Sprite get icon;

  // Heat (0.0 to 1.0), or -1.0 if weapon can not overheat.
  double get heat;

  void on_boost() => boost = (boost + 1).clamp(0, max_boosts);
}

mixin SecondaryWeapon on GameContext {
  static const int max_boosts = 10;

  int boost = 0;

  var button = GameKey.b_button;

  String get display_name;

  Sprite get icon;

  double cooldown = 0;
  double cooldown_time = 3;
  double _activation_guard = 0.0;

  Player get player;

  late Function(SecondaryWeapon) on_fired;

  void on_boost() {
    boost = (boost + 1).clamp(0, max_boosts);
  }

  void set_activation_guard() => _activation_guard = 0.2;

  @override
  void update(double dt) {
    if (keys.held[button] == false && _activation_guard > 0) {
      _activation_guard = 0;
    }
    if (_activation_guard > 0) {
      _activation_guard -= dt;
      return;
    }

    if (cooldown > 0) return;
    if (keys.held[button] != true) return;
    if (player.weapons_hot == false) return;
    do_fire();
    on_fired(this);
  }

  void do_fire();
}

mixin OnHit on Component {
  static const hit_color = Color(0xFFffffff);

  double hit_time = 0;

  late double max_hit_points;
  late double remaining_hit_points;

  bool get is_destroyed => remaining_hit_points <= 0 || isRemoved;

  /// True if this component can currently be hit by hostile entities.
  ///
  /// May be false if (temporarily) invulnerable. For example due to teleporting or such.
  bool get susceptible;

  void on_hit(double damage) {
    if (is_destroyed) return;
    hit_time = 0.05;
    remaining_hit_points -= damage;
    if (remaining_hit_points < 0) remaining_hit_points = 0;
  }

  @override
  void update(double dt) {
    super.update(dt);
    hit_time = (hit_time - dt).clamp(0, 1);
  }
}

mixin Friendly on OnHit {}

mixin Hostile on OnHit, PositionComponent {}
