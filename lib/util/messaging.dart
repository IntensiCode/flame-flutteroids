import 'package:collection/collection.dart';
import 'package:flame/components.dart';
import 'package:flutteroids/core/common.dart';
import 'package:flutteroids/util/auto_dispose.dart';
import 'package:flutteroids/util/log.dart';

extension ComponentExtension on Component {
  Messaging get messaging {
    final found = ancestors(includeSelf: true).whereType<Messaging>().firstOrNull;
    if (found != null) return found;
    throw 'no messaging mixin found in $this';
  }

  void send_message<T extends Message>(T message) => messaging.send(message);
}

mixin Messaging on Component {
  final listeners = <Type, List<dynamic>>{};

  Disposable listen<T extends Message>(void Function(T) callback) {
    listeners[T] ??= [];
    listeners[T]!.add(callback);
    return Disposable.wrap(() => listeners[T]?.remove(callback));
  }

  void send<T extends Message>(T message) {
    final all = listeners[message.runtimeType];
    if (all == null || all.isEmpty) {
      if (dev) log_verbose('No listener for ${message.runtimeType} in $listeners');
    } else {
      for (final it in all) {
        it(message);
      }
    }
  }

  @override
  void onRemove() => listeners.clear();
}
