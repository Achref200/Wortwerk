import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:wortwerk/core/error/app_failure.dart';
import 'package:wortwerk/core/state/async_resource.dart';

void main() {
  test('publishes loading then data to listeners', () async {
    final response = Completer<String>();
    final controller = AsyncResourceController<String>(
      load: () => response.future,
      isEmpty: (value) => value.isEmpty,
    );
    final states = <AsyncResource<String>>[];
    controller.addListener(() => states.add(controller.state));

    final refresh = controller.refresh();
    expect(controller.state, isA<ResourceLoading<String>>());
    response.complete('real data');
    await refresh;

    expect(controller.state, isA<ResourceData<String>>());
    expect(states, hasLength(2));
    controller.dispose();
  });

  test('distinguishes an empty result from loaded content', () async {
    final controller = AsyncResourceController<List<String>>(
      load: () async => const [],
      isEmpty: (value) => value.isEmpty,
    );

    await controller.refresh();

    expect(controller.state, isA<ResourceEmpty<List<String>>>());
    controller.dispose();
  });

  test('preserves stale data and exposes an offline retry state', () async {
    var shouldFail = false;
    final controller = AsyncResourceController<String>(
      load: () async {
        if (shouldFail) throw const SocketException('offline');
        return 'cached lesson';
      },
      isEmpty: (value) => value.isEmpty,
    );

    await controller.refresh();
    shouldFail = true;
    await controller.refresh();

    final state = controller.state as ResourceOffline<String>;
    expect(state.failure.kind, AppFailureKind.network);
    expect(state.previousData, 'cached lesson');
    controller.dispose();
  });

  test('maps non-network exceptions to a retryable failure state', () async {
    final controller = AsyncResourceController<String>(
      load: () => Future.error(StateError('backend detail')),
      isEmpty: (value) => value.isEmpty,
    );

    await controller.refresh();

    final state = controller.state as ResourceFailure<String>;
    expect(state.failure.kind, AppFailureKind.unknown);
    expect(state.failure.message, isNot(contains('backend detail')));
    controller.dispose();
  });
}
