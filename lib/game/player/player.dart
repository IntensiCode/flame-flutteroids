import 'dart:math';
import 'dart:ui';

import 'package:flame/collisions.dart';
import 'package:flame/components.dart';
import 'package:flutteroids/core/common.dart';
import 'package:flutteroids/game/common/decals.dart';
import 'package:flutteroids/game/common/extra_id.dart';
import 'package:flutteroids/game/common/game_context.dart';
import 'package:flutteroids/game/common/game_phase.dart';
import 'package:flutteroids/game/common/kinds.dart';
import 'package:flutteroids/game/common/messages.dart';
import 'package:flutteroids/game/common/voxel_entity.dart';
import 'package:flutteroids/game/common/voxel_rotation.dart';
import 'package:flutteroids/game/player/deflector_shield.dart';
import 'package:flutteroids/game/player/weapon_system.dart';
import 'package:flutteroids/input/game_keys.dart';
import 'package:flutteroids/util/auto_dispose.dart';
import 'package:flutteroids/util/log.dart';
import 'package:flutteroids/util/mutable.dart';
import 'package:flutteroids/util/on_message.dart';

part 'player_debug.dart';
part 'player_movement.dart';
part 'player_uturn.dart';

enum _State {
  destroyed,
  exploding,
  inactive,
  playing,
  teleporting_in,
  teleporting_out,
}

extension GameContextExtensions on GameContext {
  AsteroidsPlayer get player => cache.putIfAbsent('player', () => AsteroidsPlayer());
}

class AsteroidsPlayer extends PositionComponent
    with
        AutoDispose,
        GameContext,
        HasVisibility,
        VoxelRotation,
        OnHit,
        Friendly,
        _PlayerMovement,
        _PlayerUTurn,
        _PlayerDebug,
        Player {
  //

  var state = _State.inactive;
  var state_time = 0.0;

  @override
  bool get weapons_hot => state == _State.playing && !is_turning;

  @override
  Vector2 get world_pos => position;

  @override
  double get integrity => remaining_hit_points / max_hit_points;

  late final weapon_system = WeaponSystem(this);
  late final deflector_shield = DeflectorShield(this, source_size: size);

  @override
  Future<void> onLoad() async {
    super.onLoad();
    size.setAll(32);
    anchor = Anchor.center;
    priority = 10;

    voxel = VoxelEntity(
      voxel_image: await images.load('voxel/manta19.png'),
      height_frames: 19,
      exhaust_color: Color(0xFFff0037),
      parent_size: size,
    );
    voxel.model_scale.setValues(0.8, 0.2, 0.8);
    voxel.exhaust_length = 2;

    await add(weapon_system..priority = 0);
    await add(voxel..priority = 10);
    await add(deflector_shield..priority = 20);

    await add(CircleHitbox(
      radius: size.x * 0.35,
      collisionType: CollisionType.passive,
    )
      ..position.setAll(size.x * 0.15)
      ..x += 4);

    voxel.set_exhaust_gradient(0, const Color(0xFF80ffff));
    voxel.set_exhaust_gradient(1, const Color(0xF000ffff));
    voxel.set_exhaust_gradient(2, const Color(0xE00080ff));
    voxel.set_exhaust_gradient(3, const Color(0xD00000ff));
    voxel.set_exhaust_gradient(4, const Color(0xC0000080));
  }

  @override
  void onMount() {
    super.onMount();
    on_message<GamePhaseUpdate>((msg) => _handle_game_phase(msg.phase));
    max_hit_points = remaining_hit_points = 100.0;
  }

  void _handle_game_phase(GamePhase phase) {
    state_time = 0.0;

    switch (phase) {
      case GamePhase.level_info:
        state = _State.inactive;
        isVisible = false;
      case GamePhase.entering_level:
        state = _State.inactive;
        isVisible = false;
      case GamePhase.playing_level:
        state = _State.teleporting_in;
        decals.spawn(DecalKind.teleport, this);
      case GamePhase.level_completed:
        state = _State.teleporting_out;
        decals.spawn(DecalKind.teleport, this);
      case GamePhase.game_over:
        state = _State.inactive;
        isVisible = false;
      case GamePhase.inactive:
        state = _State.inactive;
        isVisible = false;
    }

    log_debug('Player phase update: $state');
  }

  @override
  void update(double dt) {
    switch (state) {
      case _State.destroyed:
        return; // Skip _PlayerMovement.update

      case _State.exploding:
        if (hit_time > 0) {
          break;
        } else if (state_time < 1.0) {
          state_time += dt;
          voxel.exploding = state_time;
        } else {
          state = _State.inactive;
          removeAll(children);
          send_message(PlayerDestroyed(game_over: true));
          return; // Skip _PlayerMovement.update
        }

      case _State.inactive:
        return; // Skip _PlayerMovement.update

      case _State.playing:
        break;

      case _State.teleporting_in:
        state_time += dt;
        isVisible = state_time >= 0.5;

        if (state_time >= 1.0) {
          state = _State.playing;
          send_message(PlayerReady());
        } else if (state_time <= 0.5) {
          return; // Skip _PlayerMovement.update
        }

      case _State.teleporting_out:
        state_time += dt;
        isVisible = state_time <= 0.5;

        if (state_time >= 1.0) {
          state = _State.inactive;
          send_message(PlayerLeft());
        } else if (state_time >= 0.25) {
          return; // Skip _PlayerMovement.update
        }
    }

    super.update(dt);

    voxel.render_mode = hit_time > 0 ? 1 : 0;
  }

  @override
  bool get susceptible => state == _State.playing && !is_elevated;

  @override
  void on_hit(double damage) {
    if (is_destroyed) return;

    super.on_hit(damage);

    if (is_destroyed) {
      removeWhere((it) => it is CircleHitbox);
      remaining_hit_points = 0;
      state = _State.exploding;
      state_time = 0.0;
      voxel.exploding = 0.0;
    }
  }

  @override
  void on_collect_extra(ExtraId which) {
    log_warn('Player collected extra: $which');
    switch (which) {
      case ExtraId.plasma_gun:
        weapon_system.on_weapon(which);
      case ExtraId.ion_pulse:
        weapon_system.on_weapon(which);
      case ExtraId.auto_laser:
        weapon_system.on_weapon(which);
      case ExtraId.plasma_ring:
        weapon_system.on_weapon(which);
      case ExtraId.nuke_missile:
        weapon_system.on_weapon(which);
      case ExtraId.smart_bomb:
        weapon_system.on_weapon(which);

      case ExtraId.integrity:
        remaining_hit_points = (remaining_hit_points + max_hit_points / 4).clamp(0, max_hit_points);
      case ExtraId.shield:
        deflector_shield.on_energy_boost();
      case ExtraId.cooldown:
        weapon_system.on_cooldown();
    }
    send_message(ExtraCollected(which));
  }
}
