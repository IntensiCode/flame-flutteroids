import 'dart:ui';

import 'package:flame/components.dart';
import 'package:flutteroids/core/common.dart';
import 'package:flutteroids/game/common/game_context.dart';
import 'package:flutteroids/game/world/world_entity.dart';
import 'package:flutteroids/util/component_recycler.dart';
import 'package:flutteroids/util/extensions.dart';
import 'package:flutteroids/util/functions.dart';
import 'package:flutteroids/util/uniforms.dart';

extension GameContextExtensions on GameContext {
  Explosions get explosions => cache.putIfAbsent('explosions', () => Explosions());
}

class Explosions extends Component with GameContext {
  final _explosions = ComponentRecycler<Explosion>(() => Explosion._())..precreate(128);

  Explosion spawn(PositionComponent origin, {double scale = 1.0, bool anim = false}) =>
      _explosions.acquire()..reset(origin, scale: scale, anim: anim);

  @override
  onLoad() async => await Explosion.preload();
}

class Explosion extends CircleComponent with Recyclable, WorldEntity {
  static FragmentShader? _explosion;
  static SpriteAnimation? _anim;

  static preload() async {
    _explosion ??= await load_shader('explosion.frag');
    _anim ??= animCR('explosion96.png', 3, 4, stepTime: 0.1);
  }

  SpriteAnimationComponent? _anim_overlay;

  double _time = 0;
  bool _add_anim = false;

  Explosion._();

  void reset(PositionComponent origin, {double scale = 1.0, bool anim = false}) {
    _add_anim = anim;

    _time = 0;
    _anim_overlay?.removeFromParent();
    _anim_overlay = null;

    radius = origin.size.x / 2 * scale;
    anchor = Anchor.center;
    anchor_to_parent(preserve_current: false);

    paint.color = white;
    paint.isAntiAlias = false;
    paint.filterQuality = FilterQuality.none;
    paint.shader = _explosion!;
  }

  @override
  void update(double dt) {
    _time += dt;
    if (_time >= 1 && _anim_overlay == null && _add_anim) {
      add(_anim_overlay = SpriteAnimationComponent(
        animation: _anim!,
        removeOnFinish: true,
        anchor: Anchor.topLeft,
        size: size,
      ));
    }
    if (_time >= 2) recycle();
  }

  @override
  void render(Canvas canvas) {
    _explosion!.setFloat(0, width);
    _explosion!.setFloat(1, height);
    _explosion!.setFloat(2, _time / 2);
    super.render(canvas);
  }
}
