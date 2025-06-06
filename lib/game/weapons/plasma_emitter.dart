import 'dart:math';

import 'package:flame/components.dart';
import 'package:flutteroids/game/common/extra_id.dart';
import 'package:flutteroids/game/common/extras.dart';
import 'package:flutteroids/game/common/game_context.dart';
import 'package:flutteroids/game/common/kinds.dart';
import 'package:flutteroids/game/projectiles/plasma_blob.dart';
import 'package:flutteroids/game/projectiles/plasma_ring.dart';
import 'package:flutteroids/game/weapons/auto_target.dart';
import 'package:flutteroids/game/world/world.dart';
import 'package:flutteroids/game/world/world_entity.dart';
import 'package:flutteroids/util/component_recycler.dart';

class PlasmaEmitter extends Component with GameContext, SecondaryWeapon, AutoTarget {
  late final _blobs = ComponentRecycler(() => PlasmaBlob(_emit_plasma_ring))..precreate(8);
  late final _rings = ComponentRecycler(() => PlasmaRing())..precreate(8);

  PlasmaEmitter(this.player, Function(SecondaryWeapon) on_fired) {
    super.on_fired = on_fired;
  }

  @override
  final Player player;

  @override
  String get display_name => 'Plasma Emitter';

  @override
  Sprite get icon => extras.icon_for(ExtraId.plasma_ring);

  @override
  void do_fire() {
    final (_, angle) = auto_target_angle(
      player.world_pos,
      player.angle,
      max_spread: pi / 8,
    );
    world.add(_blobs.acquire()
      ..reset_homing(
        player,
        player.angle,
        target_angle: angle,
        boost: boost,
      ));
  }

  void _emit_plasma_ring(WorldEntity origin, [int boost = 0]) =>
      world.add(_rings.acquire()..reset(origin, boost + boost));
}
