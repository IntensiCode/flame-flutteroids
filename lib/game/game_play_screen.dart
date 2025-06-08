import 'package:flame/components.dart';
import 'package:flutteroids/aural/audio_system.dart';
import 'package:flutteroids/background/space.dart';
import 'package:flutteroids/core/common.dart';
import 'package:flutteroids/game/asteroids/asteroids.dart';
import 'package:flutteroids/game/common/decals.dart';
import 'package:flutteroids/game/common/explosions.dart';
import 'package:flutteroids/game/common/extras.dart';
import 'package:flutteroids/game/common/game_context.dart';
import 'package:flutteroids/game/common/game_phase.dart';
import 'package:flutteroids/game/common/messages.dart';
import 'package:flutteroids/game/common/screens.dart';
import 'package:flutteroids/game/debug_overlay.dart';
import 'package:flutteroids/game/game_screen.dart';
import 'package:flutteroids/game/info_overlay.dart';
import 'package:flutteroids/game/level/level.dart';
import 'package:flutteroids/game/level/warp_transition.dart';
import 'package:flutteroids/game/level_bonus.dart';
import 'package:flutteroids/game/level_info.dart';
import 'package:flutteroids/game/player/player.dart';
import 'package:flutteroids/game/player/player_hud.dart';
import 'package:flutteroids/game/player/player_radar.dart';
import 'package:flutteroids/game/world/world.dart';
import 'package:flutteroids/game/world/world_camera.dart';
import 'package:flutteroids/ui/fonts.dart';
import 'package:flutteroids/util/bitmap_text.dart';
import 'package:flutteroids/util/extensions.dart';
import 'package:flutteroids/util/log.dart';
import 'package:flutteroids/util/on_message.dart';

class GamePlayScreen extends GameScreen with GameContext, _GamePhaseTransition {
  Component? _loading;

  @override
  Future onLoad() async {
    await add(space);

    add(_loading = BitmapText(
      text: 'LOADING...',
      position: v2(408, 32),
      font: tiny_font,
      anchor: Anchor.topCenter,
    )
      ..fadeInDeep()
      ..priority = 1000);

    Future.delayed(Duration(milliseconds: 1)).then(_load);
  }

  Future _load(dynamic _) async {
    await audio.preload();
    await add(level);
    await add(world);
    await add(camera);
    await add(explosions); // for preloading the shader
    await add(asteroids);
    await add(extras);
    await add(decals);
    await world.add(player);
    await world.add(player_radar);
    await add(PlayerHud(player));
    await add(InfoOverlay(position: v2(408, game_height / 3)));
  }

  @override
  void onMount() {
    super.onMount();

    removeWhere((it) => it == _loading);

    if (dev) {
      onKey('<A-c>', () => _on_level_complete());
      onKey('<A-l>', () => _on_level_complete());
      onKey('<A-n>', () => change_level(1));
      onKey('<A-p>', () => change_level(-1));
      onKey('<A-s>', () => player.score += 10000);
      onKey('<A-S-N>', () => change_level(10));
      onKey('<A-S-P>', () => change_level(-10));
      onKey('<A-x>', () => player.on_hit(100, player.world_pos));
    }

    if (phase == GamePhase.inactive) {
      level.set_level(1);
      player.mounted.then((_) => _activate_phase(GamePhase.level_info));
    }

    on_message<LevelComplete>((it) => _on_level_complete(it.message));
    on_message<PlayerDestroyed>((_) => _activate_phase(GamePhase.game_over));
    on_message<PlayerLeft>((_) => _on_player_left());
  }

  void _on_level_complete([String? message]) {
    _complete_message = message;
    _activate_phase(GamePhase.level_complete);
  }

  void _on_player_left() {
    _pending_phase = GamePhase.level_bonus;
    _phase_timer = 0.5;
  }

  void change_level(int step) {
    current_level += step;
    if (current_level < 1) current_level = 1;
    show_debug("Entering level $current_level");
    level.set_level(current_level);
    _activate_phase(GamePhase.level_info);
  }
}

mixin _GamePhaseTransition on GameScreen, GameContext {
  // 0 means no auto-advance
  final _phase_duration = {
    GamePhase.level_info: 0.0,
    GamePhase.enter_level: 2.0,
    GamePhase.play_level: 0.0,
    GamePhase.level_complete: 0.0,
    GamePhase.level_bonus: 0.0,
    GamePhase.game_over: 3.0,
  };

  double _phase_timer = 0.0;
  GamePhase? _pending_phase;
  String? _complete_message;

  int current_level = 1;

  @override
  void update(double dt) {
    super.update(dt);
    _handle_phase_tick(dt);
    _auto_progression();
  }

  void _handle_phase_tick(double dt) {
    if (_phase_timer > 0) _phase_timer = (_phase_timer - dt).clamp(0.0, _phase_timer);
    if (_pending_phase != null && _phase_timer <= 0) {
      _activate_phase(_pending_phase);
      _pending_phase = null;
    }
  }

  void _auto_progression() {
    if (_phase_timer > 0) return;
    switch (phase) {
      case GamePhase.enter_level:
        _activate_phase(GamePhase.play_level);
      case GamePhase.game_over:
        _activate_phase(GamePhase.inactive);
        show_screen(Screen.title);
      default:
        break;
    }
  }

  void _activate_phase(GamePhase? next) {
    removeAll(children.whereType<LevelInfo>());
    removeAll(children.whereType<LevelBonus>());
    world.removeAll(world.children.whereType<WarpTransition>());

    _pending_phase = null;
    _phase_timer = _phase_duration[next] ?? 0.0;
    switch (next) {
      case GamePhase.level_info:
        show_level_info();
      case GamePhase.enter_level:
        enter_level();
      case GamePhase.play_level:
        play_level();
      case GamePhase.level_complete:
        level_complete();
      case GamePhase.level_bonus:
        show_level_bonus();
      case GamePhase.game_over:
        game_over();
      case GamePhase.inactive:
        phase = GamePhase.inactive;
      case null:
        break;
    }
  }

  void enter_level({bool notify = true}) {
    phase = GamePhase.enter_level;
    // send_message(EnteringLevel(current_level));
    if (notify) {
      show_info('ENTERING ASTEROID FIELD', title: 'GAME ON', longer: true);
    }
  }

  void play_level() {
    phase = GamePhase.play_level;
    // send_message(PlayingLevel(current_level));
  }

  void level_complete() {
    phase = GamePhase.level_complete;
    show_info(
      _complete_message ?? '',
      title: 'LEVEL COMPLETE',
      secondary: 'CLEAR REMAINING ASTEROIDS',
      longer: true,
    );
  }

  void show_level_info() {
    phase = GamePhase.level_info;

    final level_title = 'LEVEL $current_level';
    final level_description = level.tagline;
    log_debug('Showing level info: $level_title - $level_description');
    add(LevelInfo(
      title: level_title,
      text: level_description,
      position: v2(408, game_height / 3),
      on_done: () {
        _pending_phase = GamePhase.enter_level;
        _phase_timer = 0.5;
      },
    ));
  }

  void game_over() {
    // TODO Handle hiscore here?
    phase = GamePhase.game_over;
    show_info(
      'ALL HOPE IS LOST',
      title: 'GAME OVER',
      longer: true,
    );
  }

  void show_level_bonus() {
    phase = GamePhase.level_bonus;

    _start_warp_transition();

    log_debug('Showing level bonus screen');
    add(LevelBonus(
      position: v2(408, game_height / 3),
      on_done: () => _warp_transition?.leave_warp(),
    ));
  }

  WarpTransition? _warp_transition;

  void _start_warp_transition() {
    log_debug('Starting warp transition');
    world.add(_warp_transition = WarpTransition(
      on_complete: () => _next_level(),
    ));
  }

  void _next_level() {
    log_debug('Advancing to next level');
    // _pending_phase = GamePhase.level_info;
    // _phase_timer = 0.5;
    current_level += 1;
    level.set_level(current_level);
    show_debug("Next level: $current_level");
    _activate_phase(GamePhase.level_info);
  }
}
