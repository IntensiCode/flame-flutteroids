import 'dart:math';
import 'dart:ui';

import 'package:flame/collisions.dart';
import 'package:flame/components.dart';
import 'package:flutteroids/game/common/kinds.dart';
import 'package:flutteroids/game/world/world_entity.dart';
import 'package:flutteroids/util/component_recycler.dart';

class PlasmaRing extends PositionComponent with CollisionCallbacks, Recyclable, WorldEntity, HasPaint {
  //

  static const _color1 = Color(0xFFa0a0ff);
  static const _color2 = Color(0xFF20209f);

  double get base_speed => 32;

  late CircleHitbox _hitbox;

  double _size = 32;
  double _damage = 1;
  int _boost = 0;

  PlasmaRing() {
    size.setAll(4);
    add(_hitbox = CircleHitbox(radius: 16, anchor: Anchor.center, isSolid: true));

    paint.style = PaintingStyle.stroke;
    paint.strokeWidth = 8;
    paint.maskFilter = MaskFilter.blur(BlurStyle.normal, 16);
  }

  void reset(WorldEntity origin, [int boost = 0]) {
    _size = 32;
    _boost = boost;
    _damage = 1.3 * (1 + (_boost / SecondaryWeapon.max_boosts));
    world_pos.setFrom(origin.world_pos);
  }

  @override
  void update(double dt) {
    super.update(dt);
    _size += 350 * dt + pow(_size, 2) * dt / 100;
    if (_size > 1000) recycle();
    size.setAll(_size);
    _hitbox.radius = _size;
    _damage = (_damage - dt).clamp(0.01, 1);
  }

  @override
  void render(Canvas canvas) {
    paint.color = _color2;
    canvas.drawCircle(Offset.zero, _size, paint);
    final mf = paint.maskFilter;
    paint.maskFilter = null;
    paint.color = _color1;
    canvas.drawCircle(Offset.zero, _size, paint);
    paint.maskFilter = mf;
  }

  @override
  void onCollision(Set<Vector2> intersectionPoints, PositionComponent other) {
    super.onCollision(intersectionPoints, other);
    if (recycled) return;
    if (other case Hostile it when it.susceptible) {
      it.on_hit(_damage * 0.5);
    }
  }
}
