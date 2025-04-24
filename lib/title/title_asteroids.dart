import 'dart:math';
import 'dart:ui';

import 'package:flame/collisions.dart';
import 'package:flame/components.dart';
import 'package:flutteroids/core/common.dart';
import 'package:flutteroids/util/mutable.dart';
import 'package:flutteroids/util/random.dart';
import 'package:flutteroids/util/uniforms.dart';

class TitleAsteroids extends Component with HasCollisionDetection<Sweep<ShapeHitbox>> {
  final int asteroidCount;
  final List<TitleAsteroid> _asteroids = [];
  final Random _rng = Random();

  TitleAsteroids({this.asteroidCount = 16});

  @override
  Future<void> onLoad() async {
    super.onLoad();
    int spawned = 0;
    int attempts = 0;
    while (spawned < asteroidCount && attempts < asteroidCount * 20) {
      attempts++;
      final asteroid = TitleAsteroid();
      final radius = 20 + _rng.nextDouble() * 30;
      asteroid.setup_for_spawn(radius);
      asteroid.position.setFrom(_randomOffscreenPosition(radius));
      asteroid.velocity.setFrom(_randomVelocityFrom(asteroid.position, radius));
      bool overlaps = false;
      for (final other in _asteroids) {
        final minDist = (radius + other.asteroidRadius) * 0.5;
        if (asteroid.position.distanceToSquared(other.position) < minDist * minDist) {
          overlaps = true;
          break;
        }
      }
      if (!overlaps) {
        add(asteroid);
        _asteroids.add(asteroid);
        spawned++;
      }
    }
  }

  Vector2 _randomOffscreenPosition(double radius) {
    // Pick a random edge: 0=left, 1=right, 2=top, 3=bottom
    int edge = _rng.nextInt(4);
    double x, y;
    switch (edge) {
      case 0: // left
        x = -radius - 10;
        y = _rng.nextDouble() * game_size.y;
        break;
      case 1: // right
        x = game_size.x + radius + 10;
        y = _rng.nextDouble() * game_size.y;
        break;
      case 2: // top
        x = _rng.nextDouble() * game_size.x;
        y = -radius - 10;
        break;
      case 3: // bottom
      default:
        x = _rng.nextDouble() * game_size.x;
        y = game_size.y + radius + 10;
        break;
    }
    return Vector2(x, y);
  }

  Vector2 _randomVelocityFrom(Vector2 from, double radius) {
    // Target is a random point inside the inner half of the screen
    final tx = game_size.x * 0.25 + _rng.nextDouble() * game_size.x * 0.5;
    final ty = game_size.y * 0.25 + _rng.nextDouble() * game_size.y * 0.5;
    final to = Vector2(tx, ty);
    final dir = to - from;
    dir.normalize();
    final speed = 20 + _rng.nextDouble() * 40;
    return dir..scale(speed);
  }
}

class TitleAsteroid extends PositionComponent with CollisionCallbacks {
  // 3D experiment fields
  double posZ = 0.0;
  double velZ = 0.0;
  static const double zNear = 100.0;
  static const double zFar = 800.0;
  static const double zThreshold = 40.0; // collision depth threshold
  double asteroidRadius = 40.0;
  final Vector2 velocity = Vector2.zero();
  double rotationSpeed = 0.0;
  double hash = 0.0;

  FragmentShader? _shader;
  UniformsExt<_Uniform>? _uniforms;
  Paint? _shaderPaint;
  final Vector2 _shaderRotPos = Vector2.zero();
  final Vector2 _shaderRotSpeed = Vector2.zero();
  final MutRect _shaderRect = MutRect.zero();
  final Vector2 _resolution = Vector2.zero();

  final CircleHitbox _hitbox = CircleHitbox(radius: 0, isSolid: true);

  TitleAsteroid();

  void setup_for_spawn(double newRadius) {
    posZ = zNear + (zFar - zNear) * level_rng.nextDouble();
    velZ = (level_rng.nextDouble() - 0.5) * 60.0; // range [-30,30]

    size.setAll(newRadius);
    asteroidRadius = newRadius;
    _hitbox.radius = asteroidRadius * 0.4;
    _hitbox.position.setAll(asteroidRadius * 0.1);
    rotationSpeed = ((level_rng.nextDouble() - 0.5) * 2.0).clamp(-1.2, 1.2);
    hash = level_rng.nextDoubleLimit(800);
    _shaderRotPos.setValues(
      level_rng.nextDoubleLimit(pi * 2.0),
      level_rng.nextDoubleLimit(pi * 2.0),
    );
    _shaderRotSpeed.randomizedNormal();
  }

  @override
  Future<void> onLoad() async {
    super.onLoad();
    anchor = Anchor.center;
    await add(_hitbox);
    await _loadRockShader();
  }

  Future<void> _loadRockShader() async {
    _shader ??= await load_shader('asteroid.frag');
    _uniforms ??= UniformsExt<_Uniform>(_shader!, {
      for (final e in _Uniform.values) e: e.type,
    });
    _shaderPaint ??= pixel_paint()
      ..color = white
      ..shader = _shader;
  }

  @override
  void update(double dt) {
    super.update(dt);
    position.add(velocity * dt);
    posZ += velZ * dt;
    if (posZ < zNear) {
      posZ = zNear;
      velZ = velZ.abs();
    } else if (posZ > zFar) {
      posZ = zFar;
      velZ = -velZ.abs();
    }
    priority = 1000 - posZ.round(); // Higher z means lower priority
    rotationSpeed = rotationSpeed.clamp(-1.2, 1.2);
    angle += rotationSpeed * dt;
    _shaderRotPos.x += _shaderRotSpeed.x * dt;
    _shaderRotPos.y += _shaderRotSpeed.y * dt;
    _wrapScreen();
  }

  void _wrapScreen() {
    if (position.x < -asteroidRadius) position.x = game_size.x + asteroidRadius;
    if (position.x > game_size.x + asteroidRadius) position.x = -asteroidRadius;
    if (position.y < -asteroidRadius) position.y = game_size.y + asteroidRadius;
    if (position.y > game_size.y + asteroidRadius) position.y = -asteroidRadius;
  }

  @override
  void onCollisionStart(Set<Vector2> intersectionPoints, PositionComponent other) {
    super.onCollisionStart(intersectionPoints, other);
    if (other is TitleAsteroid) {
      if ((posZ - other.posZ).abs() > zThreshold) return;
      // Elastic collision (adapted from gameplay asteroid)
      final mass1 = asteroidRadius * asteroidRadius;
      final mass2 = other.asteroidRadius * other.asteroidRadius;
      final totalMass = mass1 + mass2;
      // Use static scratch vectors to avoid allocation
      final normal = Vector2.zero();
      normal.setFrom(position);
      normal.sub(other.position);
      normal.normalize();
      final relVel = Vector2.zero();
      relVel.setFrom(velocity);
      relVel.sub(other.velocity);
      final velAlongNormal = relVel.dot(normal);
      if (velAlongNormal > 0) return;
      final restitution = 0.8;
      final impulse = -(1 + restitution) * velAlongNormal / totalMass * (mass1 * mass2);
      final impulseVec = Vector2.copy(normal)..scale(impulse);
      final deltaV1 = Vector2.copy(impulseVec)..scale(1 / mass1);
      final deltaV2 = Vector2.copy(impulseVec)..scale(1 / mass2);
      velocity.add(deltaV1);
      other.velocity.sub(deltaV2);
      // Add some visual spin
      final delta = (level_rng.nextDouble() - 0.5) * 1.0;
      rotationSpeed = (rotationSpeed + delta).clamp(-1.2, 1.2);
      other.rotationSpeed = (other.rotationSpeed - delta).clamp(-1.2, 1.2);
    }
  }

  @override
  void render(Canvas canvas) {
    // Depth projection: scale by z
    final proj = _depth_projection();
    final scale = proj[0];
    final shade = proj[1];
    final scaledRadius = asteroidRadius * scale;
    final shaderSize = scaledRadius;
    _shaderRect.left = 0;
    _shaderRect.top = 0;
    _shaderRect.right = shaderSize * 1.5;
    _shaderRect.bottom = shaderSize * 1.5;
    _resolution.setValues(shaderSize * 1.5, shaderSize * 1.5);
    _uniforms?.set(_Uniform.resolution, _resolution);
    _uniforms?.set(_Uniform.mouse, _shaderRotPos);
    _uniforms?.set(_Uniform.hash, hash);
    // Paint color as gray shade based on z
    if (_shaderPaint != null) {
      _shaderPaint!.color = Color.from(alpha: 1, red: shade, green: shade, blue: shade);
    }
    canvas.save();
    canvas.scale(scale, scale);
    canvas.translate(-shaderSize * 0.25, -shaderSize * 0.25);
    if (_shaderPaint != null) {
      canvas.drawRect(_shaderRect, _shaderPaint!);
    }
    canvas.restore();
  }

  List<double> _depth_projection() {
    // Returns [scale, gray_shade]
    final z = posZ.clamp(zNear, zFar);
    final t = (z - zNear) / (zFar - zNear);
    final scale = 0.6 + (1.0 - t) * 1.2; // scale: near=1.8, far=0.6
    final shade = (1.0 - t).roundToDouble().clamp(0.0, 255.0);
    return [scale, shade];
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
