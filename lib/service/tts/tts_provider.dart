import 'dart:async';

enum TtsProviderEventType {
  started,
  completed,
  paused,
  resumed,
  stopped,
  error,
}

class TtsProviderEvent {
  final TtsProviderEventType type;
  final String? message;

  const TtsProviderEvent(this.type, {this.message});
}

abstract class TtsProvider {
  final StreamController<TtsProviderEvent> _events = StreamController<TtsProviderEvent>.broadcast();

  Stream<TtsProviderEvent> get events => _events.stream;

  String get id;

  Future<void> init() async {}

  Future<void> dispose() async {
    await _events.close();
  }

  Future<List<String>> getEngines() async => const [];

  Future<void> applyEngine(String? engine) async {}

  Future<List<Map<String, String>>> getVoices() async => const [];

  Future<void> applyVoice(Map<String, String>? voice) async {}

  Future<void> setRate(double value) async {}

  Future<void> setPitch(double value) async {}

  Future<void> setVolume(double value) async {}

  Future<void> speak(String text);

  Future<void> preload(String text) async {}

  Future<void> pause() async {}

  Future<void> resume() async {}

  Future<void> stop() async {}

  void emit(TtsProviderEvent event) {
    if (!_events.isClosed) {
      _events.add(event);
    }
  }
}
