import 'dart:async';

import 'package:flutter/widgets.dart';

import 'connectivity_data_source.dart';

enum NetworkStatus { unknown, connected, disconnected }

final class NetworkStatusController extends ChangeNotifier
    with WidgetsBindingObserver {
  NetworkStatusController(this._dataSource) {
    WidgetsBinding.instance.addObserver(this);
    _subscription = _dataSource.watchNetworkTransport().listen(
      (connected) => _setStatus(
        connected ? NetworkStatus.connected : NetworkStatus.disconnected,
      ),
      onError: (Object _) => _setStatus(NetworkStatus.unknown),
    );
    unawaited(refresh());
  }

  final ConnectivityDataSource _dataSource;
  late final StreamSubscription<bool> _subscription;
  NetworkStatus _status = NetworkStatus.unknown;
  bool _disposed = false;

  NetworkStatus get status => _status;
  bool get isOffline => _status == NetworkStatus.disconnected;
  bool get hasNetworkTransport => _status == NetworkStatus.connected;

  Future<void> refresh() async {
    try {
      final connected = await _dataSource.hasNetworkTransport();
      _setStatus(
        connected ? NetworkStatus.connected : NetworkStatus.disconnected,
      );
    } catch (_) {
      _setStatus(NetworkStatus.unknown);
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) unawaited(refresh());
  }

  void _setStatus(NetworkStatus status) {
    if (_disposed || status == _status) return;
    _status = status;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    WidgetsBinding.instance.removeObserver(this);
    unawaited(_subscription.cancel());
    super.dispose();
  }
}
