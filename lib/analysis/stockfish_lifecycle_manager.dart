import 'dart:async';

import '../engine/engine_factory.dart';
import '../engine/uci_engine.dart';
import 'models.dart';

class StockfishLifecycleManager {
  StockfishLifecycleManager._();

  static final StockfishLifecycleManager instance =
      StockfishLifecycleManager._();

  final UciEngine _engine = createUciEngine();
  Future<void> _queue = Future<void>.value();
  bool _ready = false;
  bool _analysisActive = false;
  int _quickEvalToken = 0;

  bool get analysisActive => _analysisActive;

  Future<void> _ensureReady() async {
    if (_ready) {
      return;
    }
    await _engine.start();
    await _engine.initialize();
    await _engine.newGame();
    _ready = true;
  }

  Future<T> runSerialized<T>(Future<T> Function(UciEngine engine) job) {
    final Completer<T> completer = Completer<T>();
    _queue = _queue.then((_) async {
      try {
        await _ensureReady();
        final T result = await job(_engine);
        completer.complete(result);
      } catch (error, stackTrace) {
        completer.completeError(error, stackTrace);
      }
    });
    return completer.future;
  }

  void setAnalysisActive(bool value) {
    _analysisActive = value;
  }

  Future<EvalResult?> evaluatePosition({
    required String fen,
    required int depth,
    required int moveTimeMs,
  }) {
    return runSerialized<EvalResult?>((UciEngine engine) async {
      await engine.setPosition(fen);
      return engine.go(depth: depth, moveTimeMs: moveTimeMs);
    });
  }

  Future<EvalResult?> requestQuickEval(String fen) {
    if (_analysisActive) {
      return Future<EvalResult?>.value(null);
    }

    final int token = ++_quickEvalToken;
    return runSerialized<EvalResult?>((UciEngine engine) async {
      if (_analysisActive || token != _quickEvalToken) {
        return null;
      }
      await engine.setPosition(fen);
      return engine.go(depth: 12, moveTimeMs: 500);
    });
  }

  Future<void> stopSearch() {
    return runSerialized<void>((UciEngine engine) async {
      await engine.stop();
    });
  }
}
