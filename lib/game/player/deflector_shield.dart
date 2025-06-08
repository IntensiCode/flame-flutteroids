import 'dart:math';
import 'dart:ui';

import 'package:flame/collisions.dart';
import 'package:flame/components.dart';
import 'package:flutteroids/core/common.dart';
import 'package:flutteroids/core/traits.dart';
import 'package:flutteroids/game/common/decals.dart';
import 'package:flutteroids/game/common/game_context.dart';
import 'package:flutteroids/game/common/kinds.dart';
import 'package:flutteroids/game/common/messages.dart';
import 'package:flutteroids/game/common/sound.dart';
import 'package:flutteroids/util/extensions.dart';
import 'package:flutteroids/util/mutable.dart';
import 'package:flutteroids/util/uniforms.dart';

class DeflectorShield extends PositionComponent with GameContext, HasPaint, HasTraits, Target, Friendly {
  //

  static final _paint = pixel_paint();

  final Target carrier;
  late final FragmentShader _shader;

  double _energy = 1;
  double _deflect_time = 0;
  double _rotate_time = 0;
  double auto_recharge = 0.2;
  double shield_boost = 1.0;
  double shield_factor = 50;

  double get energy => _energy;

  @override
  Vector2 get velocity => carrier.velocity;

  @override
  Vector2 get world_pos => carrier.world_pos;

  @override
  Vector2 get world_size => size;

  @override
  double get integrity => _energy.clamp(0, 1);

  @override
  bool get susceptible => _energy > 0.1 && carrier.susceptible;

  @override
  double get remaining_hit_points => carrier.remaining_hit_points;

  @override
  double get max_hit_points => carrier.max_hit_points;

  DeflectorShield(this.carrier, {required Vector2 source_size}) {
    size = source_size;
    size.scale(2.0);

    anchor = Anchor.center;
    anchor_to_parent();

    final shader_factor = 0.875;
    add(CircleHitbox(
      radius: size.x / 2 * shader_factor,
      anchor: Anchor.center,
      isSolid: true,
      collisionType: CollisionType.passive,
    )..anchor_to_parent());

    paint.isAntiAlias = false;
    paint.filterQuality = FilterQuality.none;
    priority = -1;
  }

  void on_energy_boost() => _energy = min(1, _energy + 0.25);

  @override
  onLoad() async {
    _shader = await load_shader('plasma_shield.frag');
    _paint.shader = _shader;
    priority = 1;
  }

  @override
  void update(double dt) {
    super.update(dt);
    if (carrier.is_destroyed) {
      _deflect_time = 0;
      _energy = 0;
      return;
    }

    _energy = min(1, _energy + dt * auto_recharge);
    if (_deflect_time > 0) {
      _deflect_time -= dt;
      _rotate_time += dt;
      _rotate_time %= 0.25;
    }

    _shader.setFloat(0, size.x);
    _shader.setFloat(1, size.y);
    _shader.setFloat(4, _rotate_time);
  }

  @override
  void spawn_damage_decals(double damage, Vector2 hit_point) {
    decals.spawn(DecalKind.smoke, this, pos_override: hit_point);
  }

  @override
  void on_hit(double damage, Vector2 hit_point) {
    if (carrier case HasVisibility it) {
      if (!it.isVisible) return;
    }

    if (susceptible) {
      _deflect_time = 0.3;
      _energy -= damage / shield_factor / shield_boost;

      if (_energy < 0) {
        _on_depleted();
      } else if (damage >= 1) {
        // play_sound(Sound.teleport, volume_factor: 0.25);
        // send_message(Rumble(duration: 0.2, haptic: false));
      }

      play_sound(Sound.plasma, volume_factor: 0.25);
    } else {
      carrier.on_hit(damage, hit_point);
    }
  }

  void _on_depleted() {
    final danger = 5;
    final remaining = max(0.0, _energy.abs() - 5);
    // Use the shield's position as hit point since this is shield depletion damage
    carrier.on_hit(remaining * danger, world_pos);
    _energy = max(-5, _energy / 10);

    send_message(Rumble(duration: 0.2, haptic: false));
    // play_sound(Sound.emit, volume_factor: 0.25);
    // play_sound(Sound.plasma, volume_factor: 0.25);
  }

  final _rect = MutRect(0, 0, 0, 0);

  @override
  void render(Canvas canvas) {
    if (_deflect_time <= 0) return;

    _rect.right = size.x;
    _rect.bottom = size.y;
    canvas.drawRect(_rect, _paint);
  }
}
