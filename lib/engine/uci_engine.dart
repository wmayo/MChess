import '../analysis/models.dart';

abstract class UciEngine {
  Stream<String> get stdoutLines;

  Future<void> start();

  Future<void> initialize();

  Future<void> setOption(String name, String value);

  Future<void> newGame();

  Future<void> setPosition(String fen);

  Future<EvalResult?> go({required int depth, required int moveTimeMs});

  Future<EvalResult?> stop();

  void send(String command);

  Future<void> dispose();
}
