import 'dart:async';

import 'package:bloc_concurrency/bloc_concurrency.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/error/app_failure.dart';
import '../domain/auth_account.dart';
import '../domain/auth_repository.dart';
import '../domain/auth_session_state.dart';
import 'auth_session_event.dart';

/// The single owner of "who is signed in" for the whole app.
///
/// It is a `Bloc` rather than a `Cubit` because lifecycle events (sign-out,
/// deletion, verification) must not interleave: they are `droppable()`, so a
/// double tap cannot start two deletions.
///
/// The provider stream is consumed by a plain subscription in the
/// constructor, not by a suspended `emit.forEach` inside a handler: a handler
/// that never completes would block the event queue and deadlock [close]
/// wherever it is awaited (widget teardown, app shutdown).
class AuthSessionBloc extends Bloc<AuthSessionEvent, AuthSessionState> {
  AuthSessionBloc({required this._repository})
    : super(const AuthSessionUnknown()) {
    on<AuthSessionStarted>(_onStarted);
    on<AuthSessionSnapshot>(_onSnapshot);
    on<AuthSessionReloadRequested>(_onReload, transformer: droppable());
    on<AuthSessionSignOutRequested>(_onSignOut, transformer: droppable());
    on<AuthSessionVerificationRequested>(
      _onVerification,
      transformer: droppable(),
    );
    on<AuthSessionDeletionRequested>(_onDeletion, transformer: droppable());
    on<AuthSessionFailureDismissed>(_onFailureDismissed);
    // A transport hiccup must not discard a known-good session, so stream
    // errors are swallowed and the last snapshot stands.
    _snapshots = _repository.authStateChanges.listen(
      (account) {
        if (isClosed) return;
        add(AuthSessionSnapshot(account));
      },
      // ignore: avoid_types_on_closure_parameters
      onError: (Object error, StackTrace stackTrace) {},
    );
  }

  final AuthRepository _repository;
  late final StreamSubscription<AuthAccount?> _snapshots;
  final StreamController<AuthSessionNotice> _notices =
      StreamController<AuthSessionNotice>.broadcast();

  /// One-shot confirmations for the UI, never replayed on rebuild.
  Stream<AuthSessionNotice> get notices => _notices.stream;

  String? get currentUserId => state.account?.uid;

  /// The stream subscription drives snapshots; [AuthSessionStarted] only
  /// marks the lifecycle so callers/tests have a thing to await.
  void _onStarted(
    AuthSessionStarted event,
    Emitter<AuthSessionState> emit,
  ) {}

  void _onSnapshot(
    AuthSessionSnapshot event,
    Emitter<AuthSessionState> emit,
  ) {
    final account = event.account;
    emit(
      account == null
          ? const AuthSessionSignedOut()
          : AuthSessionActive(account: account),
    );
  }

  Future<void> _onReload(
    AuthSessionReloadRequested event,
    Emitter<AuthSessionState> emit,
  ) async {
    final current = state;
    if (current is! AuthSessionActive) return;
    emit(current.copyWith(pending: true, clearFailure: true));
    try {
      final account = await _repository.reloadAccount();
      emit(AuthSessionActive(account: account));
    } on AuthFailure catch (failure) {
      emit(current.copyWith(pending: false, failure: failure.failure));
    } catch (_) {
      emit(
        current.copyWith(
          pending: false,
          failure: const AppFailure(AppFailureKind.unknown),
        ),
      );
    }
  }

  Future<void> _onSignOut(
    AuthSessionSignOutRequested event,
    Emitter<AuthSessionState> emit,
  ) async {
    final current = state;
    emit(_pending(current, true, clearFailure: true));
    try {
      await _repository.signOut();
      // The provider stream also reports the sign-out; emitting here makes the
      // transition immediate even before that snapshot arrives.
      emit(const AuthSessionSignedOut());
    } on AuthFailure catch (failure) {
      emit(_withFailure(current, failure.failure));
    } catch (_) {
      emit(_withFailure(current, const AppFailure(AppFailureKind.unknown)));
    }
  }

  Future<void> _onVerification(
    AuthSessionVerificationRequested event,
    Emitter<AuthSessionState> emit,
  ) async {
    final current = state;
    if (current is! AuthSessionActive) return;
    emit(current.copyWith(pending: true, clearFailure: true));
    try {
      await _repository.sendEmailVerification();
      emit(current.copyWith(pending: false));
      _notices.add(AuthSessionNotice.verificationSent);
    } on AuthFailure catch (failure) {
      emit(current.copyWith(pending: false, failure: failure.failure));
    } catch (_) {
      emit(
        current.copyWith(
          pending: false,
          failure: const AppFailure(AppFailureKind.unknown),
        ),
      );
    }
  }

  Future<void> _onDeletion(
    AuthSessionDeletionRequested event,
    Emitter<AuthSessionState> emit,
  ) async {
    final current = state;
    if (current is! AuthSessionActive) return;
    emit(current.copyWith(pending: true, clearFailure: true));
    try {
      await _repository.deleteAccount(password: event.password);
      emit(const AuthSessionSignedOut());
    } on AuthFailure catch (failure) {
      emit(current.copyWith(pending: false, failure: failure.failure));
    } catch (_) {
      emit(
        current.copyWith(
          pending: false,
          failure: const AppFailure(AppFailureKind.unknown),
        ),
      );
    }
  }

  void _onFailureDismissed(
    AuthSessionFailureDismissed event,
    Emitter<AuthSessionState> emit,
  ) {
    final current = state;
    if (current is AuthSessionActive) {
      emit(current.copyWith(clearFailure: true));
    } else if (current is AuthSessionSignedOut) {
      emit(current.copyWith(clearFailure: true));
    }
  }

  AuthSessionState _pending(
    AuthSessionState current,
    bool pending, {
    bool clearFailure = false,
  }) => switch (current) {
    final AuthSessionActive active => active.copyWith(
      pending: pending,
      clearFailure: clearFailure,
    ),
    final AuthSessionSignedOut signedOut => signedOut.copyWith(
      pending: pending,
      clearFailure: clearFailure,
    ),
    AuthSessionUnknown() => AuthSessionSignedOut(pending: pending),
  };

  AuthSessionState _withFailure(AuthSessionState current, AppFailure failure) =>
      switch (current) {
        final AuthSessionActive active => active.copyWith(
          pending: false,
          failure: failure,
        ),
        final AuthSessionSignedOut signedOut => signedOut.copyWith(
          pending: false,
          failure: failure,
        ),
        AuthSessionUnknown() => AuthSessionSignedOut(failure: failure),
      };

  @override
  Future<void> close() async {
    // Stop the snapshot pump first: a snapshot arriving after close would
    // add an event onto a closed queue.
    await _snapshots.cancel();
    await _notices.close();
    return super.close();
  }
}
