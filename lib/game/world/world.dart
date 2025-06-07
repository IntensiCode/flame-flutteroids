import 'dart:math';

import 'package:flame/components.dart';
import 'package:flutteroids/core/common.dart';
import 'package:flutteroids/core/traits.dart';
import 'package:flutteroids/game/common/game_context.dart';
import 'package:flutteroids/game/common/kinds.dart';
import 'package:flutteroids/game/projectiles/directional_projectile.dart';
import 'package:flutteroids/game/world/world_entity.dart';

extension GameContextExtensions on GameContext {
  AsteroidsWorld get world => cache.putIfAbsent('world', () => AsteroidsWorld());
}

class AsteroidsWorld extends PositionComponent with HasTraits, GameContext {
  double get world_viewport_size => min(game_size.x, game_size.y);

  Iterable<Hostile> get hostiles => children.whereType<Hostile>();

  void translate_all_by(Vector2 delta) {
    for (final it in children.whereType<WorldEntity>()) {
      it.world_pos.sub(delta);
    }

    final outside = children.whereType<WorldEntity>().where((it) => it.is_outside_world());
    for (final it in outside) {
      it.recycle();
    }
  }

  @override
  void onLoad() {
    anchor = Anchor.center;
    position.x = game_size.x - world_viewport_size / 2 - 32; // Offset to the right side for HUD
    position.y = game_size.y - world_viewport_size / 2;
  }

  @override
  void onMount() {
    super.onMount();
    DirectionalProjectile.world_size = () => world_viewport_size;
  }
}
