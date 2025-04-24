import 'dart:math';
import 'dart:ui';

import 'package:flame/components.dart';
import 'package:flutteroids/core/common.dart';
import 'package:flutteroids/util/mutable.dart';
import 'package:flutteroids/util/uniforms.dart';

enum _Uniform {
  resolution(Vector2),
  mouse(Vector2),
  hash(double),
  ;

  final Type type;

  const _Uniform(this.type);
}

mixin AsteroidRendering on PositionComponent {
  FragmentShader? _shader;
  UniformsExt<_Uniform>? _uniforms;
  Paint? _shader_paint;

  final _shader_rect = MutRect.zero();
  final _resolution = Vector2.zero();

  final shader_rot_pos = Vector2.zero();
  final shader_rot_speed = Vector2.zero();

  double asteroid_hash = 0;

  double get asteroid_radius;

  @override
  Future<void> onLoad() async {
    super.onLoad();
    anchor = Anchor.center;
    await _load_rock_shader();
  }

  Future<void> _load_rock_shader() async {
    _shader ??= await load_shader('asteroid.frag');
    _uniforms ??= UniformsExt<_Uniform>(_shader!, {
      for (final e in _Uniform.values) e: e.type,
    });
    _shader_paint ??= pixel_paint()
      ..color = white
      ..shader = _shader;
  }

  @override
  void update(double dt) {
    super.update(dt);
    shader_rot_pos.x += shader_rot_speed.x * dt;
    shader_rot_pos.y += shader_rot_speed.y * dt;
  }

  @override
  void render(Canvas canvas) {
    final shader_size = asteroid_radius;

    _shader_rect.left = 0;
    _shader_rect.top = 0;
    _shader_rect.right = shader_size * 1.5;
    _shader_rect.bottom = shader_size * 1.5;

    _resolution.setValues(shader_size * 1.5, shader_size * 1.5);
    _uniforms!.set(_Uniform.resolution, _resolution);
    _uniforms!.set(_Uniform.mouse, shader_rot_pos);
    _uniforms!.set(_Uniform.hash, asteroid_hash);

    canvas.translate(-shader_size * 0.25, -shader_size * 0.25);
    canvas.drawRect(_shader_rect, _shader_paint!);
    canvas.translate(shader_size * 0.25, shader_size * 0.25);
  }
}
