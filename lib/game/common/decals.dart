import 'dart:math';
import 'dart:ui';

import 'package:flame/components.dart';
import 'package:flame/sprite.dart';
import 'package:flutteroids/core/common.dart';
import 'package:flutteroids/game/common/game_context.dart';
import 'package:flutteroids/game/common/sound.dart';
import 'package:flutteroids/game/world/world.dart';
import 'package:flutteroids/game/world/world_entity.dart';
import 'package:flutteroids/util/component_recycler.dart';
import 'package:flutteroids/util/extensions.dart';
import 'package:flutteroids/util/functions.dart';
import 'package:flutteroids/util/log.dart';
import 'package:flutteroids/util/random.dart';

extension GameContextExtensions on GameContext {
  Decals get decals => cache.putIfAbsent('decals', () => Decals());
}

enum DecalKind {
  dust(anim_time: 1.0),
  energy_ball(anim_time: 0.5, random_range: 0),
  explosion16(anim_time: 1.0),
  explosion32(anim_time: 1.0),
  mini_explosion(anim_time: 0.5, random_range: 0),
  smoke(anim_time: 1.0, random_range: 4, rotate_speed: 1),
  sparkle(anim_time: 0.5, random_range: 1, rotate_speed: 0.4),
  teleport(anim_time: 0.5, random_range: 0),
  ;

  const DecalKind({required this.anim_time, this.random_range = 8, this.rotate_speed});

  final double anim_time;
  final double random_range;
  final double? rotate_speed;
}

class Decals extends Component with GameContext {
  final _ready = <DecalKind, List<DecalObj>>{};
  final _active = <DecalKind, List<DecalObj>>{};
  final _anim = <DecalKind, SpriteSheet>{};

  List<DecalObj> spawn_multi(
    DecalKind decal,
    PositionComponent origin,
    int count, {
    Vector2? pos_override,
    double? pos_range,
    double? vel_range,
  }) =>
      List.generate(
          count,
          (_) => spawn(
                decal,
                origin,
                pos_override: pos_override,
                pos_range: pos_range,
                vel_range: vel_range,
              ));

  DecalObj spawn(
    DecalKind decal,
    PositionComponent origin, {
    Vector2? pos_override,
    double? pos_range,
    double? vel_range,
  }) {
    final spawn_pos = pos_override ?? spawn_pos_for(origin);
    final it = _spawn(decal, spawn_pos, pos_range: pos_range, vel_range: vel_range);
    if (dev) it.debugMode = debugMode;
    if (decal == DecalKind.teleport) {
      play_sound(Sound.teleport);
      it.size = origin.size;
    }
    return it;
  }

  DecalObj _spawn(DecalKind decal, Vector2 start, {double? pos_range, double? vel_range}) {
    late final DecalObj result;

    final instances = _active[decal] ??= List.empty(growable: true);
    final pool = _ready[decal]!;
    if (pool.isEmpty) {
      if (dev) {
        log_warn('decals pool empty for $decal');
        // throw 'decals pool empty for $decal';
      }
      pool.add(DecalObj(_anim[decal]!, decal));
    }
    instances.add(result = pool.removeAt(0));

    result.size.setAll(switch (decal) {
      DecalKind.dust => 6.0,
      DecalKind.mini_explosion => 8.0,
      DecalKind.smoke => 6.0,
      DecalKind.sparkle => 8.0,
      _ => 12.0,
    });
    result.world_pos.setFrom(start);
    result.velocity.setZero();
    result.time = 0;
    result.angle = 0;

    result.recycle = () {};

    pos_range = pos_range ?? decal.random_range;
    if (pos_range > 0) result.randomize_position(range: pos_range);
    if (vel_range != null) result.randomize_velocity(range: vel_range);

    world.add(result);
    return result;
  }

  @override
  onLoad() {
    _anim[DecalKind.dust] = sheetI('dust.png', 10, 1);
    _anim[DecalKind.energy_ball] = sheetI('energy_balls.png', 6, 3);
    _anim[DecalKind.explosion16] = sheetI('explosion16.png', 15, 1);
    _anim[DecalKind.explosion32] = sheetI('explosion32.png', 18, 1);
    _anim[DecalKind.mini_explosion] = sheetI('mini_explosion.png', 6, 1);
    _anim[DecalKind.smoke] = sheetI('smoke.png', 11, 1);
    _anim[DecalKind.sparkle] = sheetI('sparkle.png', 4, 1);
    _anim[DecalKind.teleport] = sheetI('teleport.png', 10, 1);

    _precreate_all();
  }

  void _precreate_all() {
    for (final it in DecalKind.values) {
      _ready[it] = List.empty(growable: true);
      _active[it] = List.empty(growable: true);
      final count = switch (it) {
        DecalKind.dust => 256,
        DecalKind.smoke => 64,
        _ => 16,
      };
      _precreate(it, count);
    }
  }

  void _precreate(DecalKind decal, int count) {
    for (var i = 0; i < count; i++) {
      _ready[decal]!.add(DecalObj(_anim[decal]!, decal));
    }
  }

  @override
  void update(double dt) {
    super.update(dt);
    for (final it in DecalKind.values) _update(it, dt);
  }

  void _update(DecalKind decal, double dt) {
    final decals = _active[decal];
    if (decals == null) return;

    for (final it in decals) {
      // it.position.x += it.velocity.x * dt;
      // it.position.y += it.velocity.y * dt;
      it.time += dt;
      if (decal.rotate_speed != null) it.angle += pi * 2 / decal.rotate_speed! * dt;
    }
    final done = decals.where((it) => it.time >= decal.anim_time).toList();
    for (final it in done) {
      _ready[decal]!.add(it);
      it.removeFromParent();
    }
    decals.removeAll(done);
  }
}

class DecalObj extends PositionComponent with HasPaint, Recyclable, WorldEntity {
  DecalObj(this.animation, this.decal); //  : this.velocity = Vector2.zero();

  final SpriteSheet animation;
  final DecalKind decal;

  // final Vector2 velocity;

  int row = 0;
  double time = 0;

  void randomize_position({double range = 20}) {
    world_pos.x += level_rng.nextDoublePM(range);
    world_pos.y += level_rng.nextDoublePM(range);
  }

  void randomize_velocity({double range = 20}) {
    velocity.x += level_rng.nextDoublePM(range);
    velocity.y += level_rng.nextDoublePM(range);
  }

  @override
  void update(double dt) {
    super.update(dt);
    priority = 1000;
  }

  @override
  void render(Canvas canvas) {
    final it = this;
    final column = (it.time * (animation.columns - 1) / decal.anim_time).toInt();
    final f = animation.getSprite(it.row, column);
    f.render(canvas, anchor: Anchor.center, size: size);
  }
}
