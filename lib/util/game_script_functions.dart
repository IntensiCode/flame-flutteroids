import 'dart:ui';

import 'package:flame/components.dart';
import 'package:flame/effects.dart';
import 'package:flutter/animation.dart';
import 'package:flutteroids/util/auto_dispose.dart';
import 'package:flutteroids/util/bitmap_font.dart';
import 'package:flutteroids/util/bitmap_text.dart';
import 'package:flutteroids/util/extensions.dart';
import 'package:flutteroids/util/functions.dart';
import 'package:flutteroids/util/vector_text.dart';

// don't look here. at least not initially. none of this you should reuse. this
// is a mess. but the mess works for the case of this demo game. all of this
// should be replaced by what you need for your game.

mixin GameScriptFunctions on Component, AutoDispose {
  void clearByType(List types) {
    final what = types.isEmpty ? children : children.where((it) => types.contains(it.runtimeType));
    removeAll(what);
  }

  T fadeIn<T extends Component>(T it, {double duration = 0.2}) {
    it.fadeInDeep(seconds: duration);
    return it;
  }

  BitmapFont? font;
  double? fontScale;

  fontSelect(BitmapFont? font, {double? scale = 1}) {
    this.font = font;
    fontScale = scale;
  }

  SpriteComponent sprite({
    required String filename,
    Vector2? position,
    Anchor? anchor,
  }) =>
      added(sprite_comp(filename, position: position, anchor: anchor));

  SpriteComponent spriteSXY(Sprite sprite, double x, double y, [Anchor anchor = Anchor.center]) =>
      added(SpriteComponent(sprite: sprite, position: Vector2(x, y), anchor: anchor));

  SpriteComponent spriteIXY(Image image, double x, double y, [Anchor anchor = Anchor.center]) =>
      added(SpriteComponent(sprite: Sprite(image), position: Vector2(x, y), anchor: anchor));

  SpriteComponent spriteXY(String filename, double x, double y, [Anchor anchor = Anchor.center]) =>
      added(sprite_comp(filename, position: Vector2(x, y), anchor: anchor));

  void fadeInByType<T extends Component>([bool reset = false]) async {
    children.whereType<T>().forEach((it) => it.fadeInDeep(restart: reset));
  }

  void fadeOutByType<T extends Component>([bool reset = false]) async {
    children.whereType<T>().forEach((it) => it.fadeOutDeep(restart: reset));
  }

  void fadeOutAll([double duration = 0.2]) {
    for (final it in children) {
      it.fadeOutDeep(seconds: duration);
    }
  }

  SpriteAnimationComponent makeAnimCRXY(
    String filename,
    int columns,
    int rows,
    double x,
    double y, {
    Anchor anchor = Anchor.center,
    bool loop = true,
    double stepTime = 0.1,
  }) {
    final animation = animCR(filename, columns, rows, stepTime: stepTime, loop: loop);
    return makeAnim(animation, Vector2(x, y), anchor);
  }

  SpriteAnimationComponent makeAnimXY(SpriteAnimation animation, double x, double y, [Anchor anchor = Anchor.center]) =>
      makeAnim(animation, Vector2(x, y), anchor);

  SpriteAnimationComponent makeAnim(SpriteAnimation animation, Vector2 position, [Anchor anchor = Anchor.center]) =>
      added(SpriteAnimationComponent(
        animation: animation,
        position: position,
        anchor: anchor,
      ));

  void scaleTo(Component it, double scale, double duration, Curve? curve) {
    it.add(
      ScaleEffect.to(
        Vector2.all(scale.toDouble()),
        EffectController(duration: duration.toDouble(), curve: curve ?? Curves.decelerate),
      ),
    );
  }

  BitmapText textXY(String text, double x, double y, {Anchor anchor = Anchor.center, double? scale}) =>
      added(BitmapText(
        text: text,
        position: Vector2(x, y),
        anchor: anchor,
        font: font,
        scale: scale ?? fontScale ?? 1,
      ));

  VectorText vectorTextXY(
    String text,
    double x,
    double y, {
    Anchor anchor = Anchor.center,
    double? scale,
    double charSpacingFactor = 1.0,
    double spacingAdjustment = 2.0,
  }) =>
      added(VectorText(
        text: text,
        position: Vector2(x, y),
        anchor: anchor,
        scale: scale ?? fontScale ?? 1,
      ));
}
