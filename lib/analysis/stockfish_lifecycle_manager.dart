import 'dart:async';

import 'package:flutter/foundation.dart';

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
  final ValueNotifier<bool> quickEvalBusy = ValueNotifier<bool>(false);
  final ValueNotifier<bool> quickEvalPaused = ValueNotifier<bool>(false);
  final Map<String, List<EvalResult?>> _analysisEvalCache =
      <String, List<EvalResult?>>{};

  bool get analysisActive => _analysisActive;

  Future<void> _ensureReady() async {
    if (_ready) {
      return;
    }
    await _engine.start();
    await _engine.initialize();
    await _engine.isReady();
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
    quickEvalPaused.value = value;
  }

  void setQuickEvalPaused(bool value) {
    quickEvalPaused.value = value || _analysisActive;
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
    if (_analysisActive || quickEvalPaused.value) {
      return Future<EvalResult?>.value(null);
    }

    final int token = ++_quickEvalToken;
    return runSerialized<EvalResult?>((UciEngine engine) async {
      if (_analysisActive ||
          quickEvalPaused.value ||
          token != _quickEvalToken) {
        return null;
      }
      quickEvalBusy.value = true;
      await engine.setPosition(fen);
      try {
        return engine.go(depth: 12, moveTimeMs: 500);
      } finally {
        quickEvalBusy.value = false;
      }
    });
  }

  Future<void> stopSearch() {
    return runSerialized<void>((UciEngine engine) async {
      await engine.stop();
    });
  }

  String cacheKeyForFenHistory(List<String> fenHistory) => fenHistory.join('|');

  List<EvalResult?>? getCachedEvaluations(String key) {
    final List<EvalResult?>? values = _analysisEvalCache[key];
    if (values == null) {
      return null;
    }
    return List<EvalResult?>.from(values);
  }

  void setCachedEvaluations(String key, List<EvalResult?> evaluations) {
    _analysisEvalCache[key] = List<EvalResult?>.from(evaluations);
  }
}
