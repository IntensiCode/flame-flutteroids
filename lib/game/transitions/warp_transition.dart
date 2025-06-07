import 'dart:ui';

import 'package:flame/components.dart';
import 'package:flutter/animation.dart';
import 'package:flutteroids/background/space.dart';
import 'package:flutteroids/core/common.dart';
import 'package:flutteroids/game/common/game_context.dart';
import 'package:flutteroids/game/common/messages.dart';
import 'package:flutteroids/game/world/world.dart';
import 'package:flutteroids/util/log.dart';
import 'package:flutteroids/util/mutable.dart';
import 'package:flutteroids/util/random.dart';
import 'package:flutteroids/util/uniforms.dart';

enum WarpUniform {
  resolution(Vector2),
  time(double),
  alpha(double),
  ;

  final Type type;

  const WarpUniform(this.type);
}

class WarpTransition extends Component with GameContext {
  WarpTransition({
    required this.on_complete,
    this.duration = 4.0,
  }) {
    priority = 1000;
  }

  static FragmentShader? _shader;
  static UniformsExt<WarpUniform>? _uniforms;

  final _paint = pixel_paint();

  final Function() on_complete;
  final double duration;

  double _hash = 0;
  double _elapsed = 0;
  bool _warped = false;
  bool _completed = false;

  @override
  Future<void> onLoad() async {
    super.onLoad();

    if (_shader == null) {
      log_debug('Loading warp shader');
      _shader = await load_shader('warp.frag');

      _uniforms = UniformsExt<WarpUniform>(_shader!, {
        for (final e in WarpUniform.values) e: e.type,
      });
    }

    _paint.shader = _shader;
  }

  @override
  void onMount() {
    super.onMount();

    _hash = level_rng.nextDouble() * 100;

    _rect.right = world.world_viewport_size * 1.2;
    _rect.bottom = world.world_viewport_size * 1.2;
    space.override_disable_anim = true;

    final size = world.world_viewport_size * 1.2;
    _uniforms!.set(WarpUniform.resolution, Vector2.all(size));

    log_debug('Warp transition started');
  }

  @override
  void onRemove() {
    space.override_disable_anim = false;
    super.onRemove();
  }

  @override
  void update(double dt) {
    super.update(dt);
    _elapsed += dt;

    final progress = (_elapsed / duration).clamp(0.0, 1.0);
    final t = Curves.easeInOut.transform(progress);
    _uniforms!.set(WarpUniform.time, t + _hash);

    // Handle alpha: cubic ease-in during first 0.1, then full opacity until 0.8, then cubic ease-out
    double alpha;
    if (t < 0.1) {
      double t_normalized = t / 0.1;
      alpha = t_normalized * t_normalized * t_normalized;
    } else if (t < 0.8) {
      alpha = 1.0;
    } else {
      double t_normalized = (t - 0.8) / 0.2;
      alpha = 1.0 - (t_normalized * t_normalized * t_normalized);
    }
    alpha = alpha.clamp(0.0, 1.0);
    _uniforms!.set(WarpUniform.alpha, alpha);

    if (_elapsed >= duration * 0.8 && !_warped) {
      _warped = true;
      space.position.x = level_rng.nextDoublePM(4);
      space.position.y = level_rng.nextDoublePM(4);
      space.override_disable_anim = false;
      send_message(LeavingWarp());
    }

    if (_elapsed >= duration && !_completed) {
      _completed = true;
      on_complete();
      removeFromParent();
    }
  }

  @override
  void render(Canvas canvas) {
    canvas.translate(-world.world_viewport_size * 0.6, -world.world_viewport_size * 0.6);
    canvas.drawRect(_rect, _paint);
    canvas.translate(world.world_viewport_size * 0.6, world.world_viewport_size * 0.6);
  }

  final _rect = MutRect(0, 0, game_width, game_height);
}
