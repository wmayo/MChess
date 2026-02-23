import 'uci_engine.dart';
import '../analysis/models.dart';

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
  Future<void> initialize() {
    throw UnsupportedError(
      'Stockfish engine is only supported on Android and iOS.',
    );
  }

  @override
  Future<void> isReady() {
    throw UnsupportedError(
      'Stockfish engine is only supported on Android and iOS.',
    );
  }

  @override
  Future<void> setOption(String name, String value) {
    throw UnsupportedError(
      'Stockfish engine is only supported on Android and iOS.',
    );
  }

  @override
  Future<void> newGame() {
    throw UnsupportedError(
      'Stockfish engine is only supported on Android and iOS.',
    );
  }

  @override
  Future<void> setPosition(String fen) {
    throw UnsupportedError(
      'Stockfish engine is only supported on Android and iOS.',
    );
  }

  @override
  Future<EvalResult?> go({required int depth, required int moveTimeMs}) {
    throw UnsupportedError(
      'Stockfish engine is only supported on Android and iOS.',
    );
  }

  @override
  Future<EvalResult?> stop() {
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
