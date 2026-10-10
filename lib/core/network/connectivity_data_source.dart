import 'package:connectivity_plus/connectivity_plus.dart';

abstract interface class ConnectivityDataSource {
  Future<bool> hasNetworkTransport();

  Stream<bool> watchNetworkTransport();
}

final class ConnectivityPlusDataSource implements ConnectivityDataSource {
  ConnectivityPlusDataSource({Connectivity? connectivity})
    : _connectivity = connectivity ?? Connectivity();

  final Connectivity _connectivity;

  @override
  Future<bool> hasNetworkTransport() async =>
      _hasTransport(await _connectivity.checkConnectivity());

  @override
  Stream<bool> watchNetworkTransport() =>
      _connectivity.onConnectivityChanged.map(_hasTransport).distinct();

  static bool _hasTransport(List<ConnectivityResult> results) =>
      results.any((result) => result != ConnectivityResult.none);
}
