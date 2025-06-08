import 'dart:math';
import 'dart:ui';

import 'package:flame/collisions.dart';
import 'package:flame/components.dart';
import 'package:flutteroids/core/common.dart';
import 'package:flutteroids/game/common/configuration.dart';
import 'package:flutteroids/game/common/decals.dart';
import 'package:flutteroids/game/common/explosions.dart';
import 'package:flutteroids/game/common/extra_id.dart';
import 'package:flutteroids/game/common/extras.dart';
import 'package:flutteroids/game/common/game_context.dart';
import 'package:flutteroids/game/common/game_phase.dart';
import 'package:flutteroids/game/common/kinds.dart';
import 'package:flutteroids/game/common/messages.dart';
import 'package:flutteroids/game/common/sound.dart';
import 'package:flutteroids/game/common/target_collisions.dart';
import 'package:flutteroids/game/common/voxel_entity.dart';
import 'package:flutteroids/game/common/voxel_rotation.dart';
import 'package:flutteroids/game/player/deflector_shield.dart';
import 'package:flutteroids/game/player/weapon_system.dart';
import 'package:flutteroids/input/game_keys.dart';
import 'package:flutteroids/util/auto_dispose.dart';
import 'package:flutteroids/util/component_recycler.dart';
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
        Target,
        CollisionCallbacks,
        Recyclable,
        TargetCollisions,
        Friendly,
        _PlayerMovement,
        _PlayerUTurn,
        _PlayerDebug,
        Player {
  //

  var state = _State.inactive;
  var state_time = 0.0;
  var jumping_countdown = 0.0;

  var score = 0;

  @override
  bool get weapons_hot => state == _State.playing && !is_turning;

  @override
  Vector2 get world_pos => v2z_; // position;

  @override
  Vector2 get world_size => size;

  @override
  double get integrity => remaining_hit_points / max_hit_points;

  late final weapon_system = WeaponSystem(this);
  late final deflector_shield = DeflectorShield(this, source_size: size);

  @override
  void spawn_damage_decals(double damage, Vector2 hit_point) {
    decals.spawn(DecalKind.mini_explosion, this, pos_override: hit_point, pos_range: size.x / 3);
  }

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
      collisionType: CollisionType.active,
      isSolid: true, // better? for projectiles?
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
    on_message<AsteroidDestroyed>((msg) => score += msg.asteroid.asteroid_radius.toInt());
    on_message<AsteroidFieldCleared>((_) => _on_jumping());
    on_message<AsteroidSplit>((msg) => score += msg.asteroid.asteroid_radius.toInt() ~/ 5);
    on_message<GamePhaseUpdate>((msg) => _handle_game_phase(msg.phase));
    max_hit_points = remaining_hit_points = 100.0;
  }

  void _on_jumping() {
    jumping_countdown = 5.0;
    play_one_shot('voice/jumping');
  }

  void _handle_game_phase(GamePhase phase) {
    state_time = 0.0;
    jumping_countdown = 0.0;

    switch (phase) {
      case GamePhase.level_info:
        state = _State.inactive;
        isVisible = false;
        _reset_position();
      case GamePhase.enter_level:
        state = _State.inactive;
        isVisible = false;
      case GamePhase.play_level:
        state = _State.teleporting_in;
        decals.spawn(DecalKind.teleport, this);
        play_sound(Sound.teleport_long);
      case GamePhase.level_complete:
        state = _State.playing;
        isVisible = true;
      case GamePhase.level_bonus:
        state = _State.inactive;
        isVisible = false;
        _reset_position();
      case GamePhase.game_over:
        state = _State.inactive;
        isVisible = false;
      case GamePhase.inactive:
        state = _State.inactive;
        isVisible = false;
    }

    log_debug('Player phase update: $state');
  }

  void _reset_position() {
    position.setZero();
    velocity.setZero();
    movement_angle = -pi / 2;
  }

  @override
  void update(double dt) {
    switch (state) {
      case _State.destroyed:
        return; // Skip _PlayerMovement.update

      case _State.exploding:
        if (hit_time > 0) {
          break;
        } else if (state_time < 2.0) {
          state_time += dt;
          voxel.exploding = min(1.0, state_time);
          return; // Skip _PlayerMovement.update
        } else {
          state = _State.inactive;
          removeAll(children);
          send_message(PlayerDestroyed(game_over: true));
          return; // Skip _PlayerMovement.update
        }

      case _State.inactive:
        return; // Skip _PlayerMovement.update

      case _State.playing:
        remaining_hit_points = min(remaining_hit_points + 1 * dt, max_hit_points);

        if (jumping_countdown > 0) {
          jumping_countdown = max(0, jumping_countdown - dt);
          if (jumping_countdown <= 0) {
            state = _State.teleporting_out;
            decals.spawn(DecalKind.teleport, this);
            play_sound(Sound.teleport_long);
            send_message(PlayerLeft());
            return; // Skip _PlayerMovement.update
          }
        }
        break;

      case _State.teleporting_in:
        state_time += dt;
        isVisible = state_time >= 0.5;

        if (state_time >= 1.0) {
          state = _State.playing;
          send_message(PlayerReady());
          log_debug('Player is ready');
        } else if (state_time <= 0.5) {
          return; // Skip _PlayerMovement.update
        }

      case _State.teleporting_out:
        state_time += dt;
        isVisible = state_time <= 0.05;

        if (state_time >= 1.0) {
          state = _State.inactive;
          send_message(PlayerLeft());
          log_debug('Player left the game');
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
  void on_hit(double damage, Vector2 hit_point) {
    if (is_destroyed) return;

    super.on_hit(damage, hit_point);

    if (is_destroyed) {
      removeWhere((it) => it is CircleHitbox);
      remaining_hit_points = 0;
      state = _State.exploding;
      state_time = 0.0;
      voxel.exploding = 0.0;
      add(explosions.spawn(this, scale: 2.0)..priority = 30);
      play_sound(Sound.explosion);
    }
  }

  @override
  void on_collect_extra(ExtraId which) {
    log_debug('Player collected extra: $which');
    score += 10;
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

  @override
  void onCollisionStart(Set<Vector2> intersectionPoints, PositionComponent other) {
    super.onCollisionStart(intersectionPoints, other);

    if (!isVisible || state != _State.playing) return;

    if (other case Enemy it when it.susceptible) {
      log_debug('Collision: ${it.runtimeType} Taking: ${it.remaining_hit_points} Dealing: $remaining_hit_points');
      final hit_point = calculate_hit_point(it, intersectionPoints);
      on_hit(it.remaining_hit_points, hit_point);
      it.on_hit(remaining_hit_points, hit_point);
    }

    if (other case Extra it when !it.recycled) {
      log_debug('Collision: Extra $it');
      on_collect_extra(it.which);
      it.recycle();
    }
  }
}
