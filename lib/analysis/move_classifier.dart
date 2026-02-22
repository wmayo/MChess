import 'models.dart';

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
}
