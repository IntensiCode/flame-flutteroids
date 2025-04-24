import 'package:flame/components.dart';
import 'package:flutteroids/game/common/extra_id.dart';
import 'package:flutteroids/game/common/extras.dart';
import 'package:flutteroids/game/common/game_context.dart';
import 'package:flutteroids/game/common/kinds.dart';
import 'package:flutteroids/game/projectiles/plasma_blob.dart';
import 'package:flutteroids/game/projectiles/plasma_ring.dart';
import 'package:flutteroids/game/world/world.dart';
import 'package:flutteroids/game/world/world_entity.dart';
import 'package:flutteroids/util/component_recycler.dart';

class PlasmaEmitter extends Component with GameContext, SecondaryWeapon {
  PlasmaEmitter(this.player, Function(SecondaryWeapon) on_fired) {
    super.on_fired = on_fired;
  }

  @override
  final Player player;

  late final _blobs = ComponentRecycler(() => PlasmaBlob(_emit_plasma_ring))..precreate(8);
  late final _rings = ComponentRecycler(() => PlasmaRing())..precreate(8);

  @override
  String get display_name => 'Plasma Emitter';

  @override
  Sprite get icon => extras.icon_for(ExtraId.plasma_ring);

  @override
  void do_fire() {
    world.add(_blobs.acquire()..reset(player, player.angle));
  }

  _emit_plasma_ring(WorldEntity origin) => world.add(_rings.acquire()..reset(origin));
}
