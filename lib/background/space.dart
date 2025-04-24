import 'dart:ui';

import 'package:flame/components.dart';
import 'package:flutteroids/core/common.dart';
import 'package:flutteroids/game/common/game_context.dart';
import 'package:flutteroids/game/common/video_mode.dart';
import 'package:flutteroids/util/auto_dispose.dart';
import 'package:flutteroids/util/log.dart';
import 'package:flutteroids/util/mutable.dart';
import 'package:flutteroids/util/pixelate.dart';
import 'package:flutteroids/util/uniforms.dart';

enum Uniform {
  resolution(Vector2),
  position(Vector2),
  time(double),
  rescale(double),
  ;

  final Type type;

  const Uniform(this.type);
}

Space? _space;

Space get shared_space {
  _space?.removeFromParent();
  return _space ??= Space._();
}

extension GameContextExtensions on GameContext {
  Space get space => cache.putIfAbsent('space', () => Space._());
}

class Space extends Component with AutoDispose, HasPaint {
  static FragmentShader? _shader;
  static UniformsExt<Uniform>? _uniforms;
  static Paint? _paint;

  static double _time = 0;
  static bool _animate = true;

  final position = Vector2.zero();

  Space._();

  @override
  Future<void> onLoad() async {
    priority = -10000;

    paint.filterQuality = FilterQuality.none;
    paint.isAntiAlias = false;

    if (_shader != null) return;

    log_info('load space shader');
    _shader = await load_shader('space.frag');

    _uniforms = UniformsExt<Uniform>(_shader!, {
      for (final e in Uniform.values) e: e.type,
    });
    _uniforms!.set(Uniform.resolution, game_size);

    _paint = pixel_paint();
    _paint!.shader = _shader;
  }

  @override
  void onMount() {
    super.onMount();
    auto_dispose('on_animate_space_change', on_bg_anim_change((animate) => _update_space()));
    _update_space();
  }

  void _update_space() {
    _animate = bg_anim;

    _last?.dispose();
    _last = null;

    _src.right = game_width;
    _src.bottom = game_height;

    _uniforms!.set(Uniform.resolution, game_size);
    _uniforms!.set(Uniform.position, position);
  }

  @override
  void update(double dt) {
    super.update(dt);
    if (_last != null && !_animate) return;
    _time += dt;
    _uniforms!.set(Uniform.time, _time / 32);
    _uniforms!.set(Uniform.position, position);
  }

  Image? _last;

  @override
  void render(Canvas canvas) {
    super.render(canvas);

    if (_animate) {
      _last?.dispose();
      _last = null;
      canvas.drawRect(_dst, _paint!);
    } else {
      _last ??= pixelate(_src.width.toInt(), _src.height.toInt(), (canvas) {
        canvas.drawRect(_src, _paint!);
      });
      canvas.drawImageRect(_last!, _src, _dst, paint);
    }
  }

  static final _src = MutRect(0, 0, game_width, game_height);
  static const _dst = Rect.fromLTWH(0, 0, game_width, game_height);
}
