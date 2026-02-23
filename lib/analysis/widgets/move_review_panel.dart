import 'package:flutter/material.dart';

import '../models.dart';
import '../review_models.dart';

class MoveReviewPanel extends StatelessWidget {
  const MoveReviewPanel({
    super.key,
    required this.review,
    required this.showingBestLine,
  });

  final ReviewedMoveViewModel review;
  final bool showingBestLine;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFF262421),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          if (showingBestLine)
            const Padding(
              padding: EdgeInsets.only(bottom: 6),
              child: Text(
                'Showing best line...',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFFBACA44),
                ),
              ),
            ),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: <Widget>[
              _cell('Played', _playedLabel(review)),
              _cell('Best', review.bestMoveSan ?? review.bestMoveUci ?? '-'),
              _cell(
                'Loss',
                review.cpLoss == null ? '-' : '${review.cpLoss} cp',
              ),
              _cell('Class', _classLabel(review.moveClass)),
              _cell('Status', _statusLabel(review.status)),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'PV: ${review.pvSan.isEmpty ? '-' : review.pvSan.join(' ')}',
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 13),
          ),
        ],
      ),
    );
  }

  Widget _cell(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: const Color(0xFF32302B),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text('$label: $value', style: const TextStyle(fontSize: 12)),
    );
  }

  String _playedLabel(ReviewedMoveViewModel review) {
    final String move = review.playedMoveSan ?? review.playedMoveUci ?? '-';
    final MoveClass? c = review.moveClass;
    if (c == null) {
      return move;
    }
    return '$move ${_glyph(c)}';
  }

  String _classLabel(MoveClass? c) {
    if (c == null) {
      return 'Pending';
    }
    switch (c) {
      case MoveClass.best:
        return 'Best';
      case MoveClass.excellent:
        return 'Excellent';
      case MoveClass.good:
        return 'Good';
      case MoveClass.inaccuracy:
        return 'Inaccuracy';
      case MoveClass.mistake:
        return 'Mistake';
      case MoveClass.blunder:
        return 'Blunder';
    }
  }

  String _statusLabel(AnalysisStatus status) {
    switch (status) {
      case AnalysisStatus.ready:
        return 'Ready';
      case AnalysisStatus.timeout:
        return 'Timeout';
      case AnalysisStatus.error:
        return 'Error';
      case AnalysisStatus.pending:
        return 'Pending';
    }
  }

  String _glyph(MoveClass c) {
    switch (c) {
      case MoveClass.best:
      case MoveClass.excellent:
        return '\u2726';
      case MoveClass.good:
        return '\u2714';
      case MoveClass.inaccuracy:
        return '?!';
      case MoveClass.mistake:
        return '?';
      case MoveClass.blunder:
        return '??';
    }
  }
}
