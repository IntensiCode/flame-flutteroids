import 'dart:math';

import 'package:flame/components.dart';
import 'package:flutter/foundation.dart';
import 'package:flutteroids/aural/audio_menu.dart';
import 'package:flutteroids/aural/audio_system.dart';
import 'package:flutteroids/background/space.dart';
import 'package:flutteroids/core/atlas.dart';
import 'package:flutteroids/core/common.dart';
import 'package:flutteroids/game/common/animated_title.dart';
import 'package:flutteroids/game/common/screens.dart';
import 'package:flutteroids/game/common/sound.dart';
import 'package:flutteroids/input/keys.dart';
import 'package:flutteroids/input/shortcuts.dart';
import 'package:flutteroids/ui/basic_menu.dart';
import 'package:flutteroids/ui/flow_text.dart';
import 'package:flutteroids/ui/fonts.dart';
import 'package:flutteroids/util/auto_dispose.dart';
import 'package:flutteroids/util/bitmap_text.dart';
import 'package:flutteroids/util/extensions.dart';
import 'package:flutteroids/util/functions.dart';

class WebPlayScreen extends AutoDisposeComponent with HasAutoDisposeShortcuts {
  WebPlayScreen() {
    add(shared_space);
    add(_keys);
  }

  final _keys = Keys();

  @override
  void onMount() => onKey('<Space>', () => _leave());

  @override
  void update(double dt) {
    super.update(dt);
    if (_keys.check_and_consume(GameKey.start)) _leave();
  }

  @override
  onLoad() async {
    if (true || kIsWeb) {
      add(FlowText(
        text: 'Hint:\n\nIf keyboard controls are not working, press <TAB> once to focus the game.',
        background: atlas.sprite('button_plain.png'),
        font: mini_font,
        position: Vector2(0, game_center.y - 8),
        anchor: Anchor.topLeft,
        size: Vector2(200, 64),
        centered_text: true,
      ));
      add(FlowText(
        text: 'Hint:\n\nPress F11 to toggle fullscreen mode.',
        background: atlas.sprite('button_plain.png'),
        font: mini_font,
        position: Vector2(0, game_center.y + 72),
        anchor: Anchor.topLeft,
        size: Vector2(200, 64),
        centered_text: true,
      ));
    }

    add(BasicMenu<AudioMenuEntry>(
      keys: _keys,
      font: mini_font,
      on_selected: _selected,
      spacing: 10,
    )
      ..add_entry(AudioMenuEntry.master_volume, 'Start')
      ..add_entry(AudioMenuEntry.music_and_sound, 'Music & Sound')
      ..add_entry(AudioMenuEntry.music_only, 'Music Only')
      ..add_entry(AudioMenuEntry.sound_only, 'Sound Only')
      ..add_entry(AudioMenuEntry.silent_mode, 'Silent Mode')
      ..preselect_entry(AudioMenuEntry.master_volume)
      ..position.setValues(game_center.x, game_center.y - 16)
      ..anchor = Anchor.topCenter);

    final anim = animCR('splash_anim.png', 2, 7, loop: false, vertical: true);
    final logo = added(SpriteComponent(
      sprite: anim.frames.last.sprite,
      anchor: Anchor.topCenter,
      position: Vector2(game_center.x, 48),
    )..opacity = 0);
    final it = added(SpriteAnimationComponent(
      animation: anim,
      removeOnFinish: true,
      anchor: Anchor.topCenter,
      position: Vector2(game_center.x, 48),
    ));
    it.animationTicker?.completed.then((_) {
      add(BitmapText(
        text: "A",
        font: menu_font,
        scale: 0.5,
        anchor: Anchor.bottomCenter,
        position: Vector2(game_center.x, 48),
      )..fadeInDeep());
      add(BitmapText(
        text: "GAME",
        font: menu_font,
        scale: 0.5,
        anchor: Anchor.topCenter,
        position: Vector2(game_center.x, 144),
      )..fadeInDeep());
      logo.opacity = 1;
      add(BitmapText(
        text: "AN INTENSICODE PRESENTATION",
        anchor: Anchor.bottomCenter,
        position: Vector2(game_center.x, game_height - 16),
      )..fadeInDeep());
    });
    play_one_shot('psychocell', cache: false);

    await add(AnimatedTitle(
      text: 'FLUTTEROIDS',
      font: menu_font,
      scale: 1.0,
    )
      ..angle = pi / 2
      ..position.setValues(550, 64)
      ..fadeInDeep());
  }

  void _selected(AudioMenuEntry it) {
    switch (it) {
      case AudioMenuEntry.master_volume:
        _leave();
      case AudioMenuEntry.music_and_sound:
        audio.audio_mode = AudioMode.music_and_sound;
        _leave();
      case AudioMenuEntry.music_only:
        audio.audio_mode = AudioMode.music_only;
        _leave();
      case AudioMenuEntry.sound_only:
        audio.audio_mode = AudioMode.sound_only;
        _leave();
      case AudioMenuEntry.silent_mode:
        audio.audio_mode = AudioMode.silent;
        _leave();
      case _: // ignore
        _leave();
    }
  }

  void _leave() {
    fadeOutDeep();
    removed.then((_) => show_screen(Screen.title));
  }
}
