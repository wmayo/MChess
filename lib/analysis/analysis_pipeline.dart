import 'package:flutter/foundation.dart';

import 'models.dart';
import 'stockfish_lifecycle_manager.dart';

const int kAnalysisDepth = 18;
const int kAnalysisMoveTimeMs = 3000;

class AnalysisPipeline {
  AnalysisPipeline({StockfishLifecycleManager? manager})
    : _manager = manager ?? StockfishLifecycleManager.instance;

  final StockfishLifecycleManager _manager;
  bool _cancelled = false;

  void cancel() {
    _cancelled = true;
  }

  Future<List<EvalResult?>> run({
    required List<String> fenHistory,
    required ValueNotifier<double> progress,
  }) async {
    final List<EvalResult?> results = <EvalResult?>[];
    if (fenHistory.isEmpty) {
      progress.value = 1.0;
      return results;
    }

    _cancelled = false;
    _manager.setAnalysisActive(true);
    try {
      for (int i = 0; i < fenHistory.length; i++) {
        if (_cancelled) {
          break;
        }

        EvalResult? eval;
        try {
          eval = await _manager.evaluatePosition(
            fen: fenHistory[i],
            depth: kAnalysisDepth,
            moveTimeMs: kAnalysisMoveTimeMs,
          );
        } catch (_) {
          eval = null;
        }
        results.add(eval);
        progress.value = (i + 1) / fenHistory.length;
      }
      return results;
    } finally {
      _manager.setAnalysisActive(false);
      if (_cancelled) {
        try {
          await _manager.stopSearch();
        } catch (_) {
          // Best effort stop.
        }
      }
    }
  }
}
