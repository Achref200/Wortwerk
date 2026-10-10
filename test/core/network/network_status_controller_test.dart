import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wortwerk/core/network/connectivity_data_source.dart';
import 'package:wortwerk/core/network/network_status_banner.dart';
import 'package:wortwerk/core/network/network_status_controller.dart';

final class _FakeConnectivityDataSource implements ConnectivityDataSource {
  final StreamController<bool> changes = StreamController<bool>.broadcast();
  bool connected = true;
  int checks = 0;

  @override
  Future<bool> hasNetworkTransport() async {
    checks++;
    return connected;
  }

  @override
  Stream<bool> watchNetworkTransport() => changes.stream;

  Future<void> close() => changes.close();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('notifies on connection loss and refreshes on demand', () async {
    final source = _FakeConnectivityDataSource();
    final controller = NetworkStatusController(source);
    addTearDown(controller.dispose);
    addTearDown(source.close);
    await controller.refresh();
    expect(controller.status, NetworkStatus.connected);

    source.changes.add(false);
    await Future<void>.delayed(Duration.zero);
    expect(controller.isOffline, isTrue);

    source.connected = true;
    await controller.refresh();
    expect(controller.hasNetworkTransport, isTrue);
    expect(source.checks, greaterThanOrEqualTo(2));
  });

  testWidgets('shows an animated offline notice and a manual retry', (
    tester,
  ) async {
    final source = _FakeConnectivityDataSource()..connected = false;
    final controller = NetworkStatusController(source);
    addTearDown(controller.dispose);
    addTearDown(source.close);
    await controller.refresh();

    await tester.pumpWidget(
      MaterialApp(
        home: NetworkStatusBanner(
          controller: controller,
          child: const Scaffold(body: Text('Home content')),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('Keine Verbindung erkannt'), findsOneWidget);
    expect(find.text('Home content'), findsOneWidget);
    await tester.tap(find.byTooltip('Verbindung erneut prüfen'));
    await tester.pumpAndSettle();
    expect(source.checks, greaterThanOrEqualTo(2));
  });
}
