import 'package:flutter/foundation.dart';

import '../error/app_failure.dart';

sealed class AsyncResource<T> {
  const AsyncResource();
}

final class ResourceIdle<T> extends AsyncResource<T> {
  const ResourceIdle();
}

final class ResourceLoading<T> extends AsyncResource<T> {
  const ResourceLoading({this.previousData});

  final T? previousData;
}

final class ResourceData<T> extends AsyncResource<T> {
  const ResourceData(this.value);

  final T value;
}

final class ResourceEmpty<T> extends AsyncResource<T> {
  const ResourceEmpty();
}

final class ResourceOffline<T> extends AsyncResource<T> {
  const ResourceOffline(this.failure, {this.previousData});

  final AppFailure failure;
  final T? previousData;
}

final class ResourceFailure<T> extends AsyncResource<T> {
  const ResourceFailure(this.failure, {this.previousData});

  final AppFailure failure;
  final T? previousData;
}

/// Owns one asynchronous read, exposing explicit loading, empty, offline,
/// success, and failure states to screens through ChangeNotifier listeners.
base class AsyncResourceController<T> extends ChangeNotifier {
  AsyncResourceController({required this.load, required this.isEmpty});

  final Future<T> Function() load;
  final bool Function(T value) isEmpty;
  AsyncResource<T> _state = const ResourceIdle();
  int _requestVersion = 0;
  bool _disposed = false;

  AsyncResource<T> get state => _state;

  Future<void> refresh() async {
    final requestVersion = ++_requestVersion;
    final previousData = switch (_state) {
      ResourceData<T>(:final value) => value,
      ResourceLoading<T>(:final previousData) => previousData,
      ResourceOffline<T>(:final previousData) => previousData,
      ResourceFailure<T>(:final previousData) => previousData,
      _ => null,
    };
    _setState(ResourceLoading(previousData: previousData));

    try {
      final value = await load();
      if (!_isCurrent(requestVersion)) return;
      _setState(isEmpty(value) ? const ResourceEmpty() : ResourceData(value));
    } catch (error) {
      if (!_isCurrent(requestVersion)) return;
      final failure = AppFailure.fromException(error);
      _setState(
        failure.kind == AppFailureKind.network
            ? ResourceOffline(failure, previousData: previousData)
            : ResourceFailure(failure, previousData: previousData),
      );
    }
  }

  bool _isCurrent(int requestVersion) =>
      !_disposed && requestVersion == _requestVersion;

  void _setState(AsyncResource<T> state) {
    if (_disposed) return;
    _state = state;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _requestVersion++;
    super.dispose();
  }
}
