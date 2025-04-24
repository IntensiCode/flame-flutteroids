import 'dart:ui';

import 'package:flame/components.dart';
import 'package:flutteroids/util/mutable.dart';

class PlayerHudBackground extends PositionComponent with HasPaint, Snapshot {
  PlayerHudBackground({required Vector2 hud_size}) {
    size = hud_size;
    renderSnapshot = true;
  }

  final _rect = MutRect(0, 0, 0, 0);

  @override
  void render(Canvas canvas) {
    _rect.top = 0;
    _rect.bottom = size.y;

    final step = 4;
    for (int i = 0; i < _background_colors.length; i++) {
      if (i < _background_colors.length - 1) {
        _rect.left = size.x - (i + 1) * step;
        _rect.right = size.x - i * step;
      } else {
        _rect.left = 0;
        _rect.right = size.x - i * step;
      }
      canvas.drawRect(_rect, paint..color = _background_colors[_background_colors.length - 1 - i]);
    }

    _rect.left = size.x - 16;
    _rect.top = 0;
    _rect.right = _rect.left + 2;
    _rect.bottom = size.y;
    paint.maskFilter = _separator_blur;
    canvas.drawRect(_rect, paint..color = _separator_color);
    paint.maskFilter = null;
  }

  static const _background_colors = [
    Color(0xFF000040),
    Color(0xC0000040),
    Color(0xA0000040),
    Color(0x80000040),
  ];

  static const _separator_color = Color(0xFFffffff);
  static const _separator_blur = MaskFilter.blur(BlurStyle.solid, 2);
}
