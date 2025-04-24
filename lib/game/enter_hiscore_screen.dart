import 'package:flutteroids/core/common.dart';
import 'package:flutteroids/game/common/game_context.dart';
import 'package:flutteroids/game/common/hiscore.dart';
import 'package:flutteroids/game/common/screens.dart';
// import 'package:flutteroids/game/level/level.dart';
// import '../../bak/player/player.dart';
import 'package:flutteroids/input/shortcuts.dart';
import 'package:flutteroids/ui/soft_keys.dart';
import 'package:flutteroids/util/game_script.dart';
import 'package:flutteroids/util/grab_input.dart';

class EnterHiscoreScreen extends GameScriptComponent with HasAutoDisposeShortcuts, GameContext, GrabInput {
  @override
  onLoad() {
    vectorTextXY('You made it into the', game_center.x, line_height * 2);
    vectorTextXY('HISCORE', game_center.x, line_height * 3, scale: 1.5);

    vectorTextXY('Score', game_center.x, line_height * 5);
    vectorTextXY('$pending_score', game_center.x, line_height * 6);

    vectorTextXY('Level', game_center.x, line_height * 8);
    vectorTextXY('$pending_level', game_center.x, line_height * 9);

    vectorTextXY('Enter your name:', game_center.x, line_height * 12);

    var input = vectorTextXY('_', game_center.x, line_height * 13);

    softkeys('Cancel', 'Ok', (it) {
      if (it == SoftKey.left) {
        pop_screen(); // TODO confirm
      } else if (it == SoftKey.right && name.isNotEmpty) {
        // hiscore.insert(player.score, level.number, name);
        show_screen(Screen.hiscore);
      }
    });

    snoop_key_input((it) {
      if (it.length == 1) {
        name += it;
      } else if (it == '<Space>' && name.isNotEmpty) {
        name += ' ';
      } else if (it == '<Backspace>' && name.isNotEmpty) {
        name = name.substring(0, name.length - 1);
      } else if (it == '<Enter>' && name.isNotEmpty) {
        hiscore.insert(pending_score!, pending_level!, name);
        show_screen(Screen.hiscore);
      }
      if (name.length > 10) name = name.substring(0, 10);

      input.removeFromParent();

      input = vectorTextXY('${name}_', game_center.x, line_height * 13);
    });
  }

  String name = '';
}
