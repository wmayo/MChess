import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:stockfish/stockfish.dart';

import 'uci_engine.dart';

UciEngine createUciEngine() {
  if (Platform.isAndroid || Platform.isIOS) {
    return StockfishEngineMobile();
  }
  return UnsupportedUciEngineIO();
}

class UnsupportedUciEngineIO implements UciEngine {
  @override
  Stream<String> get stdoutLines => const Stream<String>.empty();

  @override
  Future<void> start() {
    throw UnsupportedError(
      'Stockfish engine is only supported on Android and iOS.',
    );
  }

  @override
  void send(String command) {
    throw UnsupportedError(
      'Stockfish engine is only supported on Android and iOS.',
    );
  }

  @override
  Future<void> dispose() async {}
}

class StockfishEngineMobile implements UciEngine {
  Stockfish? _engine;
  StreamSubscription<String>? _stdoutSubscription;
  final StreamController<String> _stdoutController =
      StreamController<String>.broadcast();
  bool _started = false;

  @override
  Stream<String> get stdoutLines => _stdoutController.stream;

  @override
  Future<void> start() async {
    if (_started) {
      return;
    }

    final Stockfish engine = Stockfish();
    _engine = engine;
    _stdoutSubscription = engine.stdout.listen(
      _stdoutController.add,
      onError: _stdoutController.addError,
    );

    if (engine.state.value == StockfishState.ready) {
      _started = true;
      return;
    }

    final Completer<void> readyCompleter = Completer<void>();
    late VoidCallback listener;
    listener = () {
      final StockfishState state = engine.state.value;
      if (state == StockfishState.ready) {
        if (!readyCompleter.isCompleted) {
          readyCompleter.complete();
        }
        return;
      }
      if (state == StockfishState.error || state == StockfishState.disposed) {
        if (!readyCompleter.isCompleted) {
          readyCompleter.completeError(
            StateError('Stockfish failed to start. Current state: $state'),
          );
        }
      }
    };

    engine.state.addListener(listener);
    try {
      await readyCompleter.future.timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          throw TimeoutException(
            'Timed out waiting for Stockfish to become ready.',
          );
        },
      );
      _started = true;
    } finally {
      engine.state.removeListener(listener);
    }
  }

  @override
  void send(String command) {
    if (!_started || _engine == null) {
      throw StateError('Stockfish is not started.');
    }
    _engine!.stdin = command;
  }

  @override
  Future<void> dispose() async {
    final Stockfish? engine = _engine;
    _engine = null;
    _started = false;

    if (engine != null && engine.state.value == StockfishState.ready) {
      try {
        final Future<void> disposedFuture = _waitForDisposed(engine);
        engine.dispose();
        await disposedFuture;
      } catch (_) {
        // Best effort cleanup; the plugin enforces singleton semantics.
      }
    }

    await _stdoutSubscription?.cancel();
    _stdoutSubscription = null;

    if (!_stdoutController.isClosed) {
      await _stdoutController.close();
    }
  }

  Future<void> _waitForDisposed(Stockfish engine) async {
    final StockfishState current = engine.state.value;
    if (current == StockfishState.disposed || current == StockfishState.error) {
      return;
    }

    final Completer<void> completer = Completer<void>();
    late VoidCallback listener;
    listener = () {
      final StockfishState state = engine.state.value;
      if (state == StockfishState.disposed || state == StockfishState.error) {
        if (!completer.isCompleted) {
          completer.complete();
        }
      }
    };

    engine.state.addListener(listener);
    try {
      await completer.future.timeout(const Duration(seconds: 5));
    } finally {
      engine.state.removeListener(listener);
    }
  }
}
