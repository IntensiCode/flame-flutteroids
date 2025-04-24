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
import 'package:flutteroids/util/pixelate.dart';
import 'package:flutteroids/util/random.dart';
import 'package:flutteroids/util/uniforms.dart';

class PlasmaBlob extends PositionComponent
    with CollisionCallbacks, Recyclable, WorldEntity, DirectionalProjectile, HasPaint {
  //

  static Future<FragmentShader>? await_shader;
  static FragmentShader? _shader;

  static Future<FragmentShader> preload() {
    log_info('preload plasma blob shader');
    return PlasmaBlob.await_shader ??= load_shader('plasma_blob.frag');
  }

  PlasmaBlob(this._emit_plasma_ring) {
    anchor = Anchor.center;
    size.setAll(16);
    add(CircleHitbox(radius: 10, anchor: Anchor.center, position: size / 2, isSolid: true));

    paint.filterQuality = FilterQuality.none;
    paint.isAntiAlias = false;

    _shade.filterQuality = FilterQuality.none;
    _shade.isAntiAlias = false;
  }

  final Function(WorldEntity) _emit_plasma_ring;

  final _shade = Paint();

  @override
  double get base_speed => 200;

  double _anim_time = level_rng.nextDoubleLimit(10);

  @override
  void reset(Player origin, double angle) {
    super.reset(origin, angle);
    _anim_time = level_rng.nextDoubleLimit(10);
    _img?.dispose();
    _img = null;
  }

  @override
  onLoad() {
    await_shader ??= PlasmaBlob.preload();
    return await_shader!.then((it) => _shader = it);
  }

  @override
  void update(double dt) {
    super.update(dt);
    _anim_time += dt;
  }

  Image? _img;

  @override
  void render(Canvas canvas) {
    final shader = _shader;
    if (shader == null) return;

    _img?.dispose();
    _img = pixelate(_rect.width.toInt(), _rect.height.toInt(), (it) {
      shader.setFloat(0, _rect.width);
      shader.setFloat(1, _rect.height);
      shader.setFloat(2, _anim_time);
      _shade.shader ??= shader;
      it.drawRect(_rect, _shade);
    });

    _scaled.right = size.x;
    _scaled.bottom = size.y;
    canvas.drawImageRect(_img!, _rect, _scaled, paint);
  }

  final _rect = Rect.fromLTWH(0, 0, 24, 24);
  final _scaled = MutRect.zero();

  @override
  void onCollision(Set<Vector2> intersectionPoints, PositionComponent other) {
    super.onCollision(intersectionPoints, other);
    if (recycled) return;
    if (other case Hostile it when it.susceptible) {
      it.on_hit(20);
      _emit_plasma_ring(this);
      recycle();
    }
  }
}
