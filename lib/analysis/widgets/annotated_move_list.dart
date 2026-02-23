import 'package:flutter/material.dart';

import '../models.dart';

class AnnotatedMoveList extends StatelessWidget {
  const AnnotatedMoveList({
    super.key,
    required this.sanMoves,
    required this.annotations,
    required this.currentPly,
    required this.onJumpToPly,
    this.statuses,
  });

  final List<String> sanMoves;
  final List<MoveAnnotation?> annotations;
  final int currentPly;
  final ValueChanged<int> onJumpToPly;
  final List<AnalysisStatus>? statuses;

  @override
  Widget build(BuildContext context) {
    if (sanMoves.isEmpty) {
      return const Text('No moves.');
    }
    return ListView.builder(
      itemCount: (sanMoves.length / 2).ceil(),
      itemBuilder: (BuildContext context, int index) {
        final int whitePly = index * 2;
        final int blackPly = whitePly + 1;
        final bool isWhiteSelected = currentPly == whitePly + 1;
        final bool isBlackSelected = currentPly == blackPly + 1;

        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 8,
            runSpacing: 4,
            children: <Widget>[
              Text(
                '${index + 1}.',
                style: const TextStyle(color: Colors.white70),
              ),
              _moveChip(
                text: _withGlyph(whitePly),
                selected: isWhiteSelected,
                onTap: () => onJumpToPly(whitePly + 1),
                color: _colorFor(whitePly),
              ),
              if (blackPly < sanMoves.length)
                _moveChip(
                  text: _withGlyph(blackPly),
                  selected: isBlackSelected,
                  onTap: () => onJumpToPly(blackPly + 1),
                  color: _colorFor(blackPly),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _moveChip({
    required String text,
    required bool selected,
    required VoidCallback onTap,
    required Color color,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: selected ? const Color(0x3347A8FF) : const Color(0x0FFFFFFF),
          borderRadius: BorderRadius.circular(6),
          border: selected
              ? Border.all(color: const Color(0x6647A8FF))
              : Border.all(color: Colors.transparent),
        ),
        child: Text(
          text,
          style: TextStyle(
            fontSize: 13,
            fontWeight: selected ? FontWeight.bold : FontWeight.w500,
            color: color,
          ),
        ),
      ),
    );
  }

  String _withGlyph(int ply) {
    final String san = sanMoves[ply];
    final AnalysisStatus? status = statuses != null && ply < statuses!.length
        ? statuses![ply]
        : null;
    if (status == AnalysisStatus.pending) {
      return '$san ...';
    }
    if (status == AnalysisStatus.timeout) {
      return '$san [timeout]';
    }
    if (status == AnalysisStatus.error) {
      return '$san [error]';
    }
    if (ply >= annotations.length || annotations[ply] == null) {
      return san;
    }
    return '$san ${_glyphFor(annotations[ply]!.classification)}';
  }

  Color _colorFor(int ply) {
    final AnalysisStatus? status = statuses != null && ply < statuses!.length
        ? statuses![ply]
        : null;
    if (status == AnalysisStatus.pending) {
      return Colors.white70;
    }
    if (status == AnalysisStatus.timeout || status == AnalysisStatus.error) {
      return const Color(0xFFFB923C);
    }
    if (ply >= annotations.length || annotations[ply] == null) {
      return Colors.white;
    }
    return _classificationColor(annotations[ply]!.classification);
  }

  String _glyphFor(MoveClass c) {
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

  Color _classificationColor(MoveClass c) {
    switch (c) {
      case MoveClass.best:
      case MoveClass.excellent:
        return const Color(0xFF2DD4BF);
      case MoveClass.good:
        return const Color(0xFF22C55E);
      case MoveClass.inaccuracy:
        return const Color(0xFFF59E0B);
      case MoveClass.mistake:
        return const Color(0xFFFB923C);
      case MoveClass.blunder:
        return const Color(0xFFEF4444);
    }
  }
}
