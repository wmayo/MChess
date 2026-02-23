import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:stockfish/stockfish.dart';

import '../analysis/models.dart';
import 'uci_engine.dart';

/// Lifecycle overview:
/// idle -> start() -> starting -> ready -> send(...)
/// ready -> dispose() -> quitting -> disposed/error -> idle (new instance allowed)
///
/// Guardrails:
/// - Non-Android/iOS returns unsupported engine.
/// - start() is idempotent while started.
/// - send() throws unless ready.
/// - dispose() waits for terminal state to avoid singleton reuse races.
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
  Future<void> initialize() {
    throw UnsupportedError(
      'Stockfish engine is only supported on Android and iOS.',
    );
  }

  @override
  Future<void> isReady() {
    throw UnsupportedError(
      'Stockfish engine is only supported on Android and iOS.',
    );
  }

  @override
  Future<void> setOption(String name, String value) {
    throw UnsupportedError(
      'Stockfish engine is only supported on Android and iOS.',
    );
  }

  @override
  Future<void> newGame() {
    throw UnsupportedError(
      'Stockfish engine is only supported on Android and iOS.',
    );
  }

  @override
  Future<void> setPosition(String fen) {
    throw UnsupportedError(
      'Stockfish engine is only supported on Android and iOS.',
    );
  }

  @override
  Future<EvalResult?> go({required int depth, required int moveTimeMs}) {
    throw UnsupportedError(
      'Stockfish engine is only supported on Android and iOS.',
    );
  }

  @override
  Future<EvalResult?> stop() {
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
  bool _initialized = false;
  Completer<void>? _pendingUciCompleter;
  Completer<void>? _pendingReadyCompleter;
  Completer<EvalResult?>? _pendingEvalCompleter;
  EvalResult? _bestEvalCandidate;
  bool _searchInProgress = false;

  @override
  Stream<String> get stdoutLines => _stdoutController.stream;

  @override
  Future<void> start() async {
    if (_started) {
      return;
    }

    final Stockfish engine = Stockfish();
    _engine = engine;
    _stdoutSubscription = engine.stdout.listen((String line) {
      _handleEngineLine(line);
      _stdoutController.add(line);
    }, onError: _stdoutController.addError);

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
  Future<void> initialize() async {
    if (_initialized) {
      return;
    }
    if (!_started) {
      await start();
    }

    final Completer<void> completer = Completer<void>();
    _pendingUciCompleter = completer;
    send('uci');

    try {
      await completer.future.timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          throw TimeoutException('Timed out waiting for uciok.');
        },
      );
      _initialized = true;
    } finally {
      _pendingUciCompleter = null;
    }
  }

  @override
  Future<void> isReady() async {
    if (!_initialized) {
      await initialize();
    }
    if (_pendingReadyCompleter != null) {
      return _pendingReadyCompleter!.future;
    }

    final Completer<void> completer = Completer<void>();
    _pendingReadyCompleter = completer;
    send('isready');

    try {
      await completer.future.timeout(
        const Duration(seconds: 5),
        onTimeout: () =>
            throw TimeoutException('Timed out waiting for readyok.'),
      );
    } finally {
      _pendingReadyCompleter = null;
    }
  }

  @override
  Future<void> setOption(String name, String value) async {
    if (!_initialized) {
      await initialize();
    }
    send('setoption name $name value $value');
    await isReady();
  }

  @override
  Future<void> newGame() async {
    if (!_initialized) {
      await initialize();
    }
    send('ucinewgame');
    await isReady();
  }

  @override
  Future<void> setPosition(String fen) async {
    if (!_initialized) {
      await initialize();
    }
    await isReady();
    send('position fen $fen');
  }

  @override
  Future<EvalResult?> go({required int depth, required int moveTimeMs}) async {
    if (!_initialized) {
      await initialize();
    }
    return _runEvalCommand(
      'go depth $depth movetime $moveTimeMs',
      timeout: const Duration(seconds: 4),
    );
  }

  @override
  Future<EvalResult?> stop() async {
    if (!_initialized) {
      return null;
    }
    if (!_searchInProgress) {
      return null;
    }
    return _runEvalCommand('stop', timeout: const Duration(seconds: 4));
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
    _initialized = false;

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
    _clearPendingEval();
    _pendingUciCompleter = null;
    _pendingReadyCompleter = null;

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

  Future<EvalResult?> _runEvalCommand(
    String command, {
    required Duration timeout,
  }) async {
    if (_pendingEvalCompleter != null) {
      throw StateError('An evaluation command is already in progress.');
    }

    final Completer<EvalResult?> completer = Completer<EvalResult?>();
    _pendingEvalCompleter = completer;
    _bestEvalCandidate = null;
    _searchInProgress = true;

    send(command);

    try {
      return await completer.future.timeout(timeout, onTimeout: () => null);
    } finally {
      _clearPendingEval();
      _searchInProgress = false;
    }
  }

  void _clearPendingEval() {
    _pendingEvalCompleter = null;
    _bestEvalCandidate = null;
  }

  void _handleEngineLine(String line) {
    final String trimmed = line.trim();
    if (trimmed.isEmpty) {
      return;
    }

    if (trimmed == 'uciok' && _pendingUciCompleter != null) {
      if (!_pendingUciCompleter!.isCompleted) {
        _pendingUciCompleter!.complete();
      }
    }
    if (trimmed == 'readyok' && _pendingReadyCompleter != null) {
      if (!_pendingReadyCompleter!.isCompleted) {
        _pendingReadyCompleter!.complete();
      }
    }

    final Completer<EvalResult?>? pendingEval = _pendingEvalCompleter;
    if (pendingEval == null || pendingEval.isCompleted) {
      return;
    }

    final _ParsedInfo? parsedInfo = _parseInfo(trimmed);
    if (parsedInfo != null) {
      final EvalResult candidate = EvalResult(
        centipawns: parsedInfo.centipawns,
        mateIn: parsedInfo.mateIn,
        bestMove: _bestEvalCandidate?.bestMove ?? '',
        pv: parsedInfo.pv,
        depth: parsedInfo.depth,
      );
      if (_bestEvalCandidate == null ||
          candidate.depth >= _bestEvalCandidate!.depth) {
        _bestEvalCandidate = candidate;
      }
      return;
    }

    if (!trimmed.startsWith('bestmove ')) {
      return;
    }

    final List<String> parts = trimmed.split(RegExp(r'\s+'));
    final String bestMove = parts.length > 1 ? parts[1] : '';
    final EvalResult resolved = _bestEvalCandidate == null
        ? EvalResult(
            centipawns: 0,
            mateIn: null,
            bestMove: bestMove,
            pv: const <String>[],
            depth: 0,
          )
        : EvalResult(
            centipawns: _bestEvalCandidate!.centipawns,
            mateIn: _bestEvalCandidate!.mateIn,
            bestMove: bestMove,
            pv: _bestEvalCandidate!.pv,
            depth: _bestEvalCandidate!.depth,
          );
    if (!pendingEval.isCompleted) {
      pendingEval.complete(resolved);
    }
  }

  _ParsedInfo? _parseInfo(String line) {
    if (!line.startsWith('info ')) {
      return null;
    }

    final List<String> tokens = line.split(RegExp(r'\s+'));
    int? depth;
    int? centipawns;
    int? mateIn;
    List<String> pv = const <String>[];

    for (int i = 0; i < tokens.length; i++) {
      final String token = tokens[i];
      if (token == 'depth' && i + 1 < tokens.length) {
        depth = int.tryParse(tokens[i + 1]);
      } else if (token == 'score' && i + 2 < tokens.length) {
        final String scoreType = tokens[i + 1];
        final int? scoreValue = int.tryParse(tokens[i + 2]);
        if (scoreValue == null) {
          continue;
        }
        if (scoreType == 'cp') {
          centipawns = scoreValue;
          mateIn = null;
        } else if (scoreType == 'mate') {
          mateIn = scoreValue;
          centipawns = scoreValue >= 0 ? 30000 : -30000;
        }
      } else if (token == 'pv' && i + 1 < tokens.length) {
        pv = tokens.sublist(i + 1);
        break;
      }
    }

    if (depth == null || centipawns == null) {
      return null;
    }

    return _ParsedInfo(
      depth: depth,
      centipawns: centipawns,
      mateIn: mateIn,
      pv: pv,
    );
  }
}

class _ParsedInfo {
  final int depth;
  final int centipawns;
  final int? mateIn;
  final List<String> pv;

  const _ParsedInfo({
    required this.depth,
    required this.centipawns,
    required this.mateIn,
    required this.pv,
  });
}
