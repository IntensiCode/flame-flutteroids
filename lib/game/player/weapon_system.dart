import 'dart:math';

import 'package:flame/components.dart';
import 'package:flutteroids/core/common.dart';
import 'package:flutteroids/core/messages.dart';
import 'package:flutteroids/game/common/extra_id.dart';
import 'package:flutteroids/game/common/game_context.dart';
import 'package:flutteroids/game/common/kinds.dart';
import 'package:flutteroids/game/weapons/auto_target_laser.dart';
import 'package:flutteroids/game/weapons/ion_pulse_gun.dart';
import 'package:flutteroids/game/weapons/nuke_missile_launcher.dart';
import 'package:flutteroids/game/weapons/plasma_emitter.dart';
import 'package:flutteroids/game/weapons/plasma_gun.dart';
import 'package:flutteroids/game/weapons/smart_bomb.dart';
import 'package:flutteroids/input/game_keys.dart';
import 'package:flutteroids/input/shortcuts.dart';
import 'package:flutteroids/util/auto_dispose.dart';
import 'package:flutteroids/util/log.dart';
import 'package:supercharged/supercharged.dart';

class WeaponSystem extends Component with AutoDispose, HasAutoDisposeShortcuts, GameContext {
  WeaponSystem(this.player);

  late Player player;

  PrimaryWeapon? primary_weapon;
  SecondaryWeapon? secondary_weapon;

  double? get secondary_cooldown {
    if (secondary_weapon != null) {
      var it = secondary_weapon as SecondaryWeapon;
      return it.cooldown / it.cooldown_time;
    } else {
      return null;
    }
  }

  final _extra_to_type = <ExtraId, Type>{
    ExtraId.plasma_gun: PlasmaGun,
    ExtraId.ion_pulse: IonPulseGun,
    ExtraId.auto_laser: AutoTargetLaser,
    ExtraId.plasma_ring: PlasmaEmitter,
    ExtraId.nuke_missile: NukeMissileLauncher,
    ExtraId.smart_bomb: SmartBomb,
  };

  final _acquired = <Type>{};
  final _primaries = <PrimaryWeapon, bool>{};
  final _secondaries = <SecondaryWeapon, int>{};

  bool has_acquired(Type type) => _acquired.contains(type);

  bool has_secondary() => _acquired.any((it) => it is SecondaryWeapon);

  void on_weapon(ExtraId id) {
    final type = _extra_to_type[id];
    if (_primaries.keys.any((it) => it.runtimeType == type)) {
      switch_primary_to(type!);
      _acquired.add(type);
    } else if (_secondaries.keys.any((it) => it.runtimeType == type)) {
      switch_secondary_to(type!);
      _acquired.add(type);
    } else {
      log_error('Unknown weapon type: $type');
      return;
    }
  }

  bool switch_primary_to(Type type, {bool by_user = false}) {
    final weapon = _primaries.keys.firstWhere((it) => it.runtimeType == type);
    if (!by_user) weapon.on_boost();

    // Switch only if by_user, or if this is newly picked up.
    if (!by_user && _primaries[weapon] == true) return false;

    // If the weapon is not available, make it available.
    _primaries[weapon] = true;

    // Now make sure it is the current primary weapon...
    primary_weapon?.removeFromParent();
    primary_weapon = weapon;
    add(primary_weapon!);

    return true;
  }

  void switch_secondary_to(Type type, {bool reload_and_boost = true}) {
    log_verbose('switch secondary to $type');
    final reload_count = _reload_count(type);

    final weapon = _secondaries.keys.firstWhere((it) => it.runtimeType == type);
    _secondaries[weapon] = (_secondaries[weapon] ?? 0) + (reload_and_boost ? reload_count : 0);
    if (reload_and_boost) log_debug('reloaded $type to ${_secondaries[weapon]}');
    if (reload_and_boost) weapon.on_boost();

    if (secondary_weapon == weapon) {
      if (dev) log_verbose('same secondary');
      return;
    }

    secondary_weapon?.removeFromParent();
    secondary_weapon = weapon;
    add(secondary_weapon!);

    secondary_weapon?.set_activation_guard();
  }

  int _reload_count(Type type) {
    int reload_count;
    if (type == SmartBomb) {
      reload_count = 1;
    } else if (type == PlasmaEmitter) {
      reload_count = 5;
    } else if (type == NukeMissileLauncher) {
      reload_count = 3;
    } else {
      reload_count = 3;
    }
    return reload_count;
  }

  // cooldown all secondary weapons:
  void on_cooldown() {
    for (final it in _secondaries.entries) {
      final weapon = it.key;
      weapon.cooldown = max(0, weapon.cooldown - weapon.cooldown_time * 0.25);
    }
  }

  @override
  void onMount() {
    super.onMount();

    _acquired.add(PlasmaGun);
    _primaries[PlasmaGun(player)] = true;
    _primaries[IonPulseGun(player)] = false;
    _primaries[AutoTargetLaser(player)] = false;

    _secondaries[PlasmaEmitter(player, _on_fired)] = 0;
    _secondaries[NukeMissileLauncher(player, _on_fired)] = 0;
    _secondaries[SmartBomb(player, _on_fired)] = 0;

    player = parent as Player;
    primary_weapon = _primaries.keys.first;
    add(primary_weapon!);

    // final initial = _secondaries.keys.whereNot((it) => it is SmartBomb).toList().random(level_rng);
    // switch_secondary_to(initial.runtimeType);

    if (dev || cheat) {
      onKey('[', () {
        log_info('make all weapons available');
        _primaries.forEach((key, value) => _primaries[key] = true);
        _secondaries.forEach((key, value) => _secondaries[key] = 10);
        switch_secondary_to(_secondaries.keys.first.runtimeType);
        send_message(ShowDebugText(text: 'Grant All Weapons', title: 'Cheat'));
      });
    }
  }

  void _on_fired(SecondaryWeapon weapon) {
    final count = _secondaries[weapon];
    if (count == null || count <= 0) return;
    _secondaries[weapon] = count - 1;
    if (count == 1) {
      weapon.cooldown = 0;
      _switch_secondary();
    } else {
      weapon.cooldown = weapon.cooldown_time;
    }
  }

  @override
  void update(double dt) {
    super.update(dt);

    if (player.weapons_hot) {
      if (keys.check_and_consume(GameKey.x_button)) _switch_primary();
      if (keys.check_and_consume(GameKey.y_button)) _switch_secondary();
    }

    // update cooldown for all secondary weapons:
    for (final it in _secondaries.entries) {
      final weapon = it.key;
      weapon.cooldown = max(0, weapon.cooldown - dt);
    }
  }

  void _switch_primary() {
    final bank = _primaries.entries.filter((it) => it.value).toList();
    if (bank.isEmpty) return;

    final index = bank.indexWhere((it) => it.key == primary_weapon);
    final next = bank[(index + 1) % bank.length];
    if (next.key == primary_weapon) return;

    switch_primary_to(next.key.runtimeType, by_user: true);
  }

  void _switch_secondary() {
    final bank = _secondaries.entries.filter((it) => it.value > 0).toList();
    if (bank.isEmpty) {
      secondary_weapon?.removeFromParent();
      secondary_weapon = null;
      return;
    }

    final index = bank.indexWhere((it) => it.key == secondary_weapon);
    final next = bank[(index + 1) % bank.length];
    if (next.key == secondary_weapon) return;

    switch_secondary_to(next.key.runtimeType, reload_and_boost: false);
  }
}
