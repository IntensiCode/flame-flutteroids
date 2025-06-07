import 'package:flame/components.dart';
import 'package:flutteroids/background/space.dart';
import 'package:flutteroids/core/atlas.dart';
import 'package:flutteroids/core/common.dart';
import 'package:flutteroids/game/common/screens.dart';
import 'package:flutteroids/input/keys.dart';
import 'package:flutteroids/ui/basic_menu.dart';
import 'package:flutteroids/ui/flow_text.dart';
import 'package:flutteroids/ui/fonts.dart';
import 'package:flutteroids/util/extensions.dart';
import 'package:flutteroids/util/game_script.dart';

final credits = [
  'Powered by Flutter',
  'Made with Flame Engine',
  '',
  'Music by suno.com',
  'Voice Samples by elevenlabs.io',
  '',
  'Voxel Models by maxparata.itch.io',
  'Voxel Shader by intensicode.itch.io',
  'Pixel Explosion Shader by Leukbaars',
  'Space Shader by Pablo Roman Andrioli',
  'Warp Shader by Dave_Hoskins',
  'Asteroid Shader by foxes',
];

final how_to_play = [
  'Follow the instructions on the screen.',
  '',
  'Destroy the asteroids and collect the power-ups.',
  '',
  'Your shield will recharge automatically.',
  'It protects you from smaller asteroids.',
  'Destroy larger asteroids to find power-ups.',
  '',
  'Avoid colliding with asteroids.',
  '',
  'Colliding with large asteroids will destroy your ship.',
];

class Credits extends GameScriptComponent {
  final _keys = Keys();

  @override
  onLoad() {
    super.onLoad();
    add(_keys);
    add(shared_space);

    textXY('Credits', game_center.x + 160, 20, scale: 2, anchor: Anchor.topCenter);
    add(FlowText(
      text: credits.join('\n'),
      position: Vector2(game_center.x + 20, 60),
      size: v2(game_center.x - 32, game_size.y - 200),
      anchor: Anchor.topLeft,
      background: atlas.sprite('button_plain.png'),
      font: mini_font,
    ));

    textXY('How To Play', 160, 20, scale: 2, anchor: Anchor.topCenter);
    add(FlowText(
      text: how_to_play.join('\n'),
      position: Vector2(16, 60),
      size: v2(game_center.x - 32, game_size.y - 200),
      anchor: Anchor.topLeft,
      background: atlas.sprite('button_plain.png'),
      font: mini_font,
    ));

    final menu = added(BasicMenu(
      keys: _keys,
      font: mini_font,
      on_selected: (_) => pop_screen(),
      spacing: 10,
    ));

    menu.position.setValues(game_center.x, 64);
    menu.anchor = Anchor.topCenter;

    add(menu.add_entry('back', 'Back', size: Vector2(80, 24))
      ..auto_position = false
      ..position.setValues(8, game_size.y - 8)
      ..anchor = Anchor.bottomLeft);

    menu.preselect_entry('back');
  }

  @override
  void update(double dt) {
    super.update(dt);
    if (_keys.check_and_consume(GameKey.soft1)) pop_screen();
  }
}
