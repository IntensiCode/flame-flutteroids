import 'dart:ui';

import 'package:flame/components.dart';
import 'package:flutter/animation.dart';
import 'package:flutteroids/aural/audio_system.dart';
import 'package:flutteroids/core/common.dart';
import 'package:flutteroids/game/common/extra_id.dart';
import 'package:flutteroids/game/common/extras.dart';
import 'package:flutteroids/game/common/game_context.dart';
import 'package:flutteroids/game/common/kinds.dart';
import 'package:flutteroids/game/world/world.dart';
import 'package:flutteroids/util/component_recycler.dart';
import 'package:flutteroids/util/extensions.dart';
import 'package:flutteroids/util/log.dart';
import 'package:flutteroids/util/mutable.dart';

class SmartBomb extends Component with GameContext, SecondaryWeapon {
  SmartBomb(this.player, Function(SecondaryWeapon) on_fired) {
    super.on_fired = on_fired;
    cooldown_time = 10;
  }

  @override
  final Player player;

  late final _smarts = ComponentRecycler(() => _DestroyEverything(world));

  @override
  String get display_name => 'Smart Bomb';

  @override
  Sprite get icon => extras.icon_for(ExtraId.smart_bomb);

  @override
  void do_fire() {
    world.add(_smarts.acquire()..reset());
    audio.play(Sound.plasma, volume_factor: 0.5);
  }
}

class _DestroyEverything extends Component with Recyclable, HasPaint {
  _DestroyEverything(this.world) {
    paint.color = white;
    priority = 5000;
  }

  final AsteroidsWorld world;

  double _life_time = 0;

  void reset() {
    _life_time = 0;
  }

  @override
  void onMount() {
    _rect.setSize(world.world_viewport_size * 1.2, world.world_viewport_size * 1.2);
    _rect.left = -world.world_viewport_size * 0.6;
    _rect.top = -world.world_viewport_size * 0.6;
  }

  @override
  void update(double dt) {
    super.update(dt);
    _life_time += dt;
    if (_life_time > 1) recycle();
    if (_life_time > 0.5 && _life_time < 0.6) {
      for (final it in world.children.whereType<Hostile>()) {
        if (it.susceptible)
          it.on_hit(10);
        else
          log_info('Smart bomb skipped $it, not susceptible');
      }
    }
  }

  @override
  void render(Canvas canvas) {
    final saved = paint.opacity;
    final x = _life_time < 0.5 ? _life_time * 2 : 1 - (_life_time - 0.5) * 2;
    final o = Curves.easeInOutCubic.transform(x.clamp(0, 1));
    paint.opacity *= o;
    canvas.drawRect(_rect, paint);
    paint.opacity = saved;
  }

  late final _rect = MutRect.zero();
}
