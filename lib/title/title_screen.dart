import 'dart:math';

import 'package:flame/components.dart';
import 'package:flutteroids/aural/audio_system.dart';
import 'package:flutteroids/background/space.dart';
import 'package:flutteroids/core/common.dart';
import 'package:flutteroids/game/common/animated_title.dart';
import 'package:flutteroids/game/common/screens.dart';
import 'package:flutteroids/game/common/video_mode.dart';
import 'package:flutteroids/input/keys.dart';
import 'package:flutteroids/input/shortcuts.dart';
import 'package:flutteroids/title/title_asteroids.dart';
import 'package:flutteroids/title/title_manta.dart';
import 'package:flutteroids/ui/basic_menu.dart';
import 'package:flutteroids/ui/fonts.dart';
import 'package:flutteroids/util/bitmap_text.dart';
import 'package:flutteroids/util/extensions.dart';
import 'package:flutteroids/util/game_script.dart';

enum _TitleButtons {
  audio,
  controls,
  credits,
  hiscore,
  play,
  video,
}

final _credits = [
  'Music by suno.com',
  'Voxel Shader by IntensiCode',
  'Voxel Models by maxparata.itch.io',
];

class TitleScreen extends GameScriptComponent with HasAutoDisposeShortcuts {
  static _TitleButtons? _preselected = _TitleButtons.play;

  final _keys = Keys();

  BitmapText? _video;
  BitmapText? _audio;

  @override
  onLoad() {
    add(_keys);
    add(shared_space);
    add(TitleManta()
      ..position.setValues(500, 300)
      ..anchor = Anchor.center);
    add(TitleAsteroids());
    add(AnimatedTitle(text: 'FLUTTEROIDS', font: menu_font, scale: 2.0)
      ..position.setValues(64, 64)
      ..anchor = Anchor.center);

    for (final (idx, it) in _credits.reversed.indexed) {
      textXY(it, 784, 466 - idx * 10, anchor: Anchor.bottomRight, scale: 1);
    }

    textXY('< Video Mode >', 280, 308, anchor: Anchor.bottomCenter, scale: 1);
    _video = textXY(guess_video_mode().name, 280, 308 + 12, anchor: Anchor.bottomCenter, scale: 1);

    textXY('< Audio Mode >', 280, 340, anchor: Anchor.bottomCenter, scale: 1);
    _audio = textXY(audio.guess_audio_mode.label, 280, 340 + 12, anchor: Anchor.bottomCenter, scale: 1);

    final menu = added(BasicMenu<_TitleButtons>(
      keys: _keys,
      font: mini_font,
      on_selected: _selected,
      spacing: 8,
      fixed_position: Vector2(16, game_height - 8),
      fixed_anchor: Anchor.bottomLeft,
    ));

    menu.add_entry(_TitleButtons.hiscore, 'Hiscore');
    menu.add_entry(_TitleButtons.credits, 'Credits / How To Play');
    menu.add_entry(_TitleButtons.controls, 'Controls');
    menu.add_entry(_TitleButtons.video, 'Video');
    menu.add_entry(_TitleButtons.audio, 'Audio');
    menu.add_entry(_TitleButtons.play, 'Play');
    menu.preselect_entry(_preselected ?? _TitleButtons.play);

    menu.on_preselected = (id) => _preselected = id;
  }

  void _selected(_TitleButtons id) {
    _preselected = id;
    switch (id) {
      case _TitleButtons.hiscore:
        push_screen(Screen.hiscore);
        break;
      case _TitleButtons.credits:
        show_screen(Screen.credits);
        break;
      case _TitleButtons.controls:
        push_screen(Screen.controls);
        break;
      case _TitleButtons.video:
        push_screen(Screen.video);
        break;
      case _TitleButtons.audio:
        push_screen(Screen.audio);
        break;
      case _TitleButtons.play:
        show_screen(Screen.game);
        break;
    }
  }

  double _anim = 0;
  final _rotation = Matrix3.zero();

  @override
  void update(double dt) {
    super.update(dt);

    if (_keys.check_and_consume(GameKey.start)) {
      push_screen(Screen.game);
    }
    if (_keys.check_and_consume(GameKey.left)) {
      if (_preselected == _TitleButtons.video) _change_video_mode(-1);
      if (_preselected == _TitleButtons.audio) _change_audio_mode(-1);
    }
    if (_keys.check_and_consume(GameKey.right)) {
      if (_preselected == _TitleButtons.video) _change_video_mode(1);
      if (_preselected == _TitleButtons.audio) _change_audio_mode(1);
    }

    _anim += dt * pi / 2;
    _rotation.setRotationY(_anim);
  }

  void _change_video_mode(int add) {
    final values = VideoMode.values;
    final index = (values.indexOf(guess_video_mode()) + add) % values.length;
    apply_video_mode(values[index]);
    _video?.text = values[index].name;
    _video?.fadeInDeep();
  }

  void _change_audio_mode(int add) {
    final values = AudioMode.values;
    final index = (values.indexOf(audio.guess_audio_mode) + add) % values.length;
    audio.audio_mode = values[index];
    _audio?.text = audio.guess_audio_mode.label;
    _audio?.fadeInDeep();
  }
}
