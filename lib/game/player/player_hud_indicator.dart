import 'dart:ui';

import 'package:flame/components.dart';
import 'package:flutteroids/core/common.dart';
import 'package:flutteroids/util/extensions.dart';
import 'package:flutteroids/util/mutable.dart';

class PlayerHudIndicator extends PositionComponent with HasPaint {
  PlayerHudIndicator(this._value);

  final double Function() _value;
  final _rect = MutRect(0, 0, 0, 0);

  @override
  void render(Canvas canvas) {
    final value = _value();
    if (value <= 0) return;

    paint.color = switch (value) {
      > .6 => _good,
      > .5 => _damaged,
      > .2 => _danger,
      _ => _critical,
    };

    paint.opacity = opacity;

    _rect.left = 0;
    _rect.top = 10;
    _rect.right = value * 100;
    _rect.bottom = 14;
    canvas.drawRect(_rect, paint);
  }

  static const _good = white;
  static const _damaged = Color(0xFFf0f060);
  static const _danger = Color(0xFFf0a060);
  static const _critical = Color(0xF0ff4040);
}
