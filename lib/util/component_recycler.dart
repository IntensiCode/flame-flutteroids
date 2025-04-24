import 'package:flame/components.dart';
import 'package:flutteroids/core/common.dart';
import 'package:flutteroids/util/log.dart';

mixin Recyclable on Component {
  bool recycled = false;
  late Function() recycle;
}

class ComponentRecycler<T extends Recyclable> {
  ComponentRecycler(this._create, [this._custom_recycle]);

  final T Function() _create;
  final Function(T)? _custom_recycle;

  final items = <T>[];

  void precreate(int count) {
    for (var i = 0; i < count; i++) {
      final it = _create();
      it.recycle = _custom_recycle != null ? () => _custom_recycle(it) : () => recycle(it);
      items.add(it);
    }
  }

  T acquire() {
    if (items.isNotEmpty) {
      return items.removeLast()..recycled = false;
    } else {
      final it = _create();
      if (dev) log_warn('pool empty, creating new instance - ${it.runtimeType}');
      it.recycle = _custom_recycle != null ? () => _custom_recycle(it) : () => recycle(it);
      return it;
    }
  }

  void recycle(T component) {
    // if (component.recycled && dev) {
    //   if (component.isMounted && !component.isRemoving) throw 'no no';
    //   if (!_pool.contains(component)) throw 'oh no no';
    //   if (_pool.contains(component)) log_error('ignore duplicate recycle: $component', StackTrace.current);
    // }

    if (component.isMounted) component.removeFromParent();
    if (!component.recycled && !items.contains(component)) items.add(component);
    component.recycled = true;
  }
}
