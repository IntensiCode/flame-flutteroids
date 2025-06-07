import 'dart:ui';

import 'package:flame/components.dart';
import 'package:flutter/animation.dart';
import 'package:flutteroids/background/space.dart';
import 'package:flutteroids/core/common.dart';
import 'package:flutteroids/game/common/game_context.dart';
import 'package:flutteroids/game/common/messages.dart';
import 'package:flutteroids/game/common/sound.dart';
import 'package:flutteroids/game/world/world.dart';
import 'package:flutteroids/game/world/world_entity.dart';
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

enum WarpPhase {
  start,
  hold,
  end,
}

class WarpTransition extends Component with GameContext {
  WarpTransition({
    required this.on_complete,
  }) {
    priority = 1000;
  }

  static FragmentShader? _shader;
  static UniformsExt<WarpUniform>? _uniforms;

  final _paint = pixel_paint();

  final Function() on_complete;

  static const double start_duration = 0.1;
  static const double end_duration = 0.5;

  double _hash = 0;
  double _phase_elapsed = 0;
  WarpPhase _current_phase = WarpPhase.start;
  bool _warped = false;
  bool _completed = false;

  void leave_warp() {
    _current_phase = WarpPhase.end;
    _phase_elapsed = 0.0;
    log_debug('Warp transition proceeding to end phase');
  }

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

    world.removeAll(children.whereType<WorldEntity>());

    play_sound(Sound.incoming);
  }

  @override
  void onRemove() {
    space.override_disable_anim = false;
    super.onRemove();
  }

  @override
  void update(double dt) {
    super.update(dt);
    _phase_elapsed += dt;

    double alpha = 0.0;
    double time_value = 0.0;

    switch (_current_phase) {
      case WarpPhase.start:
        // Start phase: 0.1 second ramp up of alpha and cubic time
        final progress = (_phase_elapsed / start_duration).clamp(0.0, 1.0);
        time_value = Curves.easeInOut.transform(progress);

        // Cubic ease-in for alpha
        alpha = progress * progress * progress;

        if (_phase_elapsed >= start_duration) {
          _current_phase = WarpPhase.hold;
          _phase_elapsed = 0.0;
        }

      case WarpPhase.hold:
        // Hold phase: keep shader animation going at fast speed
        time_value = 1.0 + _phase_elapsed;
        alpha = 1.0;

      case WarpPhase.end:
        // End phase: 0.2 second ramp down of alpha and cubic time
        final progress = (_phase_elapsed / end_duration).clamp(0.0, 1.0);
        time_value = 1.0 - Curves.easeInOut.transform(progress);

        // Cubic ease-out for alpha
        alpha = 1.0 - (progress * progress * progress);

        if (_phase_elapsed >= end_duration && !_completed) {
          _completed = true;
          on_complete();
          removeFromParent();
        }
    }

    _uniforms!.set(WarpUniform.time, time_value + _hash);
    _uniforms!.set(WarpUniform.alpha, alpha.clamp(0.0, 1.0));

    // Trigger warp jump when entering end phase
    if (_current_phase == WarpPhase.end && !_warped) {
      _warped = true;
      space.position.x = level_rng.nextDoublePM(4);
      space.position.y = level_rng.nextDoublePM(4);
      space.override_disable_anim = false;
      send_message(LeavingWarp());
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
