import 'dart:async';

import 'package:chess/chess.dart' as chess;
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import 'analysis_pipeline.dart';
import 'models.dart';
import 'move_classifier.dart';
import 'widgets/annotated_move_list.dart';
import 'widgets/best_move_arrow_layer.dart';
import 'widgets/eval_bar.dart';
import 'widgets/pv_line_display.dart';

class AnalysisPage extends StatefulWidget {
  const AnalysisPage({
    super.key,
    required this.fenHistory,
    required this.sanMoves,
    required this.playedMovesUci,
    this.resultLabel,
  });

  final List<String> fenHistory;
  final List<String> sanMoves;
  final List<String> playedMovesUci;
  final String? resultLabel;

  @override
  State<AnalysisPage> createState() => _AnalysisPageState();
}

class _AnalysisPageState extends State<AnalysisPage> {
  final ValueNotifier<double> _progress = ValueNotifier<double>(0);
  final AnalysisPipeline _pipeline = AnalysisPipeline();
  final MoveClassifier _classifier = MoveClassifier();

  List<EvalResult?> _evaluations = <EvalResult?>[];
  List<MoveAnnotation?> _annotations = <MoveAnnotation?>[];
  int _currentPly = 0;
  bool _isAnalyzing = true;
  bool _isShowAutoplaying = false;
  String? _displayFenOverride;
  Timer? _showTimer;

  static const List<String> _files = <String>[
    'a',
    'b',
    'c',
    'd',
    'e',
    'f',
    'g',
    'h',
  ];

  @override
  void initState() {
    super.initState();
    _runAnalysis();
  }

  @override
  void dispose() {
    _showTimer?.cancel();
    _pipeline.cancel();
    _progress.dispose();
    super.dispose();
  }

  Future<void> _runAnalysis() async {
    final List<EvalResult?> evals = await _pipeline.run(
      fenHistory: widget.fenHistory,
      progress: _progress,
    );
    if (!mounted) {
      return;
    }
    setState(() {
      _evaluations = evals;
      _annotations = _classifier.classifyAll(
        evaluations: evals,
        playedMovesUci: widget.playedMovesUci,
      );
      _isAnalyzing = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final String activeFen =
        _displayFenOverride ?? widget.fenHistory[_currentPly];
    final chess.Chess boardState = chess.Chess.fromFEN(activeFen);
    final EvalResult? currentEval = _currentPly < _evaluations.length
        ? _evaluations[_currentPly]
        : null;
    final List<String> pvSan = currentEval == null
        ? const <String>[]
        : _uciToSanList(activeFen, currentEval.pv);
    final String bestSan = currentEval == null || currentEval.bestMove.isEmpty
        ? '-'
        : _uciMoveToSan(activeFen, currentEval.bestMove) ??
              currentEval.bestMove;

    final String? bestForReachedPosition = _currentPly < _evaluations.length
        ? _evaluations[_currentPly]?.bestMove
        : null;
    final String? playedMove =
        _currentPly > 0 && _currentPly - 1 < widget.playedMovesUci.length
        ? widget.playedMovesUci[_currentPly - 1]
        : null;

    return Scaffold(
      appBar: AppBar(
        title: Text('Analysis   Move $_currentPly / ${widget.sanMoves.length}'),
      ),
      body: SafeArea(
        child: _isAnalyzing
            ? _buildLoading(activeFen)
            : LayoutBuilder(
                builder: (BuildContext context, BoxConstraints constraints) {
                  final bool compact = constraints.maxWidth < 900;
                  final Widget boardSection = _buildBoardSection(
                    boardState: boardState,
                    currentEval: currentEval,
                    bestMoveUci: bestForReachedPosition,
                    playedMoveUci: playedMove,
                    bestSan: bestSan,
                    pvSan: pvSan,
                  );

                  if (compact) {
                    return Column(
                      children: <Widget>[
                        Expanded(flex: 5, child: boardSection),
                        _buildNavigationControls(),
                        Expanded(
                          flex: 4,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            child: AnnotatedMoveList(
                              sanMoves: widget.sanMoves,
                              annotations: _annotations,
                              currentPly: _currentPly,
                              onJumpToPly: _jumpToPly,
                            ),
                          ),
                        ),
                      ],
                    );
                  }

                  return Row(
                    children: <Widget>[
                      Expanded(flex: 3, child: boardSection),
                      Expanded(
                        flex: 2,
                        child: Column(
                          children: <Widget>[
                            _buildNavigationControls(),
                            Expanded(
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                ),
                                child: AnnotatedMoveList(
                                  sanMoves: widget.sanMoves,
                                  annotations: _annotations,
                                  currentPly: _currentPly,
                                  onJumpToPly: _jumpToPly,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  );
                },
              ),
      ),
    );
  }

  Widget _buildLoading(String initialFen) {
    final chess.Chess boardState = chess.Chess.fromFEN(initialFen);
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        children: <Widget>[
          Expanded(
            child: Center(
              child: AspectRatio(
                aspectRatio: 1,
                child: _buildBoardGrid(boardState),
              ),
            ),
          ),
          ValueListenableBuilder<double>(
            valueListenable: _progress,
            builder: (BuildContext context, double value, Widget? child) {
              final int done = (value * widget.fenHistory.length).floor();
              return Column(
                children: <Widget>[
                  LinearProgressIndicator(value: value),
                  const SizedBox(height: 8),
                  Text(
                    'Analysing... $done / ${widget.fenHistory.length} moves',
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildBoardSection({
    required chess.Chess boardState,
    required EvalResult? currentEval,
    required String? bestMoveUci,
    required String? playedMoveUci,
    required String bestSan,
    required List<String> pvSan,
  }) {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        children: <Widget>[
          Expanded(
            child: Row(
              children: <Widget>[
                EvalBar(
                  centipawns: currentEval?.centipawns ?? 0,
                  mateIn: currentEval?.mateIn,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: GestureDetector(
                    onHorizontalDragEnd: (DragEndDetails details) {
                      if (details.primaryVelocity == null) {
                        return;
                      }
                      if (details.primaryVelocity! < 0) {
                        _nextPly();
                      } else {
                        _prevPly();
                      }
                    },
                    child: AspectRatio(
                      aspectRatio: 1,
                      child: Stack(
                        children: <Widget>[
                          Positioned.fill(child: _buildBoardGrid(boardState)),
                          Positioned.fill(
                            child: BestMoveArrowLayer(
                              bestMoveUci: bestMoveUci,
                              playedMoveUci: playedMoveUci,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          PvLineDisplay(bestMoveSan: bestSan, pvSan: pvSan),
        ],
      ),
    );
  }

  Widget _buildBoardGrid(chess.Chess boardState) {
    return GridView.builder(
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 8,
      ),
      itemCount: 64,
      itemBuilder: (BuildContext context, int index) {
        final int rankIndex = index ~/ 8;
        final int fileIndex = index % 8;
        final String square = '${_files[fileIndex]}${8 - rankIndex}';
        final dynamic piece = boardState.get(square);
        final bool light = (rankIndex + fileIndex).isEven;

        return Container(
          color: light ? const Color(0xFFEEEED2) : const Color(0xFF769656),
          child: piece == null
              ? null
              : Center(
                  child: SvgPicture.asset(
                    _pieceAsset(piece),
                    width: 42,
                    height: 42,
                  ),
                ),
        );
      },
    );
  }

  Widget _buildNavigationControls() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Wrap(
        spacing: 10,
        runSpacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: <Widget>[
          IconButton(
            onPressed: _isAnalyzing ? null : _jumpToStart,
            icon: const Icon(Icons.first_page),
          ),
          IconButton(
            onPressed: _isAnalyzing ? null : _prevPly,
            icon: const Icon(Icons.chevron_left),
          ),
          Text('Move $_currentPly'),
          IconButton(
            onPressed: _isAnalyzing ? null : _nextPly,
            icon: const Icon(Icons.chevron_right),
          ),
          IconButton(
            onPressed: _isAnalyzing ? null : _jumpToEnd,
            icon: const Icon(Icons.last_page),
          ),
          FilledButton(
            onPressed: _isAnalyzing ? null : _toggleShowAutoplay,
            child: Text(_isShowAutoplaying ? 'Stop' : 'Show'),
          ),
        ],
      ),
    );
  }

  void _jumpToPly(int ply) {
    _showTimer?.cancel();
    setState(() {
      _isShowAutoplaying = false;
      _displayFenOverride = null;
      _currentPly = ply.clamp(0, widget.fenHistory.length - 1);
    });
  }

  void _jumpToStart() => _jumpToPly(0);

  void _jumpToEnd() => _jumpToPly(widget.fenHistory.length - 1);

  void _prevPly() => _jumpToPly(_currentPly - 1);

  void _nextPly() => _jumpToPly(_currentPly + 1);

  void _toggleShowAutoplay() {
    if (_isShowAutoplaying) {
      _showTimer?.cancel();
      setState(() {
        _isShowAutoplaying = false;
        _displayFenOverride = null;
      });
      return;
    }

    final EvalResult? eval = _currentPly < _evaluations.length
        ? _evaluations[_currentPly]
        : null;
    if (eval == null || eval.pv.isEmpty) {
      return;
    }

    final List<String> sequence = _buildFenSequenceForPv(
      startFen: widget.fenHistory[_currentPly],
      pv: eval.pv,
    );
    if (sequence.isEmpty) {
      return;
    }

    int step = 0;
    setState(() {
      _isShowAutoplaying = true;
      _displayFenOverride = sequence.first;
    });

    _showTimer?.cancel();
    _showTimer = Timer.periodic(const Duration(milliseconds: 700), (
      Timer timer,
    ) {
      step++;
      if (!mounted || step >= sequence.length) {
        timer.cancel();
        setState(() {
          _isShowAutoplaying = false;
          _displayFenOverride = null;
        });
        return;
      }
      setState(() {
        _displayFenOverride = sequence[step];
      });
    });
  }

  List<String> _buildFenSequenceForPv({
    required String startFen,
    required List<String> pv,
  }) {
    final chess.Chess game = chess.Chess.fromFEN(startFen);
    final List<String> sequence = <String>[startFen];
    for (final String move in pv) {
      if (move.length < 4) {
        break;
      }
      final Map<String, dynamic> payload = <String, dynamic>{
        'from': move.substring(0, 2),
        'to': move.substring(2, 4),
      };
      if (move.length >= 5) {
        payload['promotion'] = move[4];
      }
      final bool ok = game.move(payload);
      if (!ok) {
        break;
      }
      sequence.add(game.fen);
    }
    return sequence;
  }

  List<String> _uciToSanList(String fen, List<String> uciMoves) {
    final chess.Chess game = chess.Chess.fromFEN(fen);
    final List<String> san = <String>[];
    for (final String move in uciMoves) {
      final String? single = _uciMoveToSan(game.fen, move);
      if (single == null) {
        break;
      }
      san.add(single);
      final Map<String, dynamic> payload = <String, dynamic>{
        'from': move.substring(0, 2),
        'to': move.substring(2, 4),
      };
      if (move.length >= 5) {
        payload['promotion'] = move[4];
      }
      if (!game.move(payload)) {
        break;
      }
    }
    return san;
  }

  String? _uciMoveToSan(String fen, String uciMove) {
    if (uciMove.length < 4) {
      return null;
    }
    final chess.Chess game = chess.Chess.fromFEN(fen);
    final Map<String, dynamic> payload = <String, dynamic>{
      'from': uciMove.substring(0, 2),
      'to': uciMove.substring(2, 4),
    };
    if (uciMove.length >= 5) {
      payload['promotion'] = uciMove[4];
    }
    final bool ok = game.move(payload);
    if (!ok) {
      return null;
    }
    final List<dynamic> history = game.getHistory(<String, dynamic>{
      'verbose': true,
    });
    if (history.isEmpty) {
      return null;
    }
    return (history.last as Map<String, dynamic>)['san'] as String?;
  }

  String _pieceAsset(dynamic piece) {
    final String colorPrefix = piece.color == chess.Color.WHITE ? 'w' : 'b';
    final String type = piece.type.toString();
    const Map<String, String> typeCode = <String, String>{
      'k': 'K',
      'q': 'Q',
      'r': 'R',
      'b': 'B',
      'n': 'N',
      'p': 'P',
    };
    final String pieceCode = typeCode[type] ?? '';
    return 'assets/pieces/lichess/cburnett/$colorPrefix$pieceCode.svg';
  }
}
