import 'package:flutter/material.dart';

class EvalBar extends StatelessWidget {
  const EvalBar({
    super.key,
    required this.centipawns,
    required this.mateIn,
    this.width = 28,
    this.height = 240,
  });

  final int centipawns;
  final int? mateIn;
  final double width;
  final double height;

  @override
  Widget build(BuildContext context) {
    final double normalized = ((centipawns.clamp(-800, 800) + 800) / 1600)
        .toDouble();
    final double whiteHeight = height * normalized;
    final String label = mateIn == null ? '${centipawns / 100}' : 'M$mateIn';

    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        border: Border.all(color: Colors.black26),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Stack(
        children: <Widget>[
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                color: Colors.black,
                borderRadius: BorderRadius.circular(6),
              ),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              height: whiteHeight,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(6),
              ),
            ),
          ),
          Positioned.fill(
            child: Center(
              child: RotatedBox(
                quarterTurns: 3,
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: normalized > 0.5 ? Colors.black : Colors.white,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
