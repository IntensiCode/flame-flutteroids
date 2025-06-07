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
    this.line_spacing = 30,
    this.fade_delay = 0.2,
  }) {
    this.priority = 1000;
  }

  final String title;
  final String text;
  final Vector2 position;
  final Function on_done;
  final double line_spacing;
  final double fade_delay;

  late final BitmapText _title;
  late final List<BitmapText> _text_lines = [];
  late final BitmapText _start;

  bool may_proceed = false;

  @override
  void onMount() {
    super.onMount();

    final x = position.x;
    final y = position.y;

    // Add title
    add(_title = textXY('', x, y - 40, scale: 1.5));
    _title.isVisible = title.isNotEmpty;
    _title.change_text_in_place(title);
    _title.fadeInDeep();

    // Split text into lines and create BitmapText for each line
    if (text.isNotEmpty) {
      final lines = text.split('\n');
      double line_y_offset = 0;

      for (int i = 0; i < lines.length; i++) {
        final line = lines[i];
        if (line.isEmpty) {
          line_y_offset += line_spacing / 2;
          continue;
        }

        final text_line = textXY('', x, y + line_y_offset);
        text_line.isVisible = false;
        text_line.change_text_in_place(line);
        _text_lines.add(text_line);
        add(text_line);

        line_y_offset += line_spacing;
      }

      // Add staggered fade-in for each line
      for (int i = 0; i < _text_lines.length; i++) {
        final delay = fade_delay * i;
        add(Delayed(delay, () {
          _text_lines[i].isVisible = true;
          _text_lines[i].fadeInDeep();
        }));
      }
    }

    // Add start prompt with a delay
    final start_y = y + (_text_lines.isEmpty ? 60 : _text_lines.length * line_spacing + 30);
    add(_start = textXY('PRESS FIRE TO START', x, start_y, scale: 1.2));
    _start.isVisible = false;

    // Calculate total delay for start prompt based on text lines
    final start_delay = 0.5 + (_text_lines.isEmpty ? 0 : fade_delay * _text_lines.length);
    add(Delayed(start_delay, () {
      _start.isVisible = true;
      _start.fadeInDeep();
      may_proceed = true;
      add(Delayed(0.5, () {
        _start.add(BlinkEffect(on: 0.7, off: 0.3));
      }));
    }));

    keys.clear();
  }

  @override
  void update(double dt) {
    super.update(dt);
    if (may_proceed && keys.any(typical_start_or_select_keys)) {
      keys.clear();
      log_debug('Starting game from LevelInfo');
      fadeOutDeep();
      removed.then((_) => on_done());
    }
  }
}
