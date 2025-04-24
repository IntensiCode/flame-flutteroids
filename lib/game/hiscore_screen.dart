import 'package:flame/components.dart';
import 'package:flutteroids/background/space.dart';
import 'package:flutteroids/core/common.dart';
import 'package:flutteroids/game/common/hiscore.dart';
import 'package:flutteroids/game/common/screens.dart';
import 'package:flutteroids/input/game_keys.dart';
import 'package:flutteroids/input/shortcuts.dart';
import 'package:flutteroids/ui/soft_keys.dart';
import 'package:flutteroids/util/bitmap_text.dart';
import 'package:flutteroids/util/effects.dart';
import 'package:flutteroids/util/extensions.dart';
import 'package:flutteroids/util/game_script.dart';

class HiscoreScreen extends GameScriptComponent with HasAutoDisposeShortcuts, KeyboardHandler, HasGameKeys {
  final _entry_size = Vector2(game_width, line_height);
  final _position = Vector2(0, line_height * 6);

  @override
  onLoad() async {
    add(shared_space);
    textXY('Hiscore', game_center.x, line_height * 3, scale: 2.5, anchor: Anchor.topCenter);

    _add('Score', 'Level', 'Name');
    for (final entry in hiscore.entries) {
      final it = _add(entry.score.toString(), entry.level.toString(), entry.name);
      if (entry == hiscore.latest_rank) {
        it.add(BlinkEffect(on: 0.75, off: 0.25));
        // add(Particles(await AreaExplosion.covering(it))..priority = -10);
      }
    }

    softkeys('Back', null, (_) => pop_screen());
  }

  _HiscoreEntry _add(String score, String level, String name) {
    final it = added(_HiscoreEntry(
      score,
      level,
      name,
      size: _entry_size,
      position: _position,
    ));
    _position.y += line_height;
    return it;
  }
}

class _HiscoreEntry extends PositionComponent with HasVisibility {
  _HiscoreEntry(
    String score,
    String level,
    String name, {
    required Vector2 size,
    super.position,
  }) : super(size: size) {
    add(BitmapText(
      text: score,
      position: Vector2(size.x * 11 / 32, 0),
      anchor: Anchor.topCenter,
    ));

    add(BitmapText(
      text: level,
      position: Vector2(size.x * 15 / 32, 0),
      anchor: Anchor.topCenter,
    ));

    add(BitmapText(
      text: name,
      position: Vector2(size.x * 20 / 32, 0),
      anchor: Anchor.topCenter,
    ));
  }
}
