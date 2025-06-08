import 'dart:math'; // For min, sin, cos, atan2
import 'dart:ui';

import 'package:flame/collisions.dart';
import 'package:flame/components.dart';
import 'package:flutteroids/core/common.dart';
import 'package:flutteroids/game/common/kinds.dart';
import 'package:flutteroids/game/projectiles/directional_projectile.dart';
import 'package:flutteroids/game/world/world_entity.dart';
import 'package:flutteroids/util/component_recycler.dart';
import 'package:flutteroids/util/log.dart';
import 'package:flutteroids/util/mutable.dart';
import 'package:flutteroids/util/random.dart';
import 'package:flutteroids/util/uniforms.dart';

class PlasmaBlob extends PositionComponent
    with CollisionCallbacks, Recyclable, WorldEntity, DirectionalProjectile, HasPaint {
  //

  static Future<FragmentShader>? await_shader;
  static FragmentShader? _shader;

  static Future<FragmentShader> preload() {
    log_verbose('preload plasma blob shader');
    return PlasmaBlob.await_shader ??= load_shader('plasma_blob.frag');
  }

  static const double _homing_duration = 1.0;

  final Function(WorldEntity, int) _emit_plasma_ring;

  final _rect = MutRect.zero();
  final _shade = pixel_paint();

  double _initial_angle = 0.0;
  double? _angle_change;
  double _homing_progress = 0.0;
  double _anim_time = level_rng.nextDoubleLimit(10);
  int _boost = 0;

  PlasmaBlob(this._emit_plasma_ring) {
    anchor = Anchor.center;
    size.setAll(16);
    add(CircleHitbox(radius: 10, anchor: Anchor.center, position: size / 2, isSolid: true));

    paint.filterQuality = FilterQuality.none;
    paint.isAntiAlias = false;

    _shade.filterQuality = FilterQuality.none;
    _shade.isAntiAlias = false;
  }

  void reset_homing(Target origin, double angle, {double? target_angle, int boost = 0}) {
    super.reset(origin, angle);
    _boost = boost;

    _initial_angle = angle % (2 * pi);
    _homing_progress = 0.0;

    if (target_angle != null) {
      // Calculate the shortest angular distance
      var angle_diff = target_angle - _initial_angle;

      // Wrap the difference to [-π, π] range
      while (angle_diff > pi) angle_diff -= 2 * pi;
      while (angle_diff < -pi) angle_diff += 2 * pi;

      _angle_change = angle_diff;
    }

    _anim_time = level_rng.nextDoubleLimit(10);
    max_distance = DirectionalProjectile.world_size();
  }

  @override
  double get base_speed => 200;

  @override
  onLoad() {
    await_shader ??= PlasmaBlob.preload();
    return await_shader!.then((it) => _shader = it);
  }

  @override
  void update(double dt) {
    super.update(dt);
    _anim_time += dt;
    if (_angle_change != null && _homing_progress < 1.0) {
      _lerp_towards_target_angle(dt);
    }
  }

  void _lerp_towards_target_angle(double dt) {
    _homing_progress += dt / _homing_duration;
    _homing_progress = min(1.0, _homing_progress);
    set_direction_angle(_initial_angle + _angle_change! * _homing_progress);
  }

  @override
  void render(Canvas canvas) {
    final shader = _shader;
    if (shader == null) return;
    _shade.shader ??= shader;
    _rect.right = size.x;
    _rect.bottom = size.y;
    shader.setFloat(0, _rect.width);
    shader.setFloat(1, _rect.height);
    shader.setFloat(2, _anim_time);
    canvas.drawRect(_rect, _shade);
  }

  @override
  void onCollision(Set<Vector2> intersectionPoints, PositionComponent other) {
    super.onCollision(intersectionPoints, other);
    if (recycled) return;
    if (other case Hostile it when it.susceptible) {
      final dmg = 20 + (10 * (_boost / SecondaryWeapon.max_boosts));
      final hit_point = it.calculate_hit_point(it, intersectionPoints);
      it.on_hit(dmg, hit_point);
      _emit_plasma_ring(this, _boost);
      recycle();
    }
  }
}
