import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:stockfish/stockfish.dart';
import 'dart:async';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Stockfish initialises and responds to uci', (tester) async {
    final stockfish = Stockfish();
    
    bool uciOkReceived = false;

    final completer = Completer<void>();
    final sub = stockfish.stdout.listen((line) {
      if (line.contains('uciok')) {
        uciOkReceived = true;
        completer.complete();
      }
    });

    stockfish.stdin = 'uci';

    await completer.future.timeout(
      const Duration(seconds: 5),
      onTimeout: () {},
    );

    await sub.cancel();
    stockfish.dispose();

    expect(uciOkReceived, isTrue);
  });
}
