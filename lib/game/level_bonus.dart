import 'package:flame/components.dart';
import 'package:flutteroids/game/common/game_context.dart';
import 'package:flutteroids/game/common/sound.dart';
import 'package:flutteroids/game/level/level.dart';
import 'package:flutteroids/game/level/level_goal.dart';
import 'package:flutteroids/game/player/player.dart';
import 'package:flutteroids/input/game_keys.dart';
import 'package:flutteroids/util/auto_dispose.dart';
import 'package:flutteroids/util/bitmap_text.dart';
import 'package:flutteroids/util/delayed.dart';
import 'package:flutteroids/util/effects.dart';
import 'package:flutteroids/util/extensions.dart';
import 'package:flutteroids/util/game_script_functions.dart';
import 'package:flutteroids/util/log.dart';

class LevelBonus extends Component with AutoDispose, GameContext, GameScriptFunctions {
  LevelBonus({
    required this.position,
    required this.on_done,
    this.line_spacing = 30,
    this.fade_delay = 0.2,
  }) {
    this.priority = 1000;
  }

  final Vector2 position;
  final Function on_done;
  final double line_spacing;
  final double fade_delay;

  late final BitmapText _title;
  late final List<BitmapText> _message_lines = [];
  late final BitmapText _start;

  late final List<LevelGoal> goals;

  bool may_proceed = false;

  // State machine variables
  int _current_goal_index = 0;
  int _total_bonus = 0;
  bool _showing_bonus = false;
  bool _all_goals_shown = false;
  double _state_timer = 0.0;

  // State machine constants
  static const double _message_display_time = 1.0;
  static const double _bonus_display_time = 1.5;
  static const double _next_goal_delay = 0.5;

  @override
  void onMount() {
    super.onMount();

    goals = level.completed_goals.toList();

    final x = position.x;
    final y = position.y;

    // Add title
    final title_text = 'LEVEL ${level.current_level} COMPLETE';
    add(_title = textXY('', x, y - 40, scale: 1.5));
    _title.isVisible = true;
    _title.change_text_in_place(title_text);
    _title.fadeInDeep();

    // Add start prompt (initially invisible)
    add(_start = textXY('PRESS FIRE TO START', x, y + 200));
    _start.isVisible = false;

    // Start the state machine
    _state_timer = _message_display_time;
    _show_current_goal();

    keys.clear();
  }

  void _show_current_goal() {
    if (_current_goal_index >= goals.length) {
      _all_goals_shown = true;
      _show_final_prompt();
      return;
    }

    // Find the next completed goal
    final goal = goals[_current_goal_index];

    // Show the goal message
    final x = position.x;
    final y = position.y;

    // Add the message line
    final bonus = '+${goal.bonus}';
    final placeholder = ''.padRight(bonus.length, ' ');
    final text = '${goal.message} ... $placeholder';
    _create_text(text, x, y, _message_lines, anchor: Anchor.center);

    // Set state to show bonus after delay
    _showing_bonus = false;
    _state_timer = _message_display_time;
  }

  void _show_bonus_for_current_goal() {
    if (_current_goal_index >= goals.length) return;

    // Update total bonus with the current goal's bonus
    final goal = goals[_current_goal_index];
    final goal_bonus = goals[_current_goal_index].bonus;
    _total_bonus += goal.bonus;

    // Update the message line with the bonus
    final bonus = '+${goal.bonus}';
    final text = '${goal.message} ... $bonus';
    _message_lines.last.change_text_in_place(text);
    _message_lines.last.fadeInDeep();

    // Add the bonus to player score
    player.score += goal_bonus;

    // Set state to move to next goal after delay
    _showing_bonus = true;
    _state_timer = _bonus_display_time;

    play_sound(Sound.bonus, volume_factor: 0.5);
  }

  void _create_text(
    String text,
    double x,
    double y,
    List<BitmapText> list, {
    required Anchor anchor,
    double scale = 1.0,
  }) {
    final text_line = textXY('', x, y, scale: scale, anchor: anchor);
    text_line.isVisible = true;
    text_line.change_text_in_place(text);
    text_line.fadeInDeep();
    list.add(text_line);
    add(text_line);
  }

  void _advance_to_next_goal() {
    _current_goal_index++;
    _state_timer = _next_goal_delay;
    _showing_bonus = false;
  }

  void _show_final_prompt() {
    // Show total bonus if there were any goals
    if (_total_bonus > 0) {
      final x = position.x;
      final y = position.y + (_message_lines.isEmpty ? 60 : _message_lines.length * line_spacing + 30);
      _create_text('TOTAL BONUS: $_total_bonus', x, y, [], anchor: Anchor.center, scale: 1.3);

      play_sound(Sound.bonus, volume_factor: 1.0);
    }

    // Show the start prompt
    add(Delayed(0.5, () {
      _start.isVisible = true;
      _start.fadeInDeep();
      may_proceed = true;
      add(Delayed(0.5, () {
        _start.add(BlinkEffect(on: 0.7, off: 0.3));
      }));
    }));
  }

  @override
  void update(double dt) {
    super.update(dt);

    // Handle state machine
    if (!_all_goals_shown) {
      _state_timer -= dt;

      if (_state_timer <= 0) {
        if (!_showing_bonus) {
          _show_bonus_for_current_goal();
        } else {
          _advance_to_next_goal();
          _show_current_goal();
        }
      }
    }

    // Handle user input
    if (may_proceed && keys.any(typical_start_or_select_keys)) {
      keys.clear();
      log_debug('Starting next level from LevelBonus');
      fadeOutDeep();
      removed.then((_) => on_done());
    }
  }
}
