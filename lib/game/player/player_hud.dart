import 'dart:math';
import 'dart:ui';

import 'package:flame/components.dart';
import 'package:flutteroids/core/common.dart';
import 'package:flutteroids/game/common/animated_title.dart';
import 'package:flutteroids/game/common/extra_id.dart';
import 'package:flutteroids/game/common/extras.dart';
import 'package:flutteroids/game/common/game_context.dart';
import 'package:flutteroids/game/common/game_phase.dart';
import 'package:flutteroids/game/common/hiscore.dart';
import 'package:flutteroids/game/common/messages.dart';
import 'package:flutteroids/game/common/sound.dart';
import 'package:flutteroids/game/info_overlay.dart';
import 'package:flutteroids/game/player/deflector_shield.dart';
import 'package:flutteroids/game/player/player.dart';
import 'package:flutteroids/game/player/player_hud_background.dart';
import 'package:flutteroids/game/player/player_hud_indicator.dart';
import 'package:flutteroids/game/player/weapon_system.dart';
import 'package:flutteroids/ui/fonts.dart';
import 'package:flutteroids/util/auto_dispose.dart';
import 'package:flutteroids/util/bitmap_font.dart';
import 'package:flutteroids/util/bitmap_text.dart';
import 'package:flutteroids/util/effects.dart';
import 'package:flutteroids/util/extensions.dart';
import 'package:flutteroids/util/log.dart';
import 'package:flutteroids/util/on_message.dart';

class PlayerHud extends PositionComponent with AutoDispose, GameContext {
  PlayerHud(this._player) {
    size.x = game_size.x - min(game_size.x, game_size.y) - 32;
    size.y = game_size.y;
    log_verbose("Player HUD size: $size");

    add(PlayerHudBackground(hud_size: size));
    add(PlayerHudBackground(hud_size: Vector2(32, size.y))
      ..position = Vector2(game_size.x + 1, 0)
      ..scale.x = -1);

    const title = 24.0;
    const hiscore_top = 64.0;
    const score_top = hiscore_top + 40.0;
    const indicators_top = score_top + 56.0;
    const offset1 = indicators_top + 80.0;
    const offset2 = offset1 + 40.0;

    add(PositionComponent(position: Vector2(32, hiscore_top))
      ..add(BitmapText(text: 'HISCORE', position: Vector2(26, 0)))
      ..add(_hiscore_value = BitmapText(text: '${hiscore.top_hiscore}', position: Vector2(26, 16))));

    add(PositionComponent(position: Vector2(32, score_top))
      ..add(BitmapText(text: 'SCORE', position: Vector2(26, 0)))
      ..add(_score_value = BitmapText(text: '${_player.score}', position: Vector2(26, 16))));

    add(_indicators = PositionComponent(position: Vector2(32, indicators_top))
      ..add(BitmapText(text: 'SHIELD', position: Vector2(26, 2)))
      ..add(BitmapText(text: 'INTEGRITY', position: Vector2(26, 26)))
      ..add(BitmapText(text: 'COOLDOWN', position: Vector2(26, 50))));

    add(AnimatedTitle(
      text: 'FLUTTEROIDS',
      font: menu_font,
      scale: 0.5,
    )..position = Vector2(16, title));

    add(_primary = PositionComponent(position: Vector2(32, offset1)));
    _primary.add(BitmapText(text: 'PRIMARY', position: Vector2(26, 0)));

    add(_secondary = PositionComponent(position: Vector2(32, offset2)));
    _secondary.add(BitmapText(text: 'SECONDARY', position: Vector2(26, 0)));

    this.fadeInDeep();
  }

  final _extra_blink_timer = <ExtraId, double>{};
  final _extra_blink_icon = <ExtraId, SpriteComponent>{};
  final _repeat_notify = <ExtraId>{ExtraId.nuke_missile, ExtraId.plasma_ring, ExtraId.smart_bomb};
  final _notified = <ExtraId>{};

  final AsteroidsPlayer _player;
  late DeflectorShield _player_shield;
  late WeaponSystem _weapons;

  late PositionComponent _primary;
  late PositionComponent _secondary;
  late PositionComponent _indicators;

  late BitmapText _hiscore_value;
  late BitmapText _score_value;
  BitmapText? _primary_label;
  BitmapText? _secondary_label;
  SpriteComponent? _primary_weapon;
  SpriteComponent? _secondary_weapon;

  int _displayed_score = 0;
  double _score_per_second = 1000.0;
  bool _is_hiscore_rank = false;
  bool _is_new_hiscore = false;

  @override
  void onMount() {
    super.onMount();

    final current_hiscore = hiscore.top_hiscore.toString();
    if (_hiscore_value.text != current_hiscore) {
      _hiscore_value.text = current_hiscore;
    }

    _player_shield = _player.deflector_shield;
    _weapons = _player.weapon_system;

    double _shield_value() => _player_shield.integrity;
    double _integrity_value() => _player.integrity;
    double _cooldown_value() => _weapons.secondary_weapon != null ? 1 - (_weapons.secondary_cooldown ?? 1) : 0;

    final shield = _indicator_icon(Vector2(0, -0.5), ExtraId.shield);
    final integrity = _indicator_icon(Vector2(0, 23.5), ExtraId.integrity);
    final cooldown = _indicator_icon(Vector2(0, 47.5), ExtraId.cooldown);
    _indicators
      ..add(PlayerHudIndicator(_shield_value)..position = Vector2(26, 2))
      ..add(PlayerHudIndicator(_integrity_value)..position = Vector2(26, 26))
      ..add(PlayerHudIndicator(_cooldown_value)..position = Vector2(26, 50))
      ..add(shield)
      ..add(integrity)
      ..add(cooldown);

    _extra_blink_icon[ExtraId.shield] = shield;
    _extra_blink_icon[ExtraId.integrity] = integrity;
    _extra_blink_icon[ExtraId.cooldown] = cooldown;

    on_message<ExtraCollected>((msg) {
      _extra_blink_timer[msg.which] = pi / 4;
      if (!_notified.contains(msg.which)) {
        log_debug('Playing extra collected sound for ${msg.which.name}');
        play_one_shot('voice/${msg.which.name}');

        // Play only once for common extras
        if (!_repeat_notify.contains(msg.which)) _notified.add(msg.which);

        show_info(switch (msg.which) {
          ExtraId.auto_laser => 'AUTO LASER',
          ExtraId.cooldown => 'SECONDARY COOLDOWN',
          ExtraId.integrity => 'INTEGRITY BOOST',
          ExtraId.ion_pulse => 'ION PULSE',
          ExtraId.nuke_missile => 'NUKE MISSILE',
          ExtraId.plasma_gun => 'PLASMA GUN',
          ExtraId.plasma_ring => 'PLASMA RING',
          ExtraId.shield => 'SHIELD BOOST',
          ExtraId.smart_bomb => 'SMART BOMB',
        });
      }
    });

    on_message<GamePhaseUpdate>((msg) {
      switch (msg.phase) {
        case GamePhase.enter_level:
          play_one_shot('voice/game_on');
        case GamePhase.level_complete:
          play_one_shot('voice/level_complete');
        case GamePhase.game_over:
          play_sound(Sound.game_over);
          play_one_shot('voice/game_over');
        default:
          break;
      }
    });
  }

  SpriteComponent _indicator_icon(Vector2 pos, ExtraId extraId) => SpriteComponent()
    ..sprite = extras.icon_for(extraId)
    ..position = pos
    ..size = Vector2(20, 20);

  @override
  void update(double dt) {
    super.update(dt);

    _blink_icons(dt);
    _update_animated_score(dt);
    _check_hiscore_status();

    _update_primary_weapon();
    _update_secondary_weapon();
  }

  void _blink_icons(double dt) {
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
  }

  void _update_animated_score(double dt) {
    final target_score = _player.score;
    if (_displayed_score == target_score) return;

    final diff = target_score - _displayed_score;

    // Adjust animation speed based on difference
    if (diff.abs() > 10000) {
      _score_per_second = 100000.0;
    } else if (diff.abs() > 1000) {
      _score_per_second = 10000.0;
    } else {
      _score_per_second = 1000.0;
    }

    // Calculate increment based on dt and score_per_second
    final increment = (_score_per_second * dt).ceil();

    // Apply increment (or decrement)
    if (diff > 0) {
      _displayed_score += min(increment, diff);
    } else {
      _displayed_score -= min(increment, -diff);
    }

    _score_value.text = _displayed_score.toString();
  }

  void _check_hiscore_status() {
    // Check if player has achieved a hiscore rank
    if (!_is_hiscore_rank && hiscore.is_hiscore_rank(_displayed_score)) {
      _is_hiscore_rank = true;
      _score_value.add(BlinkEffect());
    }

    // Check if player has achieved a new top hiscore
    if (!_is_new_hiscore && hiscore.is_new_hiscore(_displayed_score)) {
      _is_new_hiscore = true;

      // Remove blink from score
      _score_value.removeWhere((it) => it is BlinkEffect);

      // Add blink to hiscore and update hiscore value
      _hiscore_value.add(BlinkEffect());
      _hiscore_value.text = _displayed_score.toString();

      play_one_shot('voice/hiscore');
    }

    // Check if score > hiscore
    if (_displayed_score > hiscore.top_hiscore) {
      _hiscore_value.text = _displayed_score.toString();
    }
  }

  void _update_primary_weapon() {
    final primary = _weapons.primary_weapon?.display_name ?? '';

    // Add boost info in dev mode
    var display_text = primary;
    if (_weapons.primary_weapon != null && _weapons.primary_weapon!.boost > 0) {
      display_text = '$primary ${_weapons.primary_weapon!.boost}x';
    }

    if (_weapons.primary_weapon == null || _primary_label?.text == display_text) {
      return;
    }
    _primary_label?.removeFromParent();
    _primary.add(_primary_label = BitmapText(text: display_text, position: Vector2(26, 16))..renderSnapshot = true);
    _primary_weapon ??= _primary.added(SpriteComponent()..position = Vector2(0, 2));
    _primary_weapon?.sprite = _weapons.primary_weapon?.icon;
    _primary_label?.fadeInDeep();
    _primary_weapon?.fadeInDeep();
  }

  void _update_secondary_weapon() {
    final secondary = _weapons.secondary_weapon?.display_name ?? 'N/A';

    // Add boost info in dev mode
    var display_text = secondary;
    if (_weapons.secondary_weapon != null && _weapons.secondary_weapon!.boost > 0) {
      display_text = '$secondary ${_weapons.secondary_weapon!.boost}x';
    }

    if (_weapons.secondary_weapon == null || _secondary_label?.text == display_text) {
      return;
    }
    _secondary_label?.removeFromParent();
    _secondary.add(_secondary_label = BitmapText(text: display_text, position: Vector2(26, 16))..renderSnapshot = true);
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

  @override
  void render(Canvas canvas) {
    if (player.jumping_countdown > 0) {
      final it = (player.jumping_countdown + 0.5).clamp(0, 5).toInt();
      if (it > 0) {
        tiny_font.scale = 1.0;
        tiny_font.tint = white;
        tiny_font.drawStringAligned(canvas, 408, 350, "JUMPING IN $it", Anchor.center);
      }
    }
  }
}
