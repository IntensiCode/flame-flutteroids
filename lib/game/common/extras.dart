import 'dart:math';

import 'package:flame/collisions.dart';
import 'package:flame/components.dart';
import 'package:flame/sprite.dart';
import 'package:flutteroids/core/common.dart';
import 'package:flutteroids/game/common/decals.dart';
import 'package:flutteroids/game/common/extra_id.dart';
import 'package:flutteroids/game/common/game_context.dart';
import 'package:flutteroids/game/player/player.dart';
import 'package:flutteroids/game/weapons/auto_target_laser.dart';
import 'package:flutteroids/game/weapons/ion_pulse_gun.dart';
import 'package:flutteroids/game/weapons/nuke_missile_launcher.dart';
import 'package:flutteroids/game/weapons/plasma_emitter.dart';
import 'package:flutteroids/game/weapons/plasma_gun.dart';
import 'package:flutteroids/game/weapons/smart_bomb.dart';
import 'package:flutteroids/game/world/world.dart';
import 'package:flutteroids/game/world/world_entity.dart';
import 'package:flutteroids/util/component_recycler.dart';
import 'package:flutteroids/util/extensions.dart';
import 'package:flutteroids/util/functions.dart';
import 'package:flutteroids/util/log.dart';
import 'package:flutteroids/util/random.dart';

enum ExtrasGroup {
  asteroid_split,
  asteroid_destroyed,
  boss_destroyed,
  enemy_destroyed,
}

extension GameContextExtensions on GameContext {
  Extras get extras => cache.putIfAbsent('extras', () => Extras());
}

class Extras extends Component with GameContext {
  Extras() {
    priority = 10000;
  }

  late final SpriteSheet _sheet;
  late final ComponentRecycler<Extra> _pool;

  Sprite icon_for(ExtraId which) => _sheet.getSpriteById(which.sheet_index);

  Set<ExtraId> choices_for(ExtrasGroup group) {
    final choices = ExtraId.values.toSet();
    if (!player.weapon_system.has_acquired(PlasmaGun)) choices.remove(ExtraId.plasma_gun);
    if (!player.weapon_system.has_acquired(IonPulseGun)) choices.remove(ExtraId.ion_pulse);
    if (!player.weapon_system.has_acquired(AutoTargetLaser)) choices.remove(ExtraId.auto_laser);
    if (!player.weapon_system.has_acquired(PlasmaEmitter)) choices.remove(ExtraId.plasma_ring);
    if (!player.weapon_system.has_acquired(NukeMissileLauncher)) choices.remove(ExtraId.nuke_missile);
    if (!player.weapon_system.has_acquired(SmartBomb)) choices.remove(ExtraId.smart_bomb);
    if (!player.weapon_system.has_secondary()) choices.remove(ExtraId.cooldown);
    log_debug('Available extras: $choices');

    switch (group) {
      case ExtrasGroup.asteroid_split:
        // Remove secondary weapons:
        choices.removeAll(const [ExtraId.plasma_ring, ExtraId.nuke_missile, ExtraId.smart_bomb]);
        return choices;
      case ExtrasGroup.asteroid_destroyed:
        return choices;
      case ExtrasGroup.boss_destroyed:
        // TODO Every boss spawns specific extras.
        return choices;
      case ExtrasGroup.enemy_destroyed:
        // Remove secondary weapons:
        choices.removeAll(const [ExtraId.plasma_ring, ExtraId.nuke_missile, ExtraId.smart_bomb]);
        return choices;
    }
  }

  void spawn_multi(WorldEntity origin, {required Set<ExtraId> choices, int count = 1}) {
    if (count <= 0) return;
    if (choices.isEmpty) return;

    log_debug('Spawning $count extras from $choices');

    for (int i = 0; i < count; i++) {
      spawn(origin, choices: choices, index: i, count: count);
    }
  }

  void spawn(WorldEntity origin, {required Set<ExtraId> choices, int? index, int? count}) {
    final pick = _pick_power_up(choices);
    if (pick == null) return;

    log_debug('Spawning extra: $pick');

    final extra = world.added(_pool.acquire()..reset(pick, origin));
    if (count != null && count > 1) {
      // If we have multiple extras, spread them around the origin:
      final dist = count * 4.0;
      extra.world_pos.x += level_rng.nextDoublePM(dist);
      extra.world_pos.y += level_rng.nextDoublePM(dist);
    }
    // if (index != null && count != null && count > 1) {
    //   final distance = count * 6;
    //   final angle = 2 * pi * index / count;
    //   extra.world_pos.x += cos(angle) * distance;
    //   extra.world_pos.y += sin(angle) * distance;
    // }
  }

  ExtraId? _pick_power_up(Set<ExtraId> allowed) {
    if (allowed.isEmpty) return null;

    // pick random power up, based on probabilities in _extras:

    final extras = <(ExtraId, double)>[];
    var added_probability = 0.0;
    for (final it in allowed) {
      added_probability += it.probability;
      extras.add((it, added_probability));
    }

    final all = extras.last.$2;
    final pick = level_rng.nextDoubleLimit(all);
    for (final it in extras) {
      if (pick < it.$2) return it.$1;
    }
    throw 'oh really?';
  }

  @override
  void onRemove() {
    super.onRemove();
    parent?.children.whereType<Extra>().forEach((it) => it.recycle());
    _pool.items.clear();
  }

  @override
  onLoad() {
    _sheet = sheetI('extras.png', 8, 4);

    final sweep_anim = _sheet.createAnimation(row: 0, stepTime: 0.1);

    final sprites = <ExtraId, Sprite>{
      // Primary weapons:
      ExtraId.plasma_gun: _sheet.getSpriteById(8),
      ExtraId.ion_pulse: _sheet.getSpriteById(10),
      ExtraId.auto_laser: _sheet.getSpriteById(24),
      // Secondary weapons:
      ExtraId.plasma_ring: _sheet.getSpriteById(13),
      ExtraId.nuke_missile: _sheet.getSpriteById(15),
      ExtraId.smart_bomb: _sheet.getSpriteById(23),
      // Other extras:
      ExtraId.cooldown: _sheet.getSpriteById(18),
      ExtraId.integrity: _sheet.getSpriteById(16),
      ExtraId.shield: _sheet.getSpriteById(17),
    };
    _pool = ComponentRecycler<Extra>(() => Extra(sprites, sweep_anim));
    _pool.precreate(128);
  }
}

class Extra extends SpriteComponent with GameContext, Recyclable, WorldEntity {
  static const double lifetime = 8;
  static const double pulse_start = 5;

  final Map<ExtraId, Sprite> sprites;

  late ExtraId which;

  double _delay = 0;
  double _alive = 0;

  Extra(this.sprites, SpriteAnimation sweepAnim) {
    anchor = Anchor.center;
    sprite = sprites[ExtraId.values.first];
    size.x = sprite!.src.width;
    size.y = sprite!.src.height;

    _sweep = SpriteAnimationComponent(animation: sweepAnim, playing: true, removeOnFinish: false);
    _sweep.animation?.loop = false;

    add(_sweep);
    add(CircleHitbox(anchor: Anchor.center, isSolid: true, collisionType: CollisionType.passive)..anchor_to_parent());
  }

  late final SpriteAnimationComponent _sweep;
  double _sweep_cooldown = 0;

  void reset(ExtraId which, WorldEntity origin) {
    this.which = which;
    sprite = sprites[which];
    world_pos.setFrom(origin.world_pos);
    _delay = 0.01 + level_rng.nextDoubleLimit(0.3);
    scale.setAll(0);
    _alive = 0;
  }

  @override
  void onMount() {
    super.onMount();
    _reset_cooldown();
  }

  void _reset_cooldown() {
    _sweep.animationTicker?.reset();
    _sweep.animationTicker?.completed.then((_) {
      _sweep.playing = false;
      _sweep_cooldown = 1 + level_rng.nextDoubleLimit(0.2);
    });
  }

  @override
  void update(double dt) {
    super.update(dt);

    if (_delay > 0) {
      _delay = max(0, _delay - dt);
      if (_delay <= 0) {
        _find_spot();
        decals.spawn(DecalKind.teleport, this);
      }
      return;
    }

    _alive += dt;
    if (_alive > lifetime) {
      decals.spawn(DecalKind.teleport, this);
      recycle();
      return;
    }

    if (_alive > pulse_start) {
      final t = (_alive - pulse_start) * 6.0;
      final pulse = 1.0 + 0.13 * (0.5 + 0.5 * sin(t));
      scale.setAll(pulse);
    } else if (scale.x < 1) {
      scale.x = (scale.x + dt * 2).clamp(0, 1);
      scale.y = scale.x;
    }

    _sweep.opacity = _sweep_cooldown > 0 ? 0.0 : 1.0;
    if (_sweep_cooldown > 0) {
      _sweep_cooldown -= dt;
      if (_sweep_cooldown <= 0) _reset_cooldown();
    }

    if (scale.x < 1) {
      scale.x = (scale.x + dt * 2).clamp(0, 1);
      scale.y = scale.x;
    }
  }

  void _find_spot() {
    final ox = world_pos.x;
    final oy = world_pos.y;
    final others = world.children.whereType<Extra>();

    for (int attempts = 0; attempts < 10; attempts++) {
      final jump_dist = 16 + attempts * 4.0;
      for (int tries = 0; tries < 3; tries++) {
        if (!others.any((it) => it.position.distanceTo(position) < size.x)) {
          log_debug('Found spot for extra $which after $attempts attempts');
          return;
        }
        world_pos.x = ox + level_rng.nextDoubleLimit(jump_dist) - jump_dist / 2;
        world_pos.y = oy + level_rng.nextDoubleLimit(jump_dist) - jump_dist / 2;
      }
    }
  }

// @override
// void onCollision(Set<Vector2> intersectionPoints, PositionComponent other) {
//   super.onCollision(intersectionPoints, other);
//   if (recycled) return;
//   if (other == player && !player.is_destroyed) {
//     player.on_collect_extra(which);
//     recycle();
//   }
// }
}
