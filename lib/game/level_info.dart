import 'package:flame/components.dart';
import 'package:flutteroids/game/common/game_context.dart';
import 'package:flutteroids/input/game_keys.dart';
import 'package:flutteroids/util/auto_dispose.dart';
import 'package:flutteroids/util/bitmap_text.dart';
import 'package:flutteroids/util/delayed.dart';
import 'package:flutteroids/util/effects.dart';
import 'package:flutteroids/util/extensions.dart';
import 'package:flutteroids/util/game_script_functions.dart';
import 'package:flutteroids/util/log.dart';

class LevelInfo extends Component with AutoDispose, GameContext, GameScriptFunctions {
  LevelInfo({
    required this.title,
    required this.text,
    required this.position,
    required this.on_done,
  }) {
    this.priority = 1000;
  }

  final String title;
  final String text;
  final Vector2 position;
  final Function on_done;

  late final BitmapText _title;
  late final BitmapText _text;
  late final BitmapText _start;

  @override
  void onMount() {
    super.onMount();

    final x = position.x;
    final y = position.y;
    add(_title = textXY('', x, y - 40, scale: 1.5));
    add(_text = textXY('', x, y));
    add(_start = textXY('PRESS FIRE TO START', x, y + 60, scale: 1.2));

    _title.isVisible = title.isNotEmpty;
    _title.change_text_in_place(title);
    _title.fadeInDeep();

    _text.isVisible = text.isNotEmpty;
    _text.change_text_in_place(text);
    _text.fadeInDeep();

    _start.isVisible = false;
    add(Delayed(0.5, () {
      _start.isVisible = true;
      _start.fadeInDeep();
      add(Delayed(0.5, () {
        _start.add(BlinkEffect(on: 0.7, off: 0.3));
      }));
    }));
  }

  @override
  void update(double dt) {
    super.update(dt);
    if (keys.any(typical_start_or_select_keys)) {
      keys.clear();
      log_debug('Starting game from LevelInfo');
      fadeOutDeep();
      removed.then((_) => on_done());
    }
  }
}
