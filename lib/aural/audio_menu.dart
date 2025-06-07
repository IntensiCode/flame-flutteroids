import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flame/extensions.dart';
import 'package:flutteroids/aural/audio_system.dart';
import 'package:flutteroids/aural/volume_component.dart';
import 'package:flutteroids/background/space.dart';
import 'package:flutteroids/core/atlas.dart';
import 'package:flutteroids/core/common.dart';
import 'package:flutteroids/game/common/screens.dart';
import 'package:flutteroids/game/common/sound.dart';
import 'package:flutteroids/input/keys.dart';
import 'package:flutteroids/ui/basic_menu.dart';
import 'package:flutteroids/ui/fonts.dart';
import 'package:flutteroids/util/bitmap_text.dart';
import 'package:flutteroids/util/extensions.dart';
import 'package:flutteroids/util/game_script.dart';
import 'package:flutteroids/util/log.dart';

enum AudioMenuEntry {
  music_and_sound,
  music_only,
  sound_only,
  silent_mode,
  master_volume,
  music_volume,
  sound_volume,
  back,
}

class AudioMenu extends GameScriptComponent {
  final _keys = Keys();

  late final BasicMenu<AudioMenuEntry> menu;

  static AudioMenuEntry? _preselected;

  @override
  onLoad() {
    add(_keys);
    add(shared_space);

    fontSelect(tiny_font, scale: 2);
    textXY('Audio Mode', game_center.x, 20, scale: 2, anchor: Anchor.topCenter);

    menu = added(BasicMenu<AudioMenuEntry>(
      keys: _keys,
      font: mini_font,
      on_selected: _selected,
      spacing: 10,
    )
      ..add_entry(AudioMenuEntry.music_and_sound, 'Music & Sound')
      ..add_entry(AudioMenuEntry.music_only, 'Music Only')
      ..add_entry(AudioMenuEntry.sound_only, 'Sound Only')
      ..add_entry(AudioMenuEntry.silent_mode, 'Silent Mode'));

    menu.position.setValues(game_center.x, 48);
    menu.anchor = Anchor.topCenter;

    menu.on_preselected = (it) => _preselected = it;

    _add_volume_controls(menu);

    if (dev) {
      _add_sound_tester();
    }

    add(menu.add_entry(AudioMenuEntry.back, 'Back', size: Vector2(80, 24))
      ..auto_position = false
      ..position.setValues(8, game_size.y - 8)
      ..anchor = Anchor.bottomLeft);

    menu.preselect_entry(_preselected ?? AudioMenuEntry.master_volume);
  }

  @override
  void update(double dt) {
    super.update(dt);
    if (_keys.check_and_consume(GameKey.soft1)) pop_screen();
  }

  void _add_volume_controls(BasicMenu<AudioMenuEntry> menu) {
    void change_master(double volume) => audio.master = volume;
    double read_master() => audio.master;
    void change_music(double volume) => audio.music = volume;
    double read_music() => audio.music;
    void change_sound(double volume) => audio.sound = volume;
    double read_sound() => audio.sound;

    final positions = [
      Vector2(game_center.x, game_center.y + 16),
      Vector2(game_center.x, game_center.y + 64 + 16),
      Vector2(game_center.x, game_center.y + 128 + 16),
    ];

    add(_master = _volume_control('Master Volume - / +', '-', '+',
        position: positions[0], anchor: Anchor.center, change: change_master, volume: read_master));
    add(_music = _volume_control('Music Volume [ / ]', '[', ']',
        position: positions[1], anchor: Anchor.center, change: change_music, volume: read_music));
    add(_sound = _volume_control('Sound Volume { / }', '{', '}',
        position: positions[2], anchor: Anchor.center, change: change_sound, volume: read_sound));

    menu.add_custom(AudioMenuEntry.master_volume, _master);
    menu.add_custom(AudioMenuEntry.music_volume, _music);
    menu.add_custom(AudioMenuEntry.sound_volume, _sound);
  }

  late final VolumeComponent _master;
  late final VolumeComponent _music;
  late final VolumeComponent _sound;

  void _selected(AudioMenuEntry it) {
    log_verbose('audio menu selected: $it');
    switch (it) {
      case AudioMenuEntry.music_and_sound:
        audio.audio_mode = AudioMode.music_and_sound;
        _make_sound();
      case AudioMenuEntry.music_only:
        audio.audio_mode = AudioMode.music_only;
      case AudioMenuEntry.sound_only:
        audio.audio_mode = AudioMode.sound_only;
        _make_sound();
      case AudioMenuEntry.silent_mode:
        audio.audio_mode = AudioMode.silent;
      case AudioMenuEntry.back:
        pop_screen();
      case _:
        break;
    }
  }

  int _last_sound_at = 0;

  void _make_sound() {
    final now = DateTime.timestamp().millisecondsSinceEpoch;
    if (_last_sound_at + 100 > now) return;
    _last_sound_at = now;
    final which = (Sound.values - [Sound.incoming]).random().name;
    play_one_shot('sound/$which');
  }

  void _add_sound_tester() {
    final soundList = Sound.values.toList();
    final column = PositionComponent(position: Vector2(game_size.x - 100, 48));

    for (int i = 0; i < soundList.length; i++) {
      final sound = soundList[i];
      final yPos = i * 12.0;
      column.add(_PlaySound(
        sound: sound,
        position: Vector2(0, yPos),
      ));
    }

    add(column);
  }

  VolumeComponent _volume_control(
    String label,
    String increase_shortcut,
    String decrease_shortcut, {
    required Vector2 position,
    Anchor? anchor,
    Vector2? size,
    required double Function() volume,
    required void Function(double) change,
  }) =>
      VolumeComponent(
        bg_nine_patch: atlas.sprite('button_plain.png'),
        label: label,
        position: position,
        anchor: anchor ?? Anchor.topLeft,
        size: size ?? Vector2(192, 64),
        key_down: decrease_shortcut,
        key_up: increase_shortcut,
        change: change,
        volume: volume,
        keys: _keys,
      );
}

class _PlaySound extends PositionComponent with TapCallbacks {
  final Sound sound;
  late final BitmapText _text;

  _PlaySound({
    required this.sound,
    required super.position,
  }) {
    _text = BitmapText(
      text: sound.name,
      position: Vector2.zero(),
      font: tiny_font,
      scale: 1,
    );
    add(_text);
    size = _text.size;
  }

  @override
  void onTapUp(TapUpEvent event) {
    super.onTapUp(event);
    play_sound(sound);
  }
}
