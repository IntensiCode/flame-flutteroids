import 'dart:math';
import 'dart:ui';

import 'package:flame/components.dart';
import 'package:flutteroids/core/common.dart';
import 'package:flutteroids/util/bitmap_font.dart';

class PlayerHudTitle extends PositionComponent with Snapshot {
  static const rotation_interval = 10.0;
  static const letter_delay = 0.2;
  static const rotation_duration = 2.0;

  final _paint = pixel_paint();

  final String _text;
  final BitmapFont _font;
  final double _scale;
  final List<double> _letter_positions = [];
  double _time = 0;

  static final List<Color> _gradient = List.generate(
    8,
    (i) => Color.fromARGB(255, (i * 255 / 7).round(), (i * 255 / 7).round(), (i * 255 / 7).round()),
  );

  PlayerHudTitle({
    required String text,
    required BitmapFont font,
    required double scale,
  })  : _text = text,
        _font = font,
        _scale = scale {
    _setup_positions();
  }

  void _setup_positions() {
    double x_offset = 0;
    _font.scale = _scale;

    for (int i = 0; i < _text.length; i++) {
      final char = _text[i];
      final char_width = _font.charWidth(char.codeUnitAt(0), _scale);

      _letter_positions.add(x_offset);
      x_offset += char_width + _font.spacing;
    }
  }

  @override
  void update(double dt) {
    super.update(dt);
    _time += dt;

    var snapped = true;
    for (int i = 0; i < _text.length; i++) {
      final scale_x = scale_at(_time, i);
      final scale_y = scale_at(rotation_duration / 3 + _time, i);
      if (scale_x != 1.0 || scale_y != 1.0) {
        snapped = false;
      }
    }
    this.renderSnapshot = snapped;
  }

  double scale_at(double time, int letter_index) {
    final cycle_time = time % rotation_interval;
    final letter_start_time = letter_index * letter_delay;
    final letter_time = cycle_time - letter_start_time;
    if (letter_time < 0 || letter_time > rotation_duration) return 1.0;
    final progress = letter_time / rotation_duration;
    return cos(progress * 3.14159 * 2);
  }

  @override
  void render(Canvas canvas) {
    _font.scale = _scale;
    _font.paint.colorFilter = _paint.colorFilter;
    _font.paint.filterQuality = FilterQuality.none;
    _font.paint.isAntiAlias = false;
    _font.paint.blendMode = _paint.blendMode;

    final center_y = _font.lineHeight(_scale) / 2;

    for (int i = 0; i < _text.length; i++) {
      final char = _text[i];
      final x = _letter_positions[i];
      final scale_x = scale_at(_time, i);
      final scale_y = scale_at(rotation_duration / 3 + _time, i);

      final brightness = min(scale_x.abs(), scale_y.abs());
      final gradient_index = (brightness * (_gradient.length - 1)).round().clamp(0, _gradient.length - 1);
      _font.tint = _gradient[gradient_index];

      final char_width = _font.charWidth(char.codeUnitAt(0), _scale);
      final char_height = _font.lineHeight(_scale);

      canvas.save();
      canvas.translate(x + char_width / 2, center_y);
      canvas.scale(scale_x, scale_y);
      _font.drawString(canvas, -char_width / 2, -char_height / 2, char);
      canvas.restore();
    }
  }
}
