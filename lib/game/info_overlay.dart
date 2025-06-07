import 'dart:async';

import 'package:flame/components.dart';
import 'package:flutteroids/core/common.dart';
import 'package:flutteroids/core/messages.dart';
import 'package:flutteroids/util/bitmap_text.dart';
import 'package:flutteroids/util/effects.dart';
import 'package:flutteroids/util/extensions.dart';
import 'package:flutteroids/util/game_script.dart';
import 'package:flutteroids/util/messaging.dart';
import 'package:flutteroids/util/on_message.dart';

extension ComponentExtensions on Component {
  void show_info(
    String text, {
    String? title,
    String? secondary,
    bool blink = true,
    bool longer = false,
    Function? done,
  }) {
    send_message(ShowInfoText(
      title: title,
      text: text,
      secondary: secondary,
      blink_text: blink,
      stay_longer: longer,
      when_done: done,
    ));
  }
}

class InfoOverlay extends GameScriptComponent {
  InfoOverlay({Vector2? position, int priority = 9000}) {
    // add(_info = _InfoOverlay(position: position, quick: dev));
    add(_info = _InfoOverlay(position: position, quick: false));
    super.priority = priority;
  }

  late _InfoOverlay _info;

  @override
  void onMount() {
    super.onMount();
    on_message<ShowInfoText>((it) => _info.pipe.add(it));
  }
}

class _InfoOverlay extends GameScriptComponent {
  _InfoOverlay({Vector2? position, this.quick = false}) : pos = position ?? Vector2(game_width / 2, game_height / 2);

  final pipe = <ShowInfoText>[];

  final Vector2 pos;
  final bool quick;

  Future? _active;

  late final BitmapText _title_text;
  late final BitmapText _text;
  late final BitmapText _secondary_text;

  @override
  onLoad() {
    add(_title_text = textXY('', pos.x, pos.y - 20, scale: 1.5)..isVisible = false);
    add(_text = textXY('', pos.x, pos.y)..isVisible = false);
    add(_secondary_text = textXY('', pos.x, pos.y + 20)..isVisible = false);
  }

  @override
  void update(double dt) {
    super.update(dt);

    if (_active != null || pipe.isEmpty) return;

    final it = pipe.first;

    script_clear();

    _fade_in(it);

    // if (kReleaseMode && it.stay_longer) script_after(1.2, () {});
    if (it.stay_longer) script_after(1.2, () {});

    if (pipe.length > 3) {
      _fade_out_quick(it);
    } else {
      _blink_text(it); // remove blink?
      if (pipe.length == 1) {
        _fade_out(it);
      } else {
        _skip_fade_out(it);
      }
    }

    final active = _active = script_execute();
    _active?.then((_) {
      pipe.removeAt(0);
      if (_active == active) _active = null;
    });
  }

  void _fade_in(ShowInfoText it) {
    script_after(0.0, () {
      _title_text.isVisible = it.title != null;
      _title_text.change_text_in_place(it.title ?? '');
      if (it.title != null) _title_text.fadeInDeep();

      _text.isVisible = true;
      _text.change_text_in_place(it.text);
      _text.fadeInDeep();

      _secondary_text.isVisible = it.secondary != null;
      _secondary_text.change_text_in_place(it.secondary ?? '');
      if (it.secondary != null) _secondary_text.fadeInDeep();
    });
  }

  void _blink_text(ShowInfoText it) {
    script_after(quick ? 0.2 : 0.4, () {
      if (it.blink_text) _text.add(BlinkEffect(on: 0.35, off: 0.15));
    });
    script_after(quick ? 0.9 : 1.8, () => _text.removeAll(_text.children)); // remove blink?
  }

  void _fade_out_quick(ShowInfoText it) {
    script_after(0.4, () => _text.fadeOutDeep(and_remove: false));
    script_after(0.0, () {
      if (it.title != null) _title_text.fadeOutDeep(and_remove: false);
      if (it.secondary != null) _secondary_text.fadeOutDeep(and_remove: false);
    });
    script_after(0.4, () => it.when_done?.call());
  }

  void _fade_out(ShowInfoText it) {
    script_after(quick ? 0.0 : 1.0, () => _text.fadeOutDeep(and_remove: false));
    script_after(0.0, () {
      if (it.title != null) _title_text.fadeOutDeep(and_remove: false);
      if (it.secondary != null) _secondary_text.fadeOutDeep(and_remove: false);
    });
    script_after(quick ? 0.2 : 0.5, () => it.when_done?.call());
  }

  void _skip_fade_out(ShowInfoText it) {
    script_after(0.0, () => it.when_done?.call());
  }
}
