import 'dart:ui';

import 'package:flame/components.dart';
import 'package:flutteroids/core/common.dart';
import 'package:flutteroids/post/post_process.dart';
import 'package:flutteroids/util/pixelate.dart';

class FadeScreen extends Component with PostProcess {
  final Color start;
  final Color end;
  final double seconds;
  Component? and_remove;

  FadeScreen.fade_in({required this.seconds, this.and_remove})
      : start = transparent,
        end = white;

  FadeScreen.fade_out({required this.seconds, this.and_remove})
      : start = white,
        end = transparent;

  double t = 0.0;

  @override
  void update(double dt) {
    super.update(dt);
    if (!active) return;
    t = (t + dt / seconds).clamp(0, 1);
    if (t < 1.0) return;

    and_remove?.removeFromParent();
    and_remove?.removed.then((_) => and_remove = null);
    if (and_remove != null) return;

    active = false;
    if (game_post_process == this) game_post_process = null;
  }

  @override
  void post_process(Canvas canvas, Function(Canvas) render) {
    if (active) {
      final img = pixelate(game_width.toInt(), game_height.toInt(), (canvas) => render(canvas));
      paint.color = Color.lerp(start, end, t)!;
      canvas.drawImage(img, Offset.zero, paint);
    } else {
      render(canvas);
    }
  }

  final paint = pixel_paint();
}
