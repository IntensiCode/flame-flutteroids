import 'package:collection/collection.dart';
import 'package:flame/collisions.dart';
import 'package:flame/components.dart';
import 'package:flutteroids/aural/audio_menu.dart';
import 'package:flutteroids/core/common.dart';
import 'package:flutteroids/credits.dart';
import 'package:flutteroids/game/common/configuration.dart';
import 'package:flutteroids/game/common/screens.dart';
import 'package:flutteroids/game/debug_overlay.dart';
import 'package:flutteroids/game/enter_hiscore_screen.dart';
import 'package:flutteroids/game/game_play_screen.dart';
import 'package:flutteroids/game/hiscore_screen.dart';
import 'package:flutteroids/input/controls.dart';
import 'package:flutteroids/input/select_game_pad.dart';
import 'package:flutteroids/input/shortcuts.dart';
import 'package:flutteroids/post/fade_screen.dart';
import 'package:flutteroids/post/post_process.dart';
import 'package:flutteroids/title/title_screen.dart';
import 'package:flutteroids/util/auto_dispose.dart';
import 'package:flutteroids/util/extensions.dart';
import 'package:flutteroids/util/grab_input.dart';
import 'package:flutteroids/util/log.dart';
import 'package:flutteroids/util/messaging.dart';
import 'package:flutteroids/util/on_message.dart';
import 'package:flutteroids/video_menu.dart';
import 'package:flutteroids/web_play_screen.dart';

class MainController extends World
    with AutoDispose, HasAutoDisposeShortcuts, HasCollisionDetection<Sweep<ShapeHitbox>>
    implements ScreenNavigation {
  //
  final _screen_holder = PostFxScreenHolder();

  Iterable<Component> get _screens => _screen_holder.children;

  @override // IIRC this is to have the SelectGamePad screen capture all input!?
  bool get is_active => !_screens.any((it) => it is GrabInput);

  final _stack = <Screen>[];

  @override
  onLoad() async {
    super.onLoad();
    add(_screen_holder);
    await configuration.load();
    on_message<ShowScreen>((it) => show_screen(it.screen));
  }

  @override
  void onMount() {
    super.onMount();

    if (dev) {
      show_screen(Screen.game);
    } else {
      _screen_holder.add(WebPlayScreen());
    }

    if (dev) {
      onKeys(['<A-d>', '='], (_) {
        debug << !~debug;
        log_level = ~debug ? LogLevel.debug : LogLevel.info;
        show_debug("Debug Mode: $debug");
      });
      onKeys(['<A-v>'], (_) {
        if (log_level == LogLevel.verbose) {
          log_level = ~debug ? LogLevel.debug : LogLevel.info;
        } else {
          log_level = LogLevel.verbose;
        }
      });

      onKeys(['1'], (_) => push_screen(Screen.game));
      onKeys(['`'], (_) {
        pop_screen();
        _screen_holder.add(WebPlayScreen());
      });
      onKeys(['5'], (_) => push_screen(Screen.hiscore));
      onKeys(['6'], (_) => push_screen(Screen.credits));
      onKeys(['7'], (_) => push_screen(Screen.controls));
      onKeys(['8'], (_) => push_screen(Screen.audio));
      onKeys(['9'], (_) => push_screen(Screen.video));
      onKeys(['0'], (_) => show_screen(Screen.title));
    }
  }

  void _log(String hint) {
    log_info('$hint (stack=$_stack children=${_screens.map((it) => it.runtimeType)})');
  }

  @override
  void pop_screen() {
    _log('pop screen');
    show_screen(_stack.removeLastOrNull() ?? Screen.title);
  }

  @override
  void push_screen(Screen it) {
    _log('push screen: $it triggered: $_triggered');
    if (_stack.lastOrNull == it) throw 'stack already contains $it';
    if (_triggered != null) _stack.add(_triggered!);
    show_screen(it);
  }

  Screen? _triggered;
  StackTrace? _previous;

  @override
  void show_screen(Screen screen, {ScreenTransition transition = ScreenTransition.fade_out_then_in}) {
    if (_triggered == screen) {
      _log('show $screen');
      log_error('duplicate trigger ignored: $screen previous: $_previous', StackTrace.current);
      return;
    }
    _triggered = screen;
    _previous = StackTrace.current;

    if (_screens.length > 1) _log('show $screen');

    void call_again() {
      // still the same? you never know.. :]
      if (_triggered == screen) {
        _triggered = null;
        show_screen(screen, transition: transition);
      } else {
        log_warn('triggered screen changed: $screen != $_triggered');
        log_warn('show $screen with stack=$_stack and children=${_screens.map((it) => it.runtimeType)}');
      }
    }

    const fade_duration = 0.2;

    final out = _screens.lastOrNull;
    if (out != null) {
      switch (transition) {
        case ScreenTransition.cross_fade:
          game_post_process = FadeScreen.fade_out(seconds: fade_duration, and_remove: out);
          break;
        case ScreenTransition.fade_out_then_in:
          game_post_process = FadeScreen.fade_out(seconds: fade_duration, and_remove: out);
          out.removed.then((_) => call_again());
          return;
        case ScreenTransition.switch_in_place:
          out.removeFromParent();
          break;
        case ScreenTransition.remove_then_add:
          out.removeFromParent();
          out.removed.then((_) => call_again());
          return;
      }
    }

    final it = _screen_holder.added(_makeScreen(screen));
    switch (transition) {
      case ScreenTransition.cross_fade:
        it.mounted.then((_) {
          game_post_process = FadeScreen.fade_in(seconds: fade_duration);
        });
        break;
      case ScreenTransition.fade_out_then_in:
        it.mounted.then((_) {
          game_post_process = FadeScreen.fade_in(seconds: fade_duration);
        });
        break;
      case ScreenTransition.switch_in_place:
        break;
      case ScreenTransition.remove_then_add:
        break;
    }

    messaging.send(ScreenShowing(screen));
  }

  Component _makeScreen(Screen it) => switch (it) {
        Screen.audio => AudioMenu(),
        Screen.controls => Controls(),
        Screen.credits => Credits(),
        Screen.game => GamePlayScreen(),
        Screen.hiscore => HiscoreScreen(),
        Screen.hiscore_enter => EnterHiscoreScreen(),
        Screen.controls_gamepad => SelectGamePad(),
        Screen.title => TitleScreen(),
        Screen.video => VideoMenu(),
      };
}
