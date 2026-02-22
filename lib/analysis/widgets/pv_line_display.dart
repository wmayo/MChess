import 'package:flutter/material.dart';

class PvLineDisplay extends StatelessWidget {
  const PvLineDisplay({
    super.key,
    required this.bestMoveSan,
    required this.pvSan,
  });

  final String bestMoveSan;
  final List<String> pvSan;

  @override
  Widget build(BuildContext context) {
    final String pvText = pvSan.isEmpty ? '-' : pvSan.join(' ');
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Text(
        'Best: $bestMoveSan   PV: $pvText',
        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
      ),
    );
  }
}
