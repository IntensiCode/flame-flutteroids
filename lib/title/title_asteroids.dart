import 'dart:math';
import 'dart:ui';

import 'package:flame/collisions.dart';
import 'package:flame/components.dart';
import 'package:flutteroids/core/common.dart';
import 'package:flutteroids/util/mutable.dart';
import 'package:flutteroids/util/random.dart';
import 'package:flutteroids/util/uniforms.dart';

class TitleAsteroids extends Component with HasCollisionDetection<Sweep<ShapeHitbox>> {
  static const asteroids_count = 16;

  @override
  Future<void> onLoad() async {
    super.onLoad();
    while (children.length < asteroids_count) {
      add(TitleAsteroid()..reset());
    }
  }
}

class TitleAsteroid extends PositionComponent {
  static final _rng = Random();

  final _shader_rot_pos = Vector2.zero();
  final _shader_rot_speed = Vector2.zero();
  final _shader_rect = MutRect.zero();
  final _resolution = Vector2.zero();
  final _velocity = Vector2.zero();
  final _paint = pixel_paint();

  double _hash = 0.0;

  late FragmentShader _shader;
  late UniformsExt<_Uniform> _uniforms;

  void reset() {
    _hash = _rng.nextDoubleLimit(800);

    size.setAll(20 + _rng.nextDouble() * 20);
    _resolution.setValues(size.x * 1.5, size.y * 1.5);
    _shader_rect.right = size.x * 1.5;
    _shader_rect.bottom = size.y * 1.5;

    x = _rng.nextDoubleLimit(game_size.x);
    y = _rng.nextDoubleLimit(game_size.y);

    _shader_rot_pos.setValues(
      _rng.nextDoubleLimit(pi * 2.0),
      _rng.nextDoubleLimit(pi * 2.0),
    );
    _shader_rot_speed.randomizedNormal();
  }

  @override
  Future<void> onLoad() async {
    super.onLoad();
    anchor = Anchor.center;
    await _loadRockShader();
  }

  Future<void> _loadRockShader() async {
    _shader = await load_shader('asteroid.frag');
    _uniforms = UniformsExt<_Uniform>(_shader, {
      for (final e in _Uniform.values) e: e.type,
    });
    _paint.shader = _shader;
  }

  @override
  void update(double dt) {
    super.update(dt);

    _velocity.x = max(10, 100 - size.x);

    position.add(_velocity * dt);

    priority = 1000 - size.x.toInt();

    _shader_rot_pos.x += _shader_rot_speed.x * dt;
    _shader_rot_pos.y += _shader_rot_speed.y * dt;

    _wrap_position();
  }

  void _wrap_position() {
    // Only wrap when asteroid moves off the right side of the screen
    if (position.x > game_size.x + size.x * 2) {
      position.x = -size.x * 2;
      position.y = _rng.nextDouble() * game_size.y; // New random Y position
    }
  }

  @override
  void render(Canvas canvas) {
    _uniforms.set(_Uniform.resolution, _resolution);
    _uniforms.set(_Uniform.mouse, _shader_rot_pos);
    _uniforms.set(_Uniform.hash, _hash);
    canvas.drawRect(_shader_rect, _paint);
  }
}

enum _Uniform {
  resolution(Vector2),
  mouse(Vector2),
  hash(double),
  ;

  final Type type;

  const _Uniform(this.type);
}
