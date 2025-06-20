import 'dart:math';
import 'dart:ui';

import 'package:flame/components.dart';
import 'package:flutteroids/aural/audio_system.dart';
import 'package:flutteroids/core/common.dart';
import 'package:flutteroids/core/messages.dart';
import 'package:flutteroids/game/common/game_context.dart';
import 'package:flutteroids/game/common/game_phase.dart';
import 'package:flutteroids/game/common/messages.dart';
import 'package:flutteroids/game/common/screens.dart';
import 'package:flutteroids/game/common/stage_cache.dart';
import 'package:flutteroids/input/keys.dart';
import 'package:flutteroids/input/shortcuts.dart';
import 'package:flutteroids/ui/fonts.dart';
import 'package:flutteroids/ui/soft_keys.dart';
import 'package:flutteroids/util/bitmap_text.dart';
import 'package:flutteroids/util/game_script.dart';
import 'package:flutteroids/util/log.dart';
import 'package:flutteroids/util/messaging.dart';
import 'package:flutteroids/util/on_message.dart';

abstract class GameScreen extends GameScriptComponent with HasAutoDisposeShortcuts, HasTimeScale, HasVisibility {
  GameScreen() {
    add(stage_keys);
    add(stage_cache);
  }

  final stage_keys = Keys();
  final stage_cache = StageCache();

  GamePhase _phase = GamePhase.inactive;

  GamePhase get phase => _phase;

  set phase(GamePhase value) {
    if (_phase == value) return;
    _phase = value;
    log_debug('Game phase changed to $_phase');
    send_message(GamePhaseUpdate(_phase));
  }

  bool _paused = false;

  @override
  void onMount() {
    super.onMount();

    on_message<Rumble>((it) => _rumble(it));

    if (cheat) {
      log_debug('Activate cheat keys');
    }
    if (dev) {
      onKey('-', () => _change_time_scale(-0.25));
      onKey('+', () => _change_time_scale(0.25));
    }

    enable_mapping = true;
  }

  // void _flash_screen(SuperZapper message) {
  //   log_info('Flash screen ${message.all}');
  //   game_post_process = FlashScreen(seconds: message.all ? 0.5 : 0.2);
  // }

  double _rumble_time = 0;

  void _rumble(Rumble it) {
    final shake_time = it.duration * 2;
    if (_rumble_time > shake_time * 0.75) return;
    _rumble_time = shake_time;

    if (it.haptic) stage_keys.rumble(it.duration ~/ 0.001);
  }

  @override
  void onRemove() {
    super.onRemove();
    enable_mapping = false;
  }

  void _change_time_scale(double delta) {
    timeScale += delta;
    log_info('Time scale: ${timeScale.toStringAsFixed(2)}');
    if (timeScale < 0.25) timeScale = 0.25;
    if (timeScale > 4.0) timeScale = 4.0;
    send_message(ShowDebugText(text: 'Time scale: ${timeScale.toStringAsFixed(2)}', title: 'Cheat'));
  }

  @override
  void update(double dt) {
    super.update(dt);

    if (stage_keys.any([GameKey.start, GameKey.soft1])) {
      if (!_paused) {
        _paused = true;
        audio.update_paused(_paused);
        add(_pause_overlay);
      }
    }

    _on_rumble(dt);
  }

  final _rumble_off = Vector2.zero();

  void _on_rumble(double dt) {
    if (_rumble_time <= 0) {
      _rumble_time = 0;
      _rumble_off.setZero();
    } else {
      _rumble_time = max(0, _rumble_time - dt);
      _rumble_off.x = sin(_rumble_time * 913.527) * 4;
      _rumble_off.y = cos(_rumble_time * 715.182) * 4;
    }
  }

  late final _pause_overlay = _PauseOverlay(() {
    _paused = false;
    audio.update_paused(_paused);
  });

  @override
  void updateTree(double dt) {
    if (!isVisible) return;
    if (_paused) {
      _pause_overlay.update(dt);
      stage_keys.update(dt);
      return;
    }
    super.updateTree(dt);
  }

  @override
  void renderTree(Canvas canvas) {
    canvas.translate(_rumble_off.x, _rumble_off.y);
    super.renderTree(canvas);
  }
}

class _PauseOverlay extends GameScriptComponent with GameContext {
  _PauseOverlay(this.on_resume) {
    add(RectangleComponent(size: game_size)..paint.color = const Color(0x80000000));
    add(BitmapText(text: 'PAUSED', position: v2(408, 200), font: menu_font, anchor: Anchor.center));
    softkeys('Resume', 'Exit', (it) {
      if (it == SoftKey.left) _resume();
      if (it == SoftKey.right) _back_to_title();
    });
    priority = 1000000;
  }

  void _resume() {
    log_debug('Resuming');
    removeFromParent();
    on_resume();
  }

  void _back_to_title() {
    log_debug('Exiting to title');
    show_screen(Screen.title);
    _resume();
  }

  final Function on_resume;

  @override
  void update(double dt) {
    super.update(dt);
    if (keys.check_and_consume(GameKey.a_button)) _resume();
    if (keys.check_and_consume(GameKey.b_button)) _resume();
    if (keys.check_and_consume(GameKey.select)) _back_to_title();
    if (keys.check_and_consume(GameKey.start)) _resume();
    if (keys.check_and_consume(GameKey.soft1)) _resume();
    if (keys.check_and_consume(GameKey.soft2)) _back_to_title();
  }
}
