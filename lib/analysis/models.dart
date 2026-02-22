class EvalResult {
  final int centipawns;
  final int? mateIn;
  final String bestMove;
  final List<String> pv;
  final int depth;

  const EvalResult({
    required this.centipawns,
    required this.mateIn,
    required this.bestMove,
    required this.pv,
    required this.depth,
  });
}

enum MoveClass { best, excellent, good, inaccuracy, mistake, blunder }

class MoveAnnotation {
  final MoveClass classification;
  final int cpLoss;
  final EvalResult? engineEval;

  const MoveAnnotation({
    required this.classification,
    required this.cpLoss,
    required this.engineEval,
  });
}

class AnalysisFrame {
  final String fen;
  final EvalResult? eval;
  final MoveAnnotation? annotation;

  const AnalysisFrame({
    required this.fen,
    required this.eval,
    required this.annotation,
  });
}
