import 'uci_engine.dart';

UciEngine createUciEngine() => UnsupportedUciEngine();

class UnsupportedUciEngine implements UciEngine {
  @override
  Stream<String> get stdoutLines => const Stream<String>.empty();

  @override
  Future<void> start() {
    throw UnsupportedError(
      'Stockfish engine is only supported on Android and iOS.',
    );
  }

  @override
  void send(String command) {
    throw UnsupportedError(
      'Stockfish engine is only supported on Android and iOS.',
    );
  }

  @override
  Future<void> dispose() async {}
}
