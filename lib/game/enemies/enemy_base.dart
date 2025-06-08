import 'dart:math';

import 'package:flame/collisions.dart';
import 'package:flame/components.dart';
import 'package:flutteroids/game/common/decals.dart';
import 'package:flutteroids/game/common/explosions.dart';
import 'package:flutteroids/game/common/extra_id.dart';
import 'package:flutteroids/game/common/extras.dart';
import 'package:flutteroids/game/common/game_context.dart';
import 'package:flutteroids/game/common/game_phase.dart';
import 'package:flutteroids/game/common/health_bar.dart';
import 'package:flutteroids/game/common/kinds.dart';
import 'package:flutteroids/game/common/messages.dart';
import 'package:flutteroids/game/common/sound.dart';
import 'package:flutteroids/game/common/target_collisions.dart';
import 'package:flutteroids/game/common/voxel_rotation.dart';
import 'package:flutteroids/game/world/world_entity.dart';
import 'package:flutteroids/util/auto_dispose.dart';
import 'package:flutteroids/util/component_recycler.dart';
import 'package:flutteroids/util/log.dart';
import 'package:flutteroids/util/on_message.dart';

enum EnemyState {
  destroyed,
  exploding,
  inactive,
  playing,
  teleporting_in,
  teleporting_out,
}

abstract class EnemyBase extends PositionComponent
    with
        AutoDispose,
        GameContext,
        Recyclable,
        WorldEntity,
        HasVisibility,
        VoxelRotation,
        Target,
        CollisionCallbacks,
        TargetCollisions,
        Hostile,
        Enemy {
  //

  EnemyBase() {
    size.setAll(32);
    anchor = Anchor.center;
  }

  late final health_bar = HealthBar(this);

  var spawning = <ExtraId>{};
  var spawn_count = 1;

  var state = EnemyState.inactive;
  var state_time = 0.0;

  @override
  Vector2 get world_size => size;

  @override
  bool get susceptible => state == EnemyState.playing;

  @override
  void spawn_damage_decals(double damage, Vector2 hit_point) {
    decals.spawn(DecalKind.mini_explosion, this, pos_override: hit_point, pos_range: size.x / 3);
  }

  @override
  void on_hit(double damage, Vector2 hit_point) {
    if (is_destroyed) return;
    super.on_hit(damage, hit_point);
    if (is_destroyed) on_destroyed();
  }

  void on_destroyed() {
    state = EnemyState.exploding;
    state_time = 0.0;
    voxel.exploding = 0.0;

    add(explosions.spawn(this, scale: 2.0)..priority = 30);
    extras.spawn_multi(this, choices: spawning, count: spawn_count);

    play_sound(Sound.explosion);
  }

  @override
  get recycle => () {
        log_debug('$runtimeType recycled');
        removeWhere((it) => it is Explosion);
        removeFromParent();
        health_bar.reset();
        recycled = true;
      };

  @override
  Future<void> onLoad() async {
    super.onLoad();
    if (children.isNotEmpty) return;
    await on_load_once();
  }

  Future on_load_once();

  @override
  void onMount() {
    super.onMount();

    recycled = false;
    isVisible = false;
    max_hit_points = remaining_hit_points = 100.0;

    on_message<GamePhaseUpdate>((msg) => _handle_game_phase(msg.phase));
    on_message<AsteroidFieldCleared>((_) => _on_jumping());

    _handle_game_phase(stage.phase);

    log_debug('$runtimeType mounted');
  }

  void _on_jumping() {
    state = EnemyState.teleporting_out;
    decals.spawn(DecalKind.teleport, this);
    play_sound(Sound.teleport_long);
  }

  void _handle_game_phase(GamePhase phase) {
    log_debug('UFO Enemy phase update: $phase');

    state_time = 0.0;

    switch (phase) {
      case GamePhase.level_info:
      case GamePhase.level_bonus:
      case GamePhase.inactive:
        state = EnemyState.inactive;
        isVisible = false;

      case GamePhase.enter_level:
        state = EnemyState.inactive;
        isVisible = false;

      case GamePhase.play_level:
        on_pick_start_position();
        state = EnemyState.teleporting_in;
        decals.spawn(DecalKind.teleport, this);
        play_sound(Sound.teleport_long);

      case GamePhase.level_complete:
      case GamePhase.game_over:
        // Keep current state. Assuming we were in playing state. Dev keys may mess this up.
        break;
    }

    log_debug('UFO Enemy phase update: $state');
  }

  void on_pick_start_position();

  @override
  void update(double dt) {
    switch (state) {
      case EnemyState.destroyed:
        return;

      case EnemyState.exploding:
        if (hit_time > 0) {
          break;
        } else if (state_time < 2.0) {
          state_time += dt;
          voxel.exploding = min(1.0, state_time);
          return;
        } else {
          state = EnemyState.inactive;
          recycle();
          return;
        }

      case EnemyState.inactive:
        return;

      case EnemyState.playing:
        on_playing(dt);

      case EnemyState.teleporting_in:
        state_time += dt;
        isVisible = state_time >= 0.5;

        if (state_time >= 1.0) {
          state = EnemyState.playing;
          log_debug('$runtimeType is ready');
        } else if (state_time <= 0.5) {
          return;
        }

      case EnemyState.teleporting_out:
        state_time += dt;
        isVisible = state_time <= 0.5;

        if (state_time >= 1.0) {
          state = EnemyState.inactive;
          recycle();
          log_debug('$runtimeType left the game');
        } else if (state_time >= 0.25) {
          return;
        }
    }

    super.update(dt);

    voxel.render_mode = hit_time > 0 ? 1 : 0;
  }

  void on_playing(double dt);
}
