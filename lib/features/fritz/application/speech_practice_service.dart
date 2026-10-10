import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:speech_to_text/speech_recognition_error.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart';

enum SpeechCaptureState {
  idle,
  listening,
  unavailable,
  permissionDenied,
  failed,
}

abstract interface class SpeechPracticeService {
  Future<bool> startListening({
    required ValueChanged<String> onText,
    required ValueChanged<SpeechCaptureState> onState,
  });

  Future<void> stopListening();
  Future<void> speakGerman(String text);
  Future<void> stopSpeaking();
  Future<void> dispose();
}

/// Short, on-device German dictation and optional German speech output.
final class DeviceSpeechPracticeService implements SpeechPracticeService {
  DeviceSpeechPracticeService({SpeechToText? speech, FlutterTts? tts})
    : _speech = speech ?? SpeechToText(),
      _tts = tts ?? FlutterTts();

  final SpeechToText _speech;
  final FlutterTts _tts;
  bool _initialized = false;
  String? _germanLocaleId;
  ValueChanged<SpeechCaptureState>? _onState;

  @override
  Future<bool> startListening({
    required ValueChanged<String> onText,
    required ValueChanged<SpeechCaptureState> onState,
  }) async {
    _onState = onState;
    try {
      if (!_initialized) {
        _initialized = await _speech.initialize(
          onStatus: _handleStatus,
          onError: _handleError,
        );
      }
      if (!_initialized) {
        onState(
          await _speech.hasPermission
              ? SpeechCaptureState.unavailable
              : SpeechCaptureState.permissionDenied,
        );
        return false;
      }
      final locales = await _speech.locales();
      _germanLocaleId ??= _findGermanLocale(locales);
      if (_germanLocaleId == null) {
        onState(SpeechCaptureState.unavailable);
        return false;
      }
      await _speech.listen(
        onResult: (SpeechRecognitionResult result) =>
            onText(result.recognizedWords),
        listenOptions: SpeechListenOptions(
          localeId: _germanLocaleId,
          listenFor: const Duration(seconds: 30),
          pauseFor: const Duration(seconds: 3),
          partialResults: true,
          cancelOnError: true,
          listenMode: ListenMode.dictation,
        ),
      );
      onState(SpeechCaptureState.listening);
      return true;
    } on SpeechToTextNotInitializedException {
      onState(SpeechCaptureState.failed);
      return false;
    } catch (error) {
      onState(
        _isPermissionFailure(error)
            ? SpeechCaptureState.permissionDenied
            : SpeechCaptureState.failed,
      );
      return false;
    }
  }

  String? _findGermanLocale(List<LocaleName> locales) {
    for (final locale in locales) {
      if (locale.localeId.toLowerCase().startsWith('de-de')) {
        return locale.localeId;
      }
    }
    for (final locale in locales) {
      if (locale.localeId.toLowerCase().startsWith('de')) {
        return locale.localeId;
      }
    }
    return null;
  }

  void _handleStatus(String status) {
    if (status == 'done' || status == 'notListening') {
      _onState?.call(SpeechCaptureState.idle);
    } else if (status == 'listening') {
      _onState?.call(SpeechCaptureState.listening);
    }
  }

  void _handleError(SpeechRecognitionError error) {
    final state = _isPermissionFailure(error.errorMsg)
        ? SpeechCaptureState.permissionDenied
        : SpeechCaptureState.failed;
    _onState?.call(state);
  }

  bool _isPermissionFailure(Object error) =>
      error.toString().toLowerCase().contains('permission');

  @override
  Future<void> stopListening() async {
    if (_speech.isListening) await _speech.stop();
  }

  @override
  Future<void> speakGerman(String text) async {
    final normalized = text.trim();
    if (normalized.isEmpty) return;
    await _tts.stop();
    await _tts.setLanguage('de-DE');
    await _tts.setSpeechRate(0.44);
    await _tts.setVolume(1);
    await _tts.speak(normalized);
  }

  @override
  Future<void> stopSpeaking() => _tts.stop();

  @override
  Future<void> dispose() async {
    if (_speech.isListening) await _speech.cancel();
    await _tts.stop();
    _onState = null;
  }
}
