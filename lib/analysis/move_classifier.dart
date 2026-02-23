import 'models.dart';
import 'review_models.dart';

class MoveClassifier {
  List<MoveAnnotation?> classifyAll({
    required List<EvalResult?> evaluations,
    required List<String> playedMovesUci,
  }) {
    final List<MoveAnnotation?> annotations = <MoveAnnotation?>[];
    if (playedMovesUci.isEmpty) {
      return annotations;
    }

    for (int i = 0; i < playedMovesUci.length; i++) {
      final EvalResult? before = i < evaluations.length ? evaluations[i] : null;
      final EvalResult? after = i + 1 < evaluations.length
          ? evaluations[i + 1]
          : null;
      final String played = playedMovesUci[i];
      annotations.add(
        classifyMove(
          evalBefore: before,
          evalAfter: after,
          playedMoveUci: played,
        ),
      );
    }

    return annotations;
  }

  MoveAnnotation? classifyMove({
    required EvalResult? evalBefore,
    required EvalResult? evalAfter,
    required String playedMoveUci,
  }) {
    if (evalBefore == null || evalAfter == null) {
      return null;
    }

    final bool playedBest = evalBefore.bestMove == playedMoveUci;
    final bool hadMate = evalBefore.mateIn != null;
    final bool hasMateNow = evalAfter.mateIn != null;

    if (hadMate && !playedBest) {
      return MoveAnnotation(
        classification: MoveClass.blunder,
        cpLoss: 1000,
        engineEval: evalBefore,
      );
    }
    if (hasMateNow && playedBest) {
      return MoveAnnotation(
        classification: MoveClass.best,
        cpLoss: 0,
        engineEval: evalBefore,
      );
    }

    // UCI scores are treated as side-to-move; after the move side changes.
    final int beforeMoverPerspective = evalBefore.centipawns;
    final int afterMoverPerspective = -evalAfter.centipawns;
    final int cpLoss = (beforeMoverPerspective - afterMoverPerspective).clamp(
      0,
      30000,
    );

    final MoveClass classification;
    if (cpLoss <= 10) {
      classification = playedBest ? MoveClass.best : MoveClass.excellent;
    } else if (cpLoss <= 30) {
      classification = MoveClass.good;
    } else if (cpLoss <= 90) {
      classification = MoveClass.inaccuracy;
    } else if (cpLoss <= 200) {
      classification = MoveClass.mistake;
    } else {
      classification = MoveClass.blunder;
    }

    return MoveAnnotation(
      classification: classification,
      cpLoss: cpLoss,
      engineEval: evalBefore,
    );
  }

  AnalysisSummary summarize(List<MoveAnnotation?> annotations) {
    final Map<MoveClass, int> counts = <MoveClass, int>{
      for (final MoveClass c in MoveClass.values) c: 0,
    };

    double whiteScore = 0;
    double blackScore = 0;
    int whiteMoves = 0;
    int blackMoves = 0;

    for (int i = 0; i < annotations.length; i++) {
      final MoveAnnotation? ann = annotations[i];
      if (ann == null) {
        continue;
      }
      counts[ann.classification] = (counts[ann.classification] ?? 0) + 1;
      final double score = _accuracyPoints(ann.classification);
      if (i.isEven) {
        whiteMoves++;
        whiteScore += score;
      } else {
        blackMoves++;
        blackScore += score;
      }
    }

    return AnalysisSummary(
      totalMoves: annotations.length,
      counts: counts,
      whiteAccuracy: whiteMoves == 0 ? null : (whiteScore / whiteMoves) * 100,
      blackAccuracy: blackMoves == 0 ? null : (blackScore / blackMoves) * 100,
    );
  }

  double _accuracyPoints(MoveClass c) {
    switch (c) {
      case MoveClass.best:
        return 1.0;
      case MoveClass.excellent:
        return 0.97;
      case MoveClass.good:
        return 0.9;
      case MoveClass.inaccuracy:
        return 0.7;
      case MoveClass.mistake:
        return 0.45;
      case MoveClass.blunder:
        return 0.1;
    }
  }
}
