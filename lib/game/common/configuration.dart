import 'package:collection/collection.dart';
import 'package:dart_extensions_methods/dart_extension_methods.dart';
import 'package:flutter/foundation.dart';
import 'package:flutteroids/core/common.dart';
import 'package:flutteroids/input/game_pads.dart';
import 'package:flutteroids/util/auto_dispose.dart';
import 'package:flutteroids/util/extensions.dart';
import 'package:flutteroids/util/game_data.dart';
import 'package:flutteroids/util/log.dart';
import 'package:flutteroids/util/storage.dart' as storage;
import 'package:kart/kart.dart';
import 'package:supercharged/supercharged.dart';

final configuration = Configuration._();

final debug = Configurable<bool>('debug', [false, true], preset: false);
final bg_anim = Configurable('bg_anim', [false, true], preset: true);
final exhaust_anim = Configurable('exhaust_anim', [false, true], preset: !kIsWeb);
final frame_skip = Configurable('frame_skip', [0, 1, 2, 4], preset: kIsWeb ? 2 : 0);

final _all = [
  debug,
  bg_anim,
  exhaust_anim,
  frame_skip,
  // Configurable('gamepad', GamePad.values, preset: GamePad.default_gamepad),
  // Configurable('hw_mapping', known_hw_mappings.keys.toList(), preset: 'CUSTOM'),
];

class Configuration with HasGameData {
  final _loaded = <String, dynamic>{};

  bool _loading = false;

  Configuration._() {
    for (final c in _all) {
      c.on_change((it) => _save_if_changed(c));
    }
  }

  Future? _delayed_save;

  void _save_if_changed(Configurable c) {
    if (_loading) return;
    if (c != _loaded[c.key]) {
      _loaded[c.key] = c.value;

      final it = _delayed_save = Future.delayed(Duration(milliseconds: 100));
      _delayed_save?.then((_) {
        if (_delayed_save != it) return; // Ignore if a new save was requested
        storage.save_to_storage('configuration', this);
      });
    }
  }

  Future<void> load() async {
    await storage.load_from_storage('configuration', this);
    log_verbose(known_hw_mappings.entries.firstWhereOrNull((it) => it.value.deepEquals(hw_mapping))?.key ?? 'CUSTOM');
  }

  Future save() async => storage.save_to_storage('configuration', this);

  // HasGameData

  @override
  void load_state(Map<String, dynamic> data) {
    try {
      _loading = true;
      _load_state(data);
    } catch (it, trace) {
      log_error('Failed to load configuration: $it', trace);
    } finally {
      _loading = false;
    }
  }

  void _load_state(Map<String, dynamic> data) {
    _loaded.clear();

    for (final c in _all) {
      c.value = data[c.key] ?? c.value;
      _loaded[c.key] = c.value;
    }

    hw_mapping = (data['hw_mapping'] as Map<String, dynamic>? ?? {}).entries.mapNotNull((e) {
      final k = e?.key.toIntOrNull();
      if (k == null) return null;
      final v = GamePadControl.values.firstWhereOrNull((it) => it.name == e?.value);
      if (v == null) return null;
      return MapEntry(k, v);
    }).toMap();
  }

  @override
  GameData save_state(Map<String, dynamic> data) => data
    ..addAll({for (final c in _all) c.key: c.value})
    ..['hw_mapping'] = hw_mapping.map((k, v) => MapEntry(k.toString(), v.name));
}

class Configurable<T> {
  final String key;
  final List<T> values;
  final T? _preset;
  T _value;

  Configurable(this.key, this.values, {T? preset})
      : _value = preset ?? values.first,
        _preset = preset {
    if (!values.contains(_value)) {
      throw ArgumentError('Preset value $_value is not in the list of valid values: $values');
    }
  }

  T get value => _value;

  set value(T new_value) {
    if (dev) log_verbose('Setting $key to $new_value');
    if (new_value is String || values.first is EnumProperty) {
      _value = values.firstWhere((it) => (it as EnumProperty).name == new_value);
    } else if (values.contains(new_value)) {
      _value = new_value;
    } else if (new_value == null && _preset != null) {
      _value = _preset;
    } else {
      throw ArgumentError('Invalid value: $new_value');
    }
    _on_change.forEach((it) => it(_value));
  }

  final _on_change = <Function(T)>[];

  Disposable on_change(Function(T) listener) {
    _on_change.add(listener);
    return Disposable.wrap(() => _on_change.remove(listener));
  }

  operator ~() => _value;

  operator <<(T new_value) => value = new_value;

  @override
  operator ==(Object other) {
    if (other is Configurable<T>) {
      return key == other.key && values.equals(other.values) && _value == other._value;
    }
    if (other is T) {
      return _value == other;
    }
    if (other is String && values.first is EnumProperty) {
      return (_value as EnumProperty).name == other;
    }
    return false;
  }

  @override
  int get hashCode {
    if (values.first is EnumProperty) {
      return key.hashCode ^ (_value as EnumProperty).name.hashCode;
    } else {
      return key.hashCode ^ _value.hashCode;
    }
  }

  @override
  String toString() => '$key=$_value';
}
