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
import 'package:flutteroids/game/level_info.dart';
import 'package:flutteroids/game/player/player.dart';
import 'package:flutteroids/game/player/player_hud.dart';
import 'package:flutteroids/game/player/player_radar.dart';
import 'package:flutteroids/game/world/world.dart';
import 'package:flutteroids/game/world/world_camera.dart';
import 'package:flutteroids/game/world/world_entity.dart';
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
      onKey('<A-c>', () => _on_level_complete());
      onKey('<A-l>', () => _on_level_complete());
      onKey('<A-n>', () => change_level(1));
      onKey('<A-p>', () => change_level(-1));
      onKey('<A-S-N>', () => change_level(10));
      onKey('<A-S-P>', () => change_level(-10));
    }

    if (phase == GamePhase.inactive) {
      level.set_level(1);
      player.mounted.then((_) => _activate_phase(GamePhase.level_info));
    }

    on_message<LevelComplete>((it) => _on_level_complete(it.message));
    on_message<PlayerDestroyed>((_) => _activate_phase(GamePhase.game_over));

    on_message<AsteroidDestroyed>(_on_asteroid_destroyed);
    on_message<AsteroidSplit>(_on_asteroid_split);
  }

  void _on_level_complete([String? message]) {
    _complete_message = message;
    _activate_phase(GamePhase.level_completed);
  }

  void _on_asteroid_split(AsteroidSplit msg) {
    final probability = ((msg.asteroid.split_count + 1) * 0.1).clamp(0.0, 1.0);
    if (level_rng.nextDouble() > probability) return;

    final it = msg.asteroid;
    final count = (it.asteroid_radius ~/ 12).clamp(1, 5);
    final which = extras.choices_for(ExtrasGroup.asteroid_split);
    _spawn_extras(it, count, which);
  }

  void _on_asteroid_destroyed(AsteroidDestroyed msg) {
    final probability = ((msg.asteroid.split_count + 1) * 0.3).clamp(0.0, 1.0);
    if (level_rng.nextDouble() > probability) return;

    final it = msg.asteroid;
    final count = (it.asteroid_radius ~/ 8).clamp(1, 5);
    final which = extras.choices_for(ExtrasGroup.asteroid_destroyed);
    _spawn_extras(it, count, which);
  }

  void _spawn_extras(WorldEntity origin, int count, Set<ExtraId> which) {
    log_debug('Spawning $count extras (which: $which)');

    for (var i = 0; i < count; i++) {
      extras.spawn(origin, choices: which, index: i, count: count);
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
    _activate_phase(GamePhase.level_info);
  }
}

mixin _GamePhaseTransition on GameScreen, GameContext {
  // 0 means no auto-advance
  final _phase_duration = {
    GamePhase.level_info: 0.0,
    GamePhase.entering_level: 2.0,
    GamePhase.playing_level: 0.0,
    GamePhase.level_completed: 2.0,
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
      case GamePhase.entering_level:
        _activate_phase(GamePhase.playing_level);
      case GamePhase.level_completed:
        _activate_phase(GamePhase.level_info);
      case GamePhase.game_over:
        _activate_phase(GamePhase.inactive);
        show_screen(Screen.title);
      default:
        break;
    }
  }

  void _activate_phase(GamePhase? next) {
    removeAll(children.whereType<LevelInfo>());
    _pending_phase = null;
    _phase_timer = _phase_duration[next] ?? 0.0;
    switch (next) {
      case GamePhase.level_info:
        show_level_info();
      case GamePhase.entering_level:
        enter_level();
      case GamePhase.playing_level:
        play_level();
      case GamePhase.level_completed:
        level_complete();
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
      show_info('Entering Asteroid Field...', title: 'GAME ON', longer: true);
    }
  }

  void play_level() {
    phase = GamePhase.playing_level;
    // send_message(PlayingLevel(current_level));
  }

  void level_complete() {
    phase = GamePhase.level_completed;
    show_info(
      _complete_message ?? '',
      title: 'LEVEL COMPLETE',
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
        _pending_phase = GamePhase.entering_level;
        _phase_timer = 1;
      },
    ));
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
