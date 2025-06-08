import 'dart:math';
import 'dart:ui';

import 'package:flame/components.dart';
import 'package:flutteroids/core/common.dart';
import 'package:flutteroids/game/common/kinds.dart';
import 'package:flutteroids/util/mutable.dart';

class HealthBar extends PositionComponent {
  HealthBar(this._source) {
    anchor = Anchor.topCenter;
    size.setValues(25, 5);
  }

  final Target _source;

  static const _good = Color(0xA0ffffff);
  static const _half = Color(0xA0ffff00);
  static const _bad = Color(0xA0ff7f00);
  static const _critical = Color(0xA0ff0000);

  static final _paint = pixel_paint()..strokeWidth = 2;

  final _outline = const Rect.fromLTWH(0, 0, 100, 20);
  final _health = MutRect(3, 3, 96, 16);

  void reset() {
    _percent_seen = 100;
    _show_time = 0;
  }

  @override
  void onMount() {
    super.onMount();
    position.x = (parent as PositionComponent).width / 2;
    position.y = -(parent as PositionComponent).height / 4;
  }

  @override
  void update(double dt) {
    if (_show_time > 0) _show_time = max(0, _show_time - dt);
  }

  double _percent_seen = 100;
  double _show_time = 0;

  @override
  void render(Canvas canvas) {
    if (!_source.susceptible) return;

    final percent = (_source.integrity * 100).clamp(0.0, 100.0);
    if (_percent_seen != percent) {
      _show_time = 1;
      _percent_seen = percent;
    }
    if (percent > 60 && _show_time <= 0) return;

    _paint.color = switch (percent) {
      <= 20 => _critical,
      <= 40 => _bad,
      <= 60 => _half,
      _ => _good,
    };
    _paint.style = PaintingStyle.stroke;
    canvas.scale(0.25);
    canvas.drawRect(_outline, _paint);
    _paint.style = PaintingStyle.fill;
    _health.right = max(3, min(96, percent));
    canvas.drawRect(_health, _paint);
  }
}
