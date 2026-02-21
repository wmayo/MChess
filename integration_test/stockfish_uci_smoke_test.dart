import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:m_chess/engine/engine_factory.dart';
import 'package:m_chess/engine/uci_engine.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  UciEngine? activeEngine;

  tearDown(() async {
    if (activeEngine != null) {
      await activeEngine!.dispose();
      activeEngine = null;
    }
  });

  Future<void> runHandshake() async {
    final UciEngine engine = createUciEngine();
    activeEngine = engine;

    await engine.start();

    final Completer<void> uciokCompleter = Completer<void>();
    final StreamSubscription<String> stdoutSub = engine.stdoutLines.listen(
      (String line) {
        if (!uciokCompleter.isCompleted && line.contains('uciok')) {
          uciokCompleter.complete();
        }
      },
      onError: (Object error, StackTrace stackTrace) {
        if (!uciokCompleter.isCompleted) {
          uciokCompleter.completeError(error, stackTrace);
        }
      },
    );

    engine.send('uci');
    await uciokCompleter.future.timeout(
      const Duration(seconds: 10),
      onTimeout: () => throw TimeoutException(
        'Did not receive uciok from Stockfish within timeout.',
      ),
    );

    await stdoutSub.cancel();
    await engine.dispose();
    activeEngine = null;
  }

  testWidgets(
    'Stockfish handshake returns uciok and instance disposes cleanly',
    (WidgetTester tester) async {
      if (!_isMobileTarget()) {
        return;
      }

      await runHandshake();
      await runHandshake();
    },
    timeout: const Timeout(Duration(seconds: 40)),
  );
}

bool _isMobileTarget() {
  if (kIsWeb) {
    return false;
  }
  return defaultTargetPlatform == TargetPlatform.android ||
      defaultTargetPlatform == TargetPlatform.iOS;
}
