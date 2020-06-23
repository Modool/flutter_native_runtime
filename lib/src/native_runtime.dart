import 'dart:async';

import 'package:uuid/uuid.dart';

import 'package:flutter/widgets.dart';
import 'package:flutter/services.dart';

const _nativeRuntimeChannelName =
    'com.modool.flutter/plugins/flutter_native_runtime';
const _nativeRuntimeInvokeMethodName = 'invoke';
const _nativeRuntimeDisposeMethodName = 'dispose';
const _nativeRuntimeKeepMethodName = 'keep';

enum NativeTargetType {
  global,
  clazz,
  method,
  property,
  variable,
}

class NativeTarget implements NativeRuntimeClass {
  NativeTarget(
    this.name,
    this.type,
    this._parent,
    this._runtime, {
    List arguments,
  }) {
    _arguments = arguments != null ? List.unmodifiable(arguments) : null;
  }

  bool _disposed;

  List _arguments;
  List get arguments => _arguments;

  final String id = Uuid().v4();

  final String name;

  final NativeTargetType type;

  final NativeRuntime _runtime;

  final NativeTarget _parent;

  final _children = <NativeTarget>[];

  Future<T> _invoke<T>({List arguments}) {
    _arguments = arguments;

    return __invoke();
  }

  Future<T> __invoke<T>() {
    return _runtime._invoke<T>(toMap());
  }

  NativeMethod method(
    String name, {
    List arguments,
  }) {
    final method = NativeMethod._(
      name,
      this,
      _runtime,
      arguments: arguments,
    );
    _children.add(method);

    return method;
  }

  /// Support iOS only
  NativeProperty property(
    String name, {
    bool keep = false,
  }) {
    final property = NativeProperty._(
      name,
      this,
      _runtime,
    );
    _children.add(property);

    return property;
  }

  NativeMemberVariable memberVariable(
    String name, {
    bool keep = false,
  }) {
    final variable = NativeMemberVariable._(
      name,
      this,
      _runtime,
    );
    _children.add(variable);

    return variable;
  }

  Map<String, dynamic> toMap() {
    final map = <String, dynamic>{
      'n': name,
      't': type.index,
      'id': id,
    };

    if (_arguments != null) map['a'] = _arguments;
    if (_parent != null) map['p'] = _parent.toMap();
    return map;
  }

  @override
  int get hashCode => id.hashCode;

  bool isSameAs(other) {
    if (other is NativeTarget) {
      return other.name == name &&
          other.type == type &&
          (other._parent == _parent ||
              (other._parent != null &&
                  _parent != null &&
                  _parent.isSameAs(other._parent)));
    }
    return false;
  }

  @override
  bool operator ==(other) {
    if (other is NativeTarget) {
      return other.id == id;
    }
    return false;
  }

  @override
  Future<bool> dispose() async {
    if (_disposed == null || _disposed) return false;

    _disposed = true;
    await _runtime._dispose(id);
    return true;
  }

  Future<bool> keep() async {
    if (_disposed != null && _disposed) return false;

    _disposed = false;
    await _runtime._keep(toMap());
    return true;
  }
}

class NativeMethod extends NativeTarget {
  NativeMethod._(
    String name,
    NativeTarget parent,
    NativeRuntime runtime, {
    List arguments,
  }) : super(
          name,
          NativeTargetType.method,
          parent,
          runtime,
          arguments: arguments,
        );
  Future<T> invoke<T>() => super.__invoke();
}

/// Support Android only
class NativeMemberVariable extends NativeTarget {
  NativeMemberVariable._(
    String name,
    NativeTarget parent,
    NativeRuntime runtime,
  ) : super(
          name,
          NativeTargetType.variable,
          parent,
          runtime,
        );

  Future<void> set(value) => super._invoke<void>(arguments: [value]);

  Future<T> get<T>() => super.__invoke<T>();
}

/// Support iOS only
class NativeProperty extends NativeTarget {
  NativeProperty._(
    String name,
    NativeTarget parent,
    NativeRuntime runtime,
  ) : super(
          name,
          NativeTargetType.property,
          parent,
          runtime,
        );

  Future<void> set(value) => super._invoke<void>(arguments: [value]);

  Future<T> get<T>() => super.__invoke<T>();
}

class NativeRuntime {
  factory NativeRuntime() =>
      NativeRuntime._(MethodChannel(_nativeRuntimeChannelName));

  NativeRuntime._(this._channel);

  final MethodChannel _channel;

  Future<T> _invoke<T>(Map arguments) async {
    final result = await _channel.invokeMethod<T>(
        _nativeRuntimeInvokeMethodName, arguments);
    return result;
  }

  Future<void> _keep(Map arguments) async {
    return _channel.invokeMethod<void>(_nativeRuntimeKeepMethodName, arguments);
  }

  Future<void> _dispose(String id) async {
    return _channel.invokeMethod<void>(
      _nativeRuntimeDisposeMethodName,
      id,
    );
  }

  NativeTarget classNamed(String name) =>
      NativeTarget(name, NativeTargetType.clazz, null, this);

  NativeTarget instanceNamed(String name) =>
      NativeTarget(name, NativeTargetType.global, null, this);
}

abstract class NativeRuntimeClass {
  Future<bool> dispose();
}

@visibleForTesting
class TestNativeRuntime extends NativeRuntime {
  TestNativeRuntime(MethodChannel channel) : super._(channel);
}
