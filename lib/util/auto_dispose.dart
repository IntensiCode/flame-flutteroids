import 'dart:async';

import 'package:flame/components.dart';
import 'package:flutteroids/util/log.dart';

/// Generic "disposable" to dispose/cancel/free some wrapped object.
abstract interface class Disposable {
  static final disposed = _Disposable(() {});

  /// Dispose the object wrapped by this disposable.
  void dispose();

  /// Wrap some dispose call into this disposable for later disposition.
  static wrap(Function dispose) => _Disposable(dispose);
}

/// Holds potentially multiple [Disposable]s to be [dispose]d in one call.
/// Removes all [Disposable]s when [dispose] is called. Can be reused after
/// [dispose] has been called.
mixin CompositeDisposable implements Disposable {
  final _disposables = <Disposable>[];

  void add(Disposable disposable) => _disposables.add(disposable);

  void wrap(dynamic dispose) => _disposables.add(_wrap(dispose));

  @override
  void dispose() {
    for (final it in _disposables) {
      it.dispose();
    }
    _disposables.clear();
  }
}

class _Disposable implements Disposable {
  final Function _disposable;

  _Disposable(this._disposable);

  @override
  void dispose() => _disposable();
}

Disposable _wrap(something) {
  final Disposable it;
  if (something is Timer) {
    it = _Disposable(() => something.stop());
  } else if (something is StreamController) {
    it = _Disposable(() => something.close());
  } else if (something is StreamSubscription) {
    it = _Disposable(() => something.cancel());
  } else if (something is Function()) {
    it = _Disposable(() => something());
  } else if (something is Disposable) {
    it = something;
  } else {
    throw ArgumentError("${something.runtimeType} not supported (yet)");
  }
  return it;
}

/// Auto-dispose system to manage [Disposable] instances and dispose all of them at once, or
/// specific ones individually. Uses [String] tags to identify disposables. By assigning a new
/// disposable using the same tag, any previously assigned disposable for the same tag is
/// auto-disposed. Therefore, effectively replacing the previous disposable.
mixin AutoDispose on Component {
  final _disposables = <String, Disposable>{};

  @override
  void onRemove() {
    super.onRemove();
    log_verbose('onRemove for $runtimeType');
    dispose_all_deep();
  }

  /// Dispose all [Disposable]s currently registered with this [AutoDispose] instance.
  void dispose_all() {
    log_verbose('dispose all on $runtimeType');
    if (_disposables.isNotEmpty) {
      log_verbose('disposing ${_disposables.keys}');
    }
    for (var it in _disposables.values) {
      it.dispose();
    }
    _disposables.clear();
  }

  void dispose_where(bool Function(Disposable disposable) predicate) {
    final matched = _disposables.entries.where((it) => predicate(it.value));
    for (final it in matched) {
      log_info('dispose ${it.key}');
      dispose(it.key);
    }
  }

  void dispose_where_tag(bool Function(String tag) predicate) {
    for (final tag in _disposables.keys.where(predicate).toList()) {
      log_info('dispose $tag');
      dispose(tag);
    }
  }

  /// Dispose the [Disposable] associated with the given [tag]. Nop if nothing registered for this
  /// tag.
  void dispose(String tag) {
    final disposable = _disposables.remove(tag);
    if (disposable != null) log_verbose('disposing $tag');
    disposable?.dispose();
  }

  /// Set up a [Disposable] for the given [something], using the given [tag]. If the tag already
  /// has a [Disposable] assigned, the assigned one is disposed and the new one replaces it.
  /// Otherwise, the new one is assigned to this tag. [something] is turned into a [Disposable]
  /// by inspecting the [Object.runtimeType]. Raises an [ArgumentError] if the given [something]
  /// has an unsupported type. In that case, wrap it into a [Disposable] before passing it to
  /// [auto_dispose].
  T auto_dispose<T>(String tag, T something) {
    log_verbose('register $tag on $runtimeType');
    dispose(tag);
    _disposables[tag] = _wrap(something);
    return something;
  }
}

class AutoDisposeComponent extends Component with AutoDispose {}

extension ComponentExtension on Component {
  void dispose_all_deep() {
    bool dispose(Component it) {
      if (it case AutoDispose ad) ad.dispose_all();
      return true;
    }

    propagateToChildren(dispose, includeSelf: true);
  }
}
