import 'models.dart';

class ReviewedMoveViewModel {
  final int plyIndex;
  final String fen;
  final String? playedMoveUci;
  final String? playedMoveSan;
  final String? bestMoveUci;
  final String? bestMoveSan;
  final List<String> pvUci;
  final List<String> pvSan;
  final MoveAnnotation? annotation;
  final EvalResult? evalBefore;
  final EvalResult? evalAfter;
  final AnalysisStatus status;

  const ReviewedMoveViewModel({
    required this.plyIndex,
    required this.fen,
    required this.playedMoveUci,
    required this.playedMoveSan,
    required this.bestMoveUci,
    required this.bestMoveSan,
    required this.pvUci,
    required this.pvSan,
    required this.annotation,
    required this.evalBefore,
    required this.evalAfter,
    required this.status,
  });

  int? get cpLoss => annotation?.cpLoss;
  MoveClass? get moveClass => annotation?.classification;
  bool get isAnalysed => status == AnalysisStatus.ready && evalBefore != null;
}

class AnalysisSummary {
  final int totalMoves;
  final Map<MoveClass, int> counts;
  final double? whiteAccuracy;
  final double? blackAccuracy;

  const AnalysisSummary({
    required this.totalMoves,
    required this.counts,
    required this.whiteAccuracy,
    required this.blackAccuracy,
  });

  int count(MoveClass c) => counts[c] ?? 0;
}
