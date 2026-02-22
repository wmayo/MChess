import 'dart:math' as math;

import 'package:flutter/material.dart';

class BestMoveArrowLayer extends StatelessWidget {
  const BestMoveArrowLayer({
    super.key,
    required this.bestMoveUci,
    required this.playedMoveUci,
  });

  final String? bestMoveUci;
  final String? playedMoveUci;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: CustomPaint(
        painter: _ArrowPainter(
          bestMoveUci: bestMoveUci,
          playedMoveUci: playedMoveUci,
        ),
      ),
    );
  }
}

class _ArrowPainter extends CustomPainter {
  _ArrowPainter({required this.bestMoveUci, required this.playedMoveUci});

  final String? bestMoveUci;
  final String? playedMoveUci;

  @override
  void paint(Canvas canvas, Size size) {
    if (bestMoveUci != null && bestMoveUci!.length >= 4) {
      _drawArrow(
        canvas: canvas,
        size: size,
        moveUci: bestMoveUci!,
        color: const Color(0xFF36C486),
        strokeWidth: 6,
      );
    }
    if (playedMoveUci != null &&
        playedMoveUci!.length >= 4 &&
        playedMoveUci != bestMoveUci) {
      _drawArrow(
        canvas: canvas,
        size: size,
        moveUci: playedMoveUci!,
        color: const Color(0xFF60A5FA),
        strokeWidth: 4,
      );
    }
  }

  void _drawArrow({
    required Canvas canvas,
    required Size size,
    required String moveUci,
    required Color color,
    required double strokeWidth,
  }) {
    final Offset from = _squareCenter(moveUci.substring(0, 2), size);
    final Offset to = _squareCenter(moveUci.substring(2, 4), size);

    final Paint paint = Paint()
      ..color = color.withValues(alpha: 0.85)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    canvas.drawLine(from, to, paint);

    final double angle = math.atan2(to.dy - from.dy, to.dx - from.dx);
    const double headSize = 12;
    final Offset p1 = Offset(
      to.dx - headSize * math.cos(angle - math.pi / 6),
      to.dy - headSize * math.sin(angle - math.pi / 6),
    );
    final Offset p2 = Offset(
      to.dx - headSize * math.cos(angle + math.pi / 6),
      to.dy - headSize * math.sin(angle + math.pi / 6),
    );
    final Path head = Path()
      ..moveTo(to.dx, to.dy)
      ..lineTo(p1.dx, p1.dy)
      ..lineTo(p2.dx, p2.dy)
      ..close();
    canvas.drawPath(head, Paint()..color = color.withValues(alpha: 0.9));
  }

  Offset _squareCenter(String square, Size size) {
    const String files = 'abcdefgh';
    final int file = files.indexOf(square[0]);
    final int rank = int.parse(square[1]);
    final double cell = size.width / 8;
    final double x = (file + 0.5) * cell;
    final double y = ((8 - rank) + 0.5) * cell;
    return Offset(x, y);
  }

  @override
  bool shouldRepaint(covariant _ArrowPainter oldDelegate) {
    return oldDelegate.bestMoveUci != bestMoveUci ||
        oldDelegate.playedMoveUci != playedMoveUci;
  }
}
