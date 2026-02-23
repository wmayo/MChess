import 'package:flutter/material.dart';

import '../models.dart';
import '../review_models.dart';

class AnalysisSummaryHeader extends StatelessWidget {
  const AnalysisSummaryHeader({
    super.key,
    required this.summary,
    required this.resultLabel,
  });

  final AnalysisSummary summary;
  final String? resultLabel;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 12, 12, 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF262421),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            resultLabel ?? 'Analysis',
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: <Widget>[
              _chip('Moves', '${summary.totalMoves}'),
              _chip('W Acc', _fmtPct(summary.whiteAccuracy)),
              _chip('B Acc', _fmtPct(summary.blackAccuracy)),
              _chip('Best', '${summary.count(MoveClass.best)}'),
              _chip(
                'Good+',
                '${summary.count(MoveClass.good) + summary.count(MoveClass.excellent)}',
              ),
              _chip('?!', '${summary.count(MoveClass.inaccuracy)}'),
              _chip('?', '${summary.count(MoveClass.mistake)}'),
              _chip('??', '${summary.count(MoveClass.blunder)}'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _chip(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: const Color(0xFF32302B),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text('$label: $value', style: const TextStyle(fontSize: 12)),
    );
  }

  String _fmtPct(double? value) {
    if (value == null) {
      return '-';
    }
    return '${value.clamp(0, 100).toStringAsFixed(0)}%';
  }
}
