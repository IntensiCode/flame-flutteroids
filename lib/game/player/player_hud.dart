import 'dart:math';

import 'package:flame/components.dart';
import 'package:flutteroids/core/common.dart';
import 'package:flutteroids/game/common/extra_id.dart';
import 'package:flutteroids/game/common/extras.dart';
import 'package:flutteroids/game/common/game_context.dart';
import 'package:flutteroids/game/common/messages.dart';
import 'package:flutteroids/game/player/deflector_shield.dart';
import 'package:flutteroids/game/player/player.dart';
import 'package:flutteroids/game/player/player_hud_background.dart';
import 'package:flutteroids/game/player/player_hud_indicator.dart';
import 'package:flutteroids/game/player/player_hud_title.dart';
import 'package:flutteroids/game/player/weapon_system.dart';
import 'package:flutteroids/ui/fonts.dart';
import 'package:flutteroids/util/auto_dispose.dart';
import 'package:flutteroids/util/bitmap_text.dart';
import 'package:flutteroids/util/extensions.dart';
import 'package:flutteroids/util/log.dart';
import 'package:flutteroids/util/on_message.dart';

class PlayerHud extends PositionComponent with AutoDispose, GameContext, HasPaint {
  PlayerHud(this._player) {
    size.x = game_size.x - min(game_size.x, game_size.y) - 32;
    size.y = game_size.y;
    log_verbose("Player HUD size: $size");

    add(PlayerHudBackground(hud_size: size));
    add(PlayerHudBackground(hud_size: Vector2(32, size.y))
      ..position = Vector2(game_size.x + 1, 0)
      ..scale.x = -1);

    add(PlayerHudTitle(
      text: 'FLUTTEROIDS',
      font: menu_font,
      scale: 0.5,
    )..position = Vector2(16, 16));

    add(_indicators = PositionComponent(position: Vector2(32, 64))
      ..add(BitmapText(text: 'SHIELD', position: Vector2(26, 0)))
      ..add(BitmapText(text: 'INTEGRITY', position: Vector2(26, 24)))
      ..add(BitmapText(text: 'COOLDOWN', position: Vector2(26, 48))));

    add(_primary = PositionComponent(position: Vector2(32, 128 + 16)));
    _primary.add(BitmapText(text: 'PRIMARY', position: Vector2(26, 0)));

    add(_secondary = PositionComponent(position: Vector2(32, 128 + 56)));
    _secondary.add(BitmapText(text: 'SECONDARY', position: Vector2(26, 0)));

    this.fadeInDeep();
  }

  final Map<ExtraId, double> _extra_blink_timer = {};
  final Map<ExtraId, SpriteComponent> _extra_blink_icon = {};

  final AsteroidsPlayer _player;
  late DeflectorShield _player_shield;
  late WeaponSystem _weapons;

  late PositionComponent _primary;
  late PositionComponent _secondary;
  late PositionComponent _indicators;

  BitmapText? _primary_label;
  BitmapText? _secondary_label;
  SpriteComponent? _primary_weapon;
  SpriteComponent? _secondary_weapon;

  @override
  void onMount() {
    super.onMount();

    _player_shield = _player.deflector_shield;
    _weapons = _player.weapon_system;

    double _shield_value() => _player_shield.integrity;
    double _integrity_value() => _player.integrity;
    double _cooldown_value() => _weapons.secondary_weapon != null ? 1 - (_weapons.secondary_cooldown ?? 1) : 0;

    final shield = _indicator_icon(Vector2(0, -1), ExtraId.shield);
    final integrity = _indicator_icon(Vector2(0, 21), ExtraId.integrity);
    final cooldown = _indicator_icon(Vector2(0, 45), ExtraId.cooldown);
    _indicators
      ..add(PlayerHudIndicator(_shield_value)..position = Vector2(26, 0))
      ..add(PlayerHudIndicator(_integrity_value)..position = Vector2(26, 24))
      ..add(PlayerHudIndicator(_cooldown_value)..position = Vector2(26, 48))
      ..add(shield)
      ..add(integrity)
      ..add(cooldown);

    _extra_blink_icon[ExtraId.shield] = shield;
    _extra_blink_icon[ExtraId.integrity] = integrity;
    _extra_blink_icon[ExtraId.cooldown] = cooldown;

    on_message<ExtraCollected>((msg) {
      _extra_blink_timer[msg.which] = pi / 4;
    });
  }

  SpriteComponent _indicator_icon(Vector2 pos, ExtraId extraId) => SpriteComponent()
    ..sprite = extras.icon_for(extraId)
    ..position = pos
    ..size = Vector2(20, 20);

  @override
  void update(double dt) {
    super.update(dt);

    _extra_blink_timer.updateAll((key, value) => max(0, value - dt));

    for (final entry in _extra_blink_timer.entries) {
      final extraId = entry.key;
      final timer = entry.value;
      if (timer <= 0) {
        _extra_blink_icon[extraId]?.opacity = 1.0;
      } else {
        _extra_blink_icon[extraId]?.opacity = (sin(timer * pi * 4) + 1) / 2;
      }
    }

    try {
      _update();
    } catch (e, s) {
      log_error('Error updating HUD: $e', s);
    }
  }

  void _update() {
    final primary = _weapons.primary_weapon?.display_name ?? '';
    if (_weapons.primary_weapon != null && _primary_label?.text != primary) {
      _primary_label?.removeFromParent();
      _primary.add(_primary_label = BitmapText(text: primary, position: Vector2(26, 16))..renderSnapshot = true);
      _primary_weapon ??= _primary.added(SpriteComponent()..position = Vector2(0, 2));
      _primary_weapon?.sprite = _weapons.primary_weapon?.icon;
      _primary_label?.fadeInDeep();
      _primary_weapon?.fadeInDeep();
    }

    final secondary = _weapons.secondary_weapon?.display_name ?? 'N/A';
    if (_secondary_label?.text != secondary) {
      _secondary_label?.removeFromParent();
      _secondary.add(_secondary_label = BitmapText(text: secondary, position: Vector2(26, 16))..renderSnapshot = true);
      _secondary_weapon ??= _secondary.added(SpriteComponent()..position = Vector2(0, 2));
      _secondary_weapon?.sprite = _weapons.secondary_weapon?.icon;
      if (_weapons.secondary_weapon == null) {
        _secondary_weapon?.removeFromParent();
      } else if (_secondary_weapon?.parent == null) {
        _secondary.add(_secondary_weapon!);
      }
      _secondary_label?.fadeInDeep();
      _secondary_weapon?.fadeInDeep();
    }
  }
}
