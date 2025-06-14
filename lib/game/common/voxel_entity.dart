import 'dart:math';
import 'dart:ui';

import 'package:flame/components.dart';
import 'package:flame/extensions.dart';
import 'package:flutteroids/core/common.dart';
import 'package:flutteroids/game/common/configuration.dart';
import 'package:flutteroids/util/mutable.dart';
import 'package:flutteroids/util/pixelate.dart';
import 'package:flutteroids/util/uniforms.dart';

class VoxelEntity extends PositionComponent with HasPaint {
  final _shader_rect = MutRect(0, 0, 0, 0);
  final _dst_rect = MutRect(0, 0, 0, 0);

  static final Matrix4 _scale_matrix = Matrix4.identity();
  static final Matrix4 _transform = Matrix4.identity();
  static final Matrix4 _inverse = Matrix4.identity();

  Image? _exhaust_buffer;

  late final int _frames;
  late final Image _voxel_atlas;
  late final Color _exhaust_color;
  late final double _exhaust_color_variance;
  late final FragmentShader _shader;
  late final FragmentShader _exhaust_shader;
  late final FragmentShader _exploding_shader;
  late final UniformsExt<Voxel3dUniform> _uniforms;
  late final UniformsExt<ExhaustUniform> _exhaust_uniforms;
  late final UniformsExt<Voxel3dExplodingUniform> _exploding_uniforms;

  final _paint = pixel_paint();

  double _exhaust_anim = 0.0;

  var voxel_pixel_size = 64;
  var exhaust_length = 8.0;
  var render_mode = 0.0; // 0=normal, 1=hit (white), 2=shadow (black)
  var exploding = 0.0; // If > 0, uses exploding shader with this value as time

  final model_scale = Vector3.all(1.0);
  final orientation_matrix = Matrix3.identity();
  final light_direction = Vector3(0.5, 0.75, -1.0)..normalize();

  final Vector2 parent_size;

  VoxelEntity({
    required Image voxel_image,
    required int height_frames,
    required Color exhaust_color,
    required this.parent_size,
    double exhaust_color_variance = 0.1,
  }) {
    _frames = height_frames;
    _voxel_atlas = voxel_image;
    _exhaust_color = exhaust_color;
    _exhaust_color_variance = exhaust_color_variance;
  }

  void set_exhaust_gradient(int index, Color color) {
    final first = ExhaustUniform.color0.index;
    _exhaust_uniforms[ExhaustUniform.values[first + index]] = color;
  }

  @override
  Future<void> onLoad() async => await _init_shaders();

  Future<void> _init_shaders() async {
    _shader = await load_shader('voxel3d.frag');
    _exhaust_shader = await load_shader('exhaust.frag');
    _exhaust_shader.setImageSampler(0, _voxel_atlas);
    _exploding_shader = await load_shader('voxel3d_exploding.frag');
    _exploding_shader.setImageSampler(0, _voxel_atlas);

    _uniforms = UniformsExt<Voxel3dUniform>(_shader, {
      for (final e in Voxel3dUniform.values) e: e.type,
    });
    _exhaust_uniforms = UniformsExt<ExhaustUniform>(_exhaust_shader, {
      for (final e in ExhaustUniform.values) e: e.type,
    });
    _exploding_uniforms = UniformsExt<Voxel3dExplodingUniform>(_exploding_shader, {
      for (final e in Voxel3dExplodingUniform.values) e: e.type,
    });

    _init_voxel_uniforms();
    _init_exhaust_uniforms();
    _init_exploding_uniforms();
  }

  void _init_voxel_uniforms() {
    final atlas_size = _voxel_atlas.size;
    final frame_size = Vector2(atlas_size.x, atlas_size.y / _frames);
    _uniforms
      ..[Voxel3dUniform.dst_origin] = Vector2.zero()
      ..[Voxel3dUniform.atlas_size] = atlas_size
      ..[Voxel3dUniform.frames] = _frames.toDouble()
      ..[Voxel3dUniform.frame_size] = frame_size;
  }

  void _init_exploding_uniforms() {
    final atlas_size = _voxel_atlas.size;
    final frame_size = Vector2(atlas_size.x, atlas_size.y / _frames);
    _exploding_uniforms
      ..[Voxel3dExplodingUniform.dst_origin] = Vector2.zero()
      ..[Voxel3dExplodingUniform.atlas_size] = atlas_size
      ..[Voxel3dExplodingUniform.frames] = _frames.toDouble()
      ..[Voxel3dExplodingUniform.frame_size] = frame_size;
  }

  void _init_exhaust_uniforms() => _exhaust_uniforms
    ..[ExhaustUniform.resolution] = _voxel_atlas.size
    ..[ExhaustUniform.target_color] = _exhaust_color
    ..[ExhaustUniform.color_variance] = _exhaust_color_variance
    ..[ExhaustUniform.color0] = const Color(0xFFff0000)
    ..[ExhaustUniform.color1] = const Color(0xFFffff00)
    ..[ExhaustUniform.color2] = const Color(0xFFff0000)
    ..[ExhaustUniform.color3] = const Color(0xFF800000)
    ..[ExhaustUniform.color4] = const Color(0xFF800000);

  @override
  void update(double dt) {
    if (exploding == 0.0) _exhaust_anim += dt;
  }

  @override
  void render(Canvas canvas) {
    final size = parent_size;
    voxel_pixel_size = min(size.x, size.y).toInt().clamp(16, 256);

    _dst_rect.setSize(size.x, size.y);

    if (~exhaust_anim) _render_exhaust();

    _render_model(canvas);
  }

  void _render_exhaust() {
    _exhaust_buffer?.dispose();
    _exhaust_buffer = pixelate(_voxel_atlas.width, _voxel_atlas.height, (canvas) {
      final len = exploding > 0.0 ? 0.0 : exhaust_length;
      _exhaust_uniforms[ExhaustUniform.exhaust_length] = len;
      _exhaust_uniforms[ExhaustUniform.time] = _exhaust_anim;
      _paint.shader = _exhaust_shader;
      _shader_rect.setFromImage(_voxel_atlas);
      canvas.drawRect(_shader_rect, _paint);
      _paint.shader = null;
    });
  }

  void _render_model(Canvas canvas) {
    final bool is_exploding = exploding > 0.0;
    final active_shader = is_exploding ? _exploding_shader : _shader;

    _updateUniforms(active_shader, is_exploding);
    _paint.shader = active_shader;
    _paint.color = const Color(0xFFffffff);
    canvas.drawRect(_dst_rect, _paint);
  }

  final _tmp_vector = Vector2.zero();

  void _updateUniforms(FragmentShader shader, bool is_exploding) {
    _scale_matrix.setIdentity();
    _scale_matrix.scale(model_scale);
    _transform.setIdentity();
    _transform.setRotation(orientation_matrix);
    _transform.multiply(_scale_matrix);
    _inverse.copyInverse(_transform);

    _tmp_vector.setAll(voxel_pixel_size.toDouble());

    if (is_exploding) {
      _exploding_uniforms
        ..[Voxel3dExplodingUniform.dst_size] = _tmp_vector
        ..[Voxel3dExplodingUniform.model_matrix_inverse] = _inverse
        ..[Voxel3dExplodingUniform.explode_time] = exploding;
      shader.setImageSampler(0, _exhaust_buffer ?? _voxel_atlas);
    } else {
      _uniforms
        ..[Voxel3dUniform.dst_size] = _tmp_vector
        ..[Voxel3dUniform.light_direction] = light_direction
        ..[Voxel3dUniform.model_matrix_inverse] = _inverse
        ..[Voxel3dUniform.render_mode] = render_mode;
      shader.setImageSampler(0, _exhaust_buffer ?? _voxel_atlas);
    }
  }
}

enum Voxel3dUniform {
  dst_origin(Vector2),
  dst_size(Vector2),
  atlas_size(Vector2),
  frames(double),
  frame_size(Vector2),
  model_matrix_inverse(Matrix4),
  light_direction(Vector3),
  render_mode(double);

  final Type type;

  const Voxel3dUniform(this.type);
}

enum Voxel3dExplodingUniform {
  dst_origin(Vector2),
  dst_size(Vector2),
  atlas_size(Vector2),
  frames(double),
  frame_size(Vector2),
  model_matrix_inverse(Matrix4),
  explode_time(double);

  final Type type;

  const Voxel3dExplodingUniform(this.type);
}

enum ExhaustUniform {
  resolution(Vector2),
  time(double),
  target_color(Color),
  color_variance(double),
  exhaust_length(double),
  color0(Color),
  color1(Color),
  color2(Color),
  color3(Color),
  color4(Color);

  final Type type;

  const ExhaustUniform(this.type);
}
