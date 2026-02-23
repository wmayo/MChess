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

  Future<List<AnalysisFrame>> run({
    required List<String> fenHistory,
    required ValueNotifier<double> progress,
    void Function(int index, AnalysisFrame frame)? onFrameReady,
  }) async {
    final List<AnalysisFrame> results = fenHistory
        .map(
          (String fen) => AnalysisFrame(
            fen: fen,
            eval: null,
            annotation: null,
            status: AnalysisStatus.pending,
          ),
        )
        .toList();
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
        AnalysisStatus status = AnalysisStatus.ready;
        try {
          eval = await _manager.evaluatePosition(
            fen: fenHistory[i],
            depth: kAnalysisDepth,
            moveTimeMs: kAnalysisMoveTimeMs,
          );
          if (eval == null) {
            status = AnalysisStatus.timeout;
          }
        } catch (_) {
          eval = null;
          status = AnalysisStatus.error;
        }
        results[i] = AnalysisFrame(
          fen: fenHistory[i],
          eval: eval,
          annotation: null,
          status: status,
        );
        onFrameReady?.call(i, results[i]);
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
