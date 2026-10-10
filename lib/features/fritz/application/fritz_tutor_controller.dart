import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';

import '../../../core/error/app_failure.dart';
import '../domain/fritz_message.dart';

final class FritzTutorController extends ChangeNotifier {
  FritzTutorController({required this._repository, this.threadId = 'main'}) {
    _startWatching();
  }

  final FritzChatRepository _repository;
  final String threadId;
  StreamSubscription<List<FritzMessage>>? _subscription;
  List<FritzMessage> _messages = const [];
  FritzMessage? _pendingMessage;
  AppFailure? _loadFailure;
  AppFailure? _sendFailure;
  String? _retryText;
  String? _retryMode;
  String? _retryRequestId;
  bool _isLoading = true;
  bool _isSending = false;
  bool _disposed = false;

  List<FritzMessage> get messages {
    final pending = _pendingMessage;
    if (pending == null ||
        _messages.any((message) => message.id == pending.id)) {
      return _messages;
    }
    return [..._messages, pending];
  }

  AppFailure? get loadFailure => _loadFailure;
  AppFailure? get sendFailure => _sendFailure;
  String? get retryText => _retryText;
  bool get isLoading => _isLoading;
  bool get isSending => _isSending;
  bool get hasMessages => messages.isNotEmpty;

  Future<void> retryLoad() async {
    _loadFailure = null;
    _isLoading = true;
    _notify();
    await _subscription?.cancel();
    _startWatching();
  }

  Future<void> send(String text, {String mode = 'chat'}) async {
    final normalized = text.trim();
    if (normalized.isEmpty || _isSending || _sendFailure != null) return;
    if (normalized.length > 1000) {
      _sendFailure = const AppFailure(AppFailureKind.validation);
      _notify();
      return;
    }
    await _send(normalized, mode: mode, requestId: _newRequestId());
  }

  Future<void> retrySend() async {
    final text = _retryText;
    final mode = _retryMode;
    final requestId = _retryRequestId;
    if (text == null || mode == null || requestId == null || _isSending) return;
    await _send(text, mode: mode, requestId: requestId);
  }

  void discardFailedSend() {
    if (_isSending || _sendFailure == null) return;
    _sendFailure = null;
    _pendingMessage = null;
    _retryText = null;
    _retryMode = null;
    _retryRequestId = null;
    _notify();
  }

  Future<void> _send(
    String text, {
    required String mode,
    required String requestId,
  }) async {
    _isSending = true;
    _sendFailure = null;
    _retryText = text;
    _retryMode = mode;
    _retryRequestId = requestId;
    _pendingMessage = FritzMessage(
      id: 'user_$requestId',
      requestId: requestId,
      role: FritzMessageRole.learner,
      text: text,
      createdAt: DateTime.now(),
    );
    _notify();
    try {
      await _repository.sendMessage(
        text: text,
        mode: mode,
        threadId: threadId,
        clientRequestId: requestId,
      );
      _pendingMessage = null;
      _retryText = null;
      _retryMode = null;
      _retryRequestId = null;
    } catch (error) {
      _sendFailure = AppFailure.fromException(error);
    } finally {
      _isSending = false;
      _notify();
    }
  }

  void _startWatching() {
    _subscription = _repository
        .watchMessages(threadId: threadId)
        .listen(
          (messages) {
            _messages = List.unmodifiable(messages);
            _isLoading = false;
            _loadFailure = null;
            final pending = _pendingMessage;
            if (pending != null &&
                messages.any((message) => message.id == pending.id)) {
              _pendingMessage = null;
            }
            _notify();
          },
          onError: (Object error) {
            _isLoading = false;
            _loadFailure = AppFailure.fromException(error);
            _notify();
          },
        );
  }

  String _newRequestId() {
    final random = Random.secure();
    final suffix = List<int>.generate(
      16,
      (_) => random.nextInt(256),
    ).map((value) => value.toRadixString(16).padLeft(2, '0')).join();
    return 'fritz_${DateTime.now().toUtc().microsecondsSinceEpoch}_$suffix';
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    unawaited(_subscription?.cancel());
    super.dispose();
  }
}
