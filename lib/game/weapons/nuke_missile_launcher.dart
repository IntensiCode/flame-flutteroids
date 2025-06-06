import 'package:flame/components.dart';
import 'package:flutteroids/game/common/decals.dart';
import 'package:flutteroids/game/common/extra_id.dart';
import 'package:flutteroids/game/common/extras.dart';
import 'package:flutteroids/game/common/game_context.dart';
import 'package:flutteroids/game/common/kinds.dart';
import 'package:flutteroids/game/projectiles/nuke.dart';
import 'package:flutteroids/game/projectiles/nuke_missile.dart';
import 'package:flutteroids/game/weapons/auto_target.dart';
import 'package:flutteroids/game/world/world.dart';
import 'package:flutteroids/game/world/world_entity.dart';
import 'package:flutteroids/util/component_recycler.dart';

class NukeMissileLauncher extends Component with GameContext, SecondaryWeapon, AutoTarget {
  late final _missiles = ComponentRecycler(() => NukeMissile(decals, _emit_nuke));
  late final _nukes = ComponentRecycler(() => Nuke());

  NukeMissileLauncher(this.player, Function(SecondaryWeapon) on_fired) {
    super.on_fired = on_fired;
    cooldown_time = 4;
  }

  @override
  final Player player;

  @override
  String get display_name => 'Nuke Missile';

  @override
  Sprite get icon => extras.icon_for(ExtraId.nuke_missile);

  @override
  void do_fire() => world.add(_missiles.acquire()..reset(player, player.angle, boost));

  _emit_nuke(WorldEntity origin, int boost) => world.add(_nukes.acquire()..reset(origin, boost));
}
