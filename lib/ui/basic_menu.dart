import 'dart:math';

import 'package:flame/components.dart';
import 'package:flutteroids/input/keys.dart';
import 'package:flutteroids/ui/basic_menu_entry.dart';
import 'package:flutteroids/util/auto_dispose.dart';
import 'package:flutteroids/util/bitmap_font.dart';
import 'package:flutteroids/util/log.dart';

import 'basic_menu_button.dart';

class BasicMenu<T> extends PositionComponent with AutoDispose {
  final Keys keys;
  final BitmapFont font;
  final Function(T) on_selected;
  final double spacing;

  final _entries = <(T, BasicMenuEntry)>[];

  List<T> get entries => _entries.map((it) => it.$1).toList();

  Function(T?) on_preselected = (_) {};

  BasicMenu({
    required this.keys,
    required this.font,
    required this.on_selected,
    this.spacing = 10,
    this.fixed_position,
    this.fixed_size,
    this.fixed_anchor,
  }) : super(anchor: Anchor.center, size: fixed_size);

  Vector2? fixed_position;
  Vector2? fixed_size;
  Anchor? fixed_anchor;

  void _on_selected(T id) {
    log_verbose('Selected: $id');
    preselect_entry(id);
    on_selected(id);
  }

  @override
  void update(double dt) {
    super.update(dt);
    if (keys.check_and_consume(GameKey.up)) preselect_previous();
    if (keys.check_and_consume(GameKey.down)) preselect_next();
    if (keys.any(typical_select_keys)) select();
  }

  @override
  onMount() {
    var offset = 0.0;
    for (final (_, it) in _entries) {
      if (it case BasicMenuButton it) {
        width = max(width, it.size.x);
        if (it.auto_position) {
          it.position.x = width / 2;
          it.position.y = offset;
          it.anchor = Anchor.topCenter;
          offset += it.size.y + spacing;
          if (!it.isMounted) add(it);
        }
      }
    }

    if (height == 0) height = offset;

    if (fixed_position != null) position.setFrom(fixed_position!);
    if (fixed_size != null) size.setFrom(fixed_size!);
    if (fixed_anchor != null) anchor = fixed_anchor!;
  }

  BasicMenuButton add_entry(T id, String text, {Anchor text_anchor = Anchor.center, Vector2? size}) {
    final it = BasicMenuButton(
      text,
      size: size ?? Vector2(192, 24),
      font: font,
      onTap: () => _on_selected(id),
      text_anchor: text_anchor,
    );
    _entries.add((id, it));
    return it;
  }

  void add_custom(T id, BasicMenuEntry it) => _entries.add((id, it));

  T? _preselected;

  preselect_entry(T? id) {
    for (final it in _entries) {
      it.$2.selected = it.$1 == id;
    }
    if (_preselected != id) {
      _preselected = id;
      on_preselected(id);
    }
  }

  preselect_next() {
    final idx = _entries.indexWhere((it) => it.$1 == _preselected);
    final it = (idx + 1) % _entries.length;
    preselect_entry(_entries[it].$1);
  }

  preselect_previous() {
    final idx = _entries.indexWhere((it) => it.$1 == _preselected);
    final it = idx == -1 ? _entries.length - 1 : (idx - 1) % _entries.length;
    preselect_entry(_entries[it].$1);
  }

  select() {
    final it = _preselected;
    if (it != null) _on_selected(it);
  }
}
