import 'package:flutteroids/aural/audio_system.dart';
import 'package:flutteroids/background/space.dart';
import 'package:flutteroids/core/common.dart';
import 'package:flutteroids/game/asteroids/asteroids.dart';
import 'package:flutteroids/game/common/decals.dart';
import 'package:flutteroids/game/common/extra_id.dart';
import 'package:flutteroids/game/common/extras.dart';
import 'package:flutteroids/game/common/game_context.dart';
import 'package:flutteroids/game/common/game_phase.dart';
import 'package:flutteroids/game/common/level.dart';
import 'package:flutteroids/game/common/messages.dart';
import 'package:flutteroids/game/common/screens.dart';
import 'package:flutteroids/game/debug_overlay.dart';
import 'package:flutteroids/game/game_screen.dart';
import 'package:flutteroids/game/info_overlay.dart';
import 'package:flutteroids/game/player/player.dart';
import 'package:flutteroids/game/player/player_hud.dart';
import 'package:flutteroids/game/player/player_radar.dart';
import 'package:flutteroids/game/world/world.dart';
import 'package:flutteroids/game/world/world_camera.dart';
import 'package:flutteroids/util/log.dart';
import 'package:flutteroids/util/on_message.dart';

class GamePlayScreen extends GameScreen with GameContext, _GamePhaseTransition {
  @override
  Future onLoad() async {
    await audio.preload();
    await add(space);
    await add(level);
    await add(world);
    await world.add(asteroids);
    await world.add(player);
    await world.add(extras);
    await world.add(decals);
    await world.add(player_radar);
    await world.add(camera);
    await add(PlayerHud(player));
    await addAll([InfoOverlay(position: v2(408, game_height / 3))]);
  }

  @override
  void onMount() {
    super.onMount();

    if (dev) {
      onKey('<A-c>', () => _activate_phase(GamePhase.level_completed));
      onKey('<A-l>', () => _activate_phase(GamePhase.level_completed));
      onKey('<A-n>', () => change_level(1));
      onKey('<A-p>', () => change_level(-1));
      onKey('<A-S-N>', () => change_level(10));
      onKey('<A-S-P>', () => change_level(-10));
    }

    if (phase == GamePhase.inactive) {
      level.set_level(1);
      player.mounted.then((_) => _activate_phase(GamePhase.entering_level));
    }

    on_message<PlayerDestroyed>((_) => _pending_phase = GamePhase.game_over);
    on_message<PlayerLeft>((_) => _pending_phase = GamePhase.entering_level);

    on_message<AsteroidDestroyed>(_on_asteroid_destroyed);
    on_message<AsteroidSplit>(_on_asteroid_split);
  }

  void _on_asteroid_split(AsteroidSplit msg) {
    const split_extra_probability = 0.035;
    if (level_rng.nextDouble() < split_extra_probability) {
      extras.spawn(msg.asteroid, choices: ExtraId.defaults);
    }
  }

  void _on_asteroid_destroyed(AsteroidDestroyed msg) {
    final probability = (msg.asteroid.split_count * 0.09).clamp(0.0, 1.0);
    if (level_rng.nextDouble() < probability) {
      extras.spawn(msg.asteroid, choices: ExtraId.defaults);
    }
  }

  void change_level(int step) {
    current_level += step;
    if (current_level < 1) current_level = 1;
    show_debug("Entering level $current_level");
    _activate_phase(phase);
  }

  void next_level() {
    current_level += 1;
    show_debug("Next level: $current_level");
    _activate_phase(GamePhase.entering_level);
  }
}

mixin _GamePhaseTransition on GameScreen, GameContext {
  final _phase_duration = {
    GamePhase.entering_level: 2.0,
    GamePhase.playing_level: 0.0, // 0 means no auto-advance
    GamePhase.level_completed: 2.0,
    GamePhase.game_over: 3.0,
  };

  double _phase_timer = 0.0;
  GamePhase? _pending_phase;

  int current_level = 1;

  @override
  void update(double dt) {
    super.update(dt);
    _handle_phase_tick(dt);
    _auto_progression();
  }

  void _handle_phase_tick(double dt) {
    _phase_timer -= dt;
    if (_pending_phase != null && _phase_timer <= 0) {
      _activate_phase(_pending_phase);
      _pending_phase = null;
    }
  }

  void _auto_progression() {
    if (_phase_timer > 0) return;
    switch (phase) {
      case GamePhase.entering_level:
        _activate_phase(GamePhase.playing_level);
      case GamePhase.level_completed:
        _activate_phase(GamePhase.entering_level);
      case GamePhase.game_over:
        _activate_phase(GamePhase.inactive);
        show_screen(Screen.title);
      default:
        break;
    }
  }

  void _activate_phase(GamePhase? next) {
    _pending_phase = null;
    _phase_timer = _phase_duration[next] ?? 0.0;
    switch (next) {
      case GamePhase.entering_level:
        enter_level();
      case GamePhase.playing_level:
        play_level();
      case GamePhase.level_completed:
        level_complete();
        _pending_phase = GamePhase.entering_level;
      case GamePhase.game_over:
        game_over();
      case GamePhase.inactive:
        phase = GamePhase.inactive;
      case null:
        break;
    }
  }

  void enter_level({bool notify = true}) {
    phase = GamePhase.entering_level;
    // send_message(EnteringLevel(current_level));
    if (notify) {
      show_info(
        'Entering Asteroid Field...',
        title: 'GAME ON',
        longer: true,
        done: () {
          log_info('Entering level $current_level');
        },
      );
    }
  }

  void play_level() {
    phase = GamePhase.playing_level;
    // send_message(PlayingLevel(current_level));
  }

  void level_complete() {
    phase = GamePhase.level_completed;
    show_info(
      'Asteroid Field cleared!',
      title: 'LEVEL COMPLETE',
      longer: true,
    );
  }

  void game_over() {
    // TODO Handle hiscore here?
    phase = GamePhase.game_over;
    show_info(
      'Manta destroyed!',
      title: 'GAME OVER',
      longer: true,
    );
    audio.play(Sound.game_over);
  }
}
