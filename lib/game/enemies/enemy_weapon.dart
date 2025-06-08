import 'dart:math';

import 'package:flame/components.dart';
import 'package:flutteroids/core/common.dart';
import 'package:flutteroids/game/common/game_context.dart';
import 'package:flutteroids/game/common/kinds.dart';
import 'package:flutteroids/game/common/sound.dart';
import 'package:flutteroids/game/enemies/enemy_projectile.dart';
import 'package:flutteroids/game/world/world.dart';
import 'package:flutteroids/util/component_recycler.dart';
import 'package:flutteroids/util/log.dart';
import 'package:flutteroids/util/random.dart';

class EnemyWeapon extends Component with GameContext {
  late final _projectiles = ComponentRecycler(() => EnemyProjectile())..precreate(4);

  EnemyWeapon(this._enemy);

  final Target _enemy;

  var fire_rate = 1.0;
  var _cooldown = 0.0;

  bool get can_fire => _cooldown <= 0;

  @override
  void update(double dt) {
    if (_cooldown > 0) _cooldown = max(0, _cooldown - dt);
  }

  void fire_at_target(Target target) {
    if (!can_fire) {
      log_debug('EnemyWeapon: Cannot fire, cooldown active');
      return;
    }

    _cooldown = fire_rate + level_rng.nextDoubleLimit(fire_rate * 0.1);

    // Calculate angle to target
    final direction = target.world_pos - _enemy.world_pos;
    final angle = direction.screenAngle() - pi / 2;
    log_debug('EnemyWeapon: Firing at target at angle $angle (${direction.x}, ${direction.y})');

    // Fire projectile
    world.add(_projectiles.acquire()..reset_from_hostile(_enemy, angle));

    play_sound(Sound.shot, volume_factor: 0.3);
  }
}
