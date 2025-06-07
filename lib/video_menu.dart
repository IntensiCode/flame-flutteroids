import 'package:flame/components.dart';
import 'package:flutteroids/background/space.dart';
import 'package:flutteroids/core/atlas.dart';
import 'package:flutteroids/core/common.dart';
import 'package:flutteroids/game/common/configuration.dart';
import 'package:flutteroids/game/common/screens.dart';
import 'package:flutteroids/game/common/video_mode.dart';
import 'package:flutteroids/input/keys.dart';
import 'package:flutteroids/ui/basic_menu.dart';
import 'package:flutteroids/ui/basic_menu_button.dart';
import 'package:flutteroids/ui/flow_text.dart';
import 'package:flutteroids/ui/fonts.dart';
import 'package:flutteroids/util/extensions.dart';
import 'package:flutteroids/util/game_script.dart';

enum _VideoEntry {
  performance('Performance'),
  balanced('Balanced'),
  quality('Quality'),
  animate_space('Animate Space'),
  exhaust_anim('Exhaust Animation'),
  back('Back'),
  ;

  final String label;

  const _VideoEntry(this.label);
}

final _hint = {
  _VideoEntry.performance: '''
      Fastest rendering, but less smooth:
      \n\n
      - Disables non-essential animations
      - Disables voxel model exhaust animation
      - Disables animated space background
      ''',
  _VideoEntry.balanced: '''
      Balanced rendering speed and smoothness:
      \n\n
      - Disables non-essential animations
      - Disables voxel model exhaust animation
      ''',
  _VideoEntry.quality: '''
      Full rendering quality:
      \n\n
      - Everything enabled
      ''',
  _VideoEntry.animate_space: '''
      Animate the space background:
      \n\n
      - Enables animated starfield
      - Reduces render performance
      \n\n
      Overrides performance mode
      ''',
  _VideoEntry.exhaust_anim: '''
      Enable exhaust animation:
      \n\n
      - Enables Voxel Model animation
      - Reduces render performance
      \n\n
      Overrides performance mode
      \n\n
      *Does not work on web for some reason*
      ''',
};

class VideoMenu extends GameScriptComponent {
  final _keys = Keys();

  late final BasicMenu<_VideoEntry> _menu;

  BasicMenuButton? _animate_space_button;
  BasicMenuButton? _exhaust_anim_button;

  FlowText? _hint_text;

  static _VideoEntry? _preselected;

  @override
  onLoad() {
    add(_keys);
    add(shared_space);

    fontSelect(tiny_font, scale: 2);
    textXY('Video Mode', game_center.x, 20, scale: 2, anchor: Anchor.topCenter);

    _preselected ??= switch (video_mode.value) {
      VideoMode.performance => _VideoEntry.performance,
      VideoMode.balanced => _VideoEntry.balanced,
      VideoMode.quality => _VideoEntry.quality,
    };

    _menu = added(BasicMenu<_VideoEntry>(
      keys: _keys,
      font: mini_font,
      on_selected: _selected,
      spacing: 10,
    )
      ..add_entry(_VideoEntry.performance, 'Performance')
      ..add_entry(_VideoEntry.balanced, 'Balanced')
      ..add_entry(_VideoEntry.quality, 'Quality'));

    _animate_space_button = _menu.add_entry(_VideoEntry.animate_space, 'Animate Space', text_anchor: Anchor.centerLeft);
    _animate_space_button?.checked = ~bg_anim;
    _exhaust_anim_button =
        _menu.add_entry(_VideoEntry.exhaust_anim, 'Exhaust Animation', text_anchor: Anchor.centerLeft);
    _exhaust_anim_button?.checked = ~exhaust_anim;

    _menu.position.setValues(64, 64);
    _menu.anchor = Anchor.topLeft;
    _menu.on_preselected = _preselect;

    add(_menu.add_entry(_VideoEntry.back, 'Back', size: Vector2(80, 24))
      ..auto_position = false
      ..position.setValues(8, game_size.y - 8)
      ..anchor = Anchor.bottomLeft);

    _menu.preselect_entry(_preselected ?? _VideoEntry.balanced);
  }

  @override
  void update(double dt) {
    super.update(dt);
    if (_keys.check_and_consume(GameKey.soft1)) pop_screen();
  }

  void _selected(_VideoEntry it) {
    switch (it) {
      case _VideoEntry.performance:
        apply_video_mode(VideoMode.performance);
      case _VideoEntry.balanced:
        apply_video_mode(VideoMode.balanced);
      case _VideoEntry.quality:
        apply_video_mode(VideoMode.quality);
      case _VideoEntry.animate_space:
        bg_anim << !~bg_anim;
      case _VideoEntry.exhaust_anim:
        exhaust_anim << !~exhaust_anim;
      case _VideoEntry.back:
        pop_screen();
    }
    if (_animate_space_button?.checked != ~bg_anim) {
      _animate_space_button?.checked = ~bg_anim;
      _animate_space_button?.fadeInDeep();
    }
    if (_exhaust_anim_button?.checked != ~exhaust_anim) {
      _exhaust_anim_button?.checked = ~exhaust_anim;
      _exhaust_anim_button?.fadeInDeep();
    }
  }

  void _preselect(_VideoEntry? it) {
    _preselected = it;
    _hint_text?.removeFromParent();
    _hint_text = null;

    if (it == null || _hint[it] == null) return;

    _hint_text = added(FlowText(
      background: atlas.sprite('button_plain.png'),
      text: _hint[it]!,
      font: mini_font,
      anchor: Anchor.topRight,
      size: Vector2(280 + 32, 128),
      position: Vector2(game_size.x - 32, 63),
    ));
  }
}
