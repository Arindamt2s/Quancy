import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart';

class VoiceReply {
  final String message;
  final bool keepListening;
  final Future<void> Function()? afterSpeak;

  const VoiceReply(this.message, {this.keepListening = true, this.afterSpeak});
}

typedef VoiceCommandHandler = Future<VoiceReply> Function(String text);

class VoiceAssistantViewModel extends ChangeNotifier {
  final SpeechToText _speech = SpeechToText();
  final FlutterTts _tts = FlutterTts();

  VoiceCommandHandler? onCommand;

  bool _initialized = false;
  bool _speechAvailable = false;
  bool _isListening = false;
  bool _isSpeaking = false;
  bool _isPanelOpen = true;
  bool _handling = false;
  bool _disposed = false;

  String _botMessage = '';
  String _userText = '';

  bool get isListening => _isListening;
  bool get isSpeaking => _isSpeaking;
  bool get isPanelOpen => _isPanelOpen;
  bool get speechAvailable => _speechAvailable;
  String get botMessage => _botMessage;
  String get userText => _userText;

  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;

    await _tts.setLanguage('en-US');
    await _tts.setSpeechRate(0.45);
    await _tts.setPitch(1.0);
    await _tts.awaitSpeakCompletion(true);

    try {
      _speechAvailable = await _speech.initialize(
        onStatus: _onStatus,
        onError: (error) {
          debugPrint('🎤 Speech error: ${error.errorMsg}');
          _isListening = false;
          _notify();
        },
      );
    } catch (e) {
      debugPrint('🎤 Speech init failed: $e');
      _speechAvailable = false;
    }
    _notify();
  }

  Future<void> greet(String firstName) async {
    final name = firstName.trim().isNotEmpty ? ' ${firstName.trim()}' : '';
    await speak(
      'Hi$name! I am your AI Guide. Please talk with me, '
      'I can help you with your inspections. '
      'Try saying, open food inspection.',
    );
    if (_speechAvailable && _isPanelOpen) await startListening();
  }

  Future<void> speak(String text) async {
    if (_disposed) return;
    if (_isListening) {
      await _speech.stop();
      _isListening = false;
    }
    _botMessage = text;
    _isSpeaking = true;
    _notify();

    await _tts.speak(text);

    _isSpeaking = false;
    _notify();
  }

  Future<void> startListening() async {
    if (_disposed) return;
    if (!_speechAvailable) {
      _botMessage =
          'Voice recognition is not available on this device. Please check microphone permission.';
      _notify();
      return;
    }
    if (_isListening || _isSpeaking) return;

    await _tts.stop();
    _userText = '';
    _isListening = true;
    _notify();

    await _speech.listen(
      onResult: _onResult,
      listenFor: const Duration(seconds: 20),
      pauseFor: const Duration(seconds: 3),
      localeId: 'en_US',
      listenOptions: SpeechListenOptions(
        partialResults: true,
        cancelOnError: true,
        listenMode: ListenMode.confirmation,
      ),
    );
  }

  Future<void> stopListening() async {
    await _speech.stop();
    _isListening = false;
    _notify();
  }

  void _onStatus(String status) {
    if (status == 'done' || status == 'notListening') {
      _isListening = false;
      _notify();
    }
  }

  Future<void> _onResult(SpeechRecognitionResult result) async {
    _userText = result.recognizedWords;
    _notify();

    if (!result.finalResult ||
        _userText.trim().isEmpty ||
        _handling ||
        onCommand == null) {
      return;
    }

    _handling = true;
    _isListening = false;
    _notify();

    try {
      final reply = await onCommand!(_userText);
      if (_disposed) return;

      await speak(reply.message);
      if (reply.afterSpeak != null) await reply.afterSpeak!();

      if (!_disposed && reply.keepListening && _isPanelOpen) {
        await startListening();
      }
    } finally {
      _handling = false;
    }
  }

  void openPanel() {
    _isPanelOpen = true;
    _notify();
    startListening();
  }

  Future<void> closePanel() async {
    _isPanelOpen = false;
    await _speech.stop();
    await _tts.stop();
    _isListening = false;
    _isSpeaking = false;
    _notify();
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _speech.cancel();
    _tts.stop();
    super.dispose();
  }
}