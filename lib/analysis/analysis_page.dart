import 'dart:async';

import 'package:chess/chess.dart' as chess;
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import 'analysis_pipeline.dart';
import 'models.dart';
import 'move_classifier.dart';
import 'review_models.dart';
import 'stockfish_lifecycle_manager.dart';
import 'widgets/analysis_summary_header.dart';
import 'widgets/annotated_move_list.dart';
import 'widgets/best_move_arrow_layer.dart';
import 'widgets/eval_bar.dart';
import 'widgets/move_review_panel.dart';

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
  final StockfishLifecycleManager _engineManager =
      StockfishLifecycleManager.instance;

  late List<AnalysisFrame> _frames;
  List<MoveAnnotation?> _annotations = <MoveAnnotation?>[];
  AnalysisSummary _summary = const AnalysisSummary(
    totalMoves: 0,
    counts: <MoveClass, int>{},
    whiteAccuracy: null,
    blackAccuracy: null,
  );
  int _currentPly = 0;
  bool _isAnalyzing = true;
  bool _isShowAutoplaying = false;
  String? _displayFenOverride;
  Timer? _showTimer;
  bool _analysisCancelled = false;
  String? _analysisErrorMessage;
  int _completedFrames = 0;
  late final String _cacheKey;

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
    _cacheKey = _engineManager.cacheKeyForFenHistory(widget.fenHistory);
    _frames = widget.fenHistory
        .map(
          (String fen) => AnalysisFrame(
            fen: fen,
            eval: null,
            annotation: null,
            status: AnalysisStatus.pending,
          ),
        )
        .toList();
    _hydrateFromCacheOrRun();
  }

  @override
  void dispose() {
    _showTimer?.cancel();
    _analysisCancelled = true;
    _pipeline.cancel();
    _engineManager.setAnalysisActive(false);
    _progress.dispose();
    super.dispose();
  }

  Future<void> _hydrateFromCacheOrRun() async {
    final List<EvalResult?>? cached = _engineManager.getCachedEvaluations(
      _cacheKey,
    );
    if (cached != null && cached.length == widget.fenHistory.length) {
      for (int i = 0; i < cached.length; i++) {
        _frames[i] = AnalysisFrame(
          fen: widget.fenHistory[i],
          eval: cached[i],
          annotation: null,
          status: cached[i] == null
              ? AnalysisStatus.timeout
              : AnalysisStatus.ready,
        );
      }
      _completedFrames = _frames.length;
      _recomputeAnnotationsAndSummary();
      setState(() {
        _isAnalyzing = false;
        _progress.value = 1;
      });
      return;
    }
    await _runAnalysis();
  }

  Future<void> _runAnalysis() async {
    _analysisCancelled = false;
    setState(() {
      _isAnalyzing = true;
      _analysisErrorMessage = null;
      _completedFrames = 0;
      _frames = widget.fenHistory
          .map(
            (String fen) => AnalysisFrame(
              fen: fen,
              eval: null,
              annotation: null,
              status: AnalysisStatus.pending,
            ),
          )
          .toList();
    });
    _progress.value = 0;

    try {
      final List<AnalysisFrame> frames = await _pipeline.run(
        fenHistory: widget.fenHistory,
        progress: _progress,
        onFrameReady: (int index, AnalysisFrame frame) {
          if (!mounted) {
            return;
          }
          setState(() {
            _frames[index] = frame;
            _completedFrames = _frames
                .where((AnalysisFrame f) => f.status != AnalysisStatus.pending)
                .length;
            _recomputeAnnotationsAndSummary();
          });
        },
      );
      if (!mounted) {
        return;
      }
      final List<EvalResult?> cacheValues = frames
          .map((AnalysisFrame f) => f.eval)
          .toList();
      _engineManager.setCachedEvaluations(_cacheKey, cacheValues);
      setState(() {
        _frames = frames;
        _completedFrames = _frames
            .where((AnalysisFrame f) => f.status != AnalysisStatus.pending)
            .length;
        _recomputeAnnotationsAndSummary();
        _isAnalyzing = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _analysisErrorMessage = '$error';
        _isAnalyzing = false;
      });
    }
  }

  void _recomputeAnnotationsAndSummary() {
    final List<EvalResult?> evaluations = _frames
        .map((AnalysisFrame f) => f.eval)
        .toList();
    _annotations = _classifier.classifyAll(
      evaluations: evaluations,
      playedMovesUci: widget.playedMovesUci,
    );
    _summary = _classifier.summarize(_annotations);
  }

  @override
  Widget build(BuildContext context) {
    final String activeFen =
        _displayFenOverride ??
        widget.fenHistory[_currentPly.clamp(0, widget.fenHistory.length - 1)];
    final chess.Chess boardState = chess.Chess.fromFEN(activeFen);
    final ReviewedMoveViewModel review = _buildReviewModelForPly(_currentPly);

    final String? bestForReachedPosition = _frameAt(
      _currentPly,
    )?.eval?.bestMove;
    final String? playedMoveForReachedPosition =
        _currentPly > 0 && _currentPly - 1 < widget.playedMovesUci.length
        ? widget.playedMovesUci[_currentPly - 1]
        : null;

    return Scaffold(
      appBar: AppBar(
        title: Text('Analysis   Move $_currentPly / ${widget.sanMoves.length}'),
        actions: <Widget>[
          if (_isAnalyzing)
            IconButton(
              tooltip: 'Cancel analysis',
              onPressed: _cancelAnalysis,
              icon: const Icon(Icons.stop_circle_outlined),
            ),
          IconButton(
            tooltip: 'Restart analysis',
            onPressed: _runAnalysis,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (BuildContext context, BoxConstraints constraints) {
            final bool compact = constraints.maxWidth < 900;
            final Widget boardSection = _buildBoardSection(
              boardState: boardState,
              review: review,
              bestMoveUci: bestForReachedPosition,
              playedMoveUci: playedMoveForReachedPosition,
            );
            final Widget sidePanel = _buildSidePanel();

            return Column(
              children: <Widget>[
                AnalysisSummaryHeader(
                  summary: _summary,
                  resultLabel: widget.resultLabel,
                ),
                if (_isAnalyzing || _analysisErrorMessage != null)
                  _buildProgressStrip(),
                Expanded(
                  child: compact
                      ? Column(
                          children: <Widget>[
                            Expanded(flex: 5, child: boardSection),
                            _buildNavigationControls(),
                            Expanded(flex: 4, child: sidePanel),
                          ],
                        )
                      : Row(
                          children: <Widget>[
                            Expanded(flex: 3, child: boardSection),
                            Expanded(
                              flex: 2,
                              child: Column(
                                children: <Widget>[
                                  _buildNavigationControls(),
                                  Expanded(child: sidePanel),
                                ],
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

  Widget _buildProgressStrip() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: ValueListenableBuilder<double>(
        valueListenable: _progress,
        builder: (BuildContext context, double value, Widget? child) {
          final int total = widget.fenHistory.length;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              LinearProgressIndicator(value: _isAnalyzing ? value : null),
              const SizedBox(height: 4),
              Text(
                _analysisErrorMessage != null
                    ? 'Analysis error: $_analysisErrorMessage'
                    : _isAnalyzing
                    ? 'Analysing... $_completedFrames / $total positions'
                    : _analysisCancelled
                    ? 'Analysis cancelled'
                    : 'Analysis complete',
                style: const TextStyle(fontSize: 12),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildBoardSection({
    required chess.Chess boardState,
    required ReviewedMoveViewModel review,
    required String? bestMoveUci,
    required String? playedMoveUci,
  }) {
    final EvalResult? eval = _frameAt(_currentPly)?.eval;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Column(
        children: <Widget>[
          Expanded(
            child: Row(
              children: <Widget>[
                EvalBar(
                  centipawns: eval?.centipawns ?? 0,
                  mateIn: eval?.mateIn,
                  isLoading:
                      _frameAt(_currentPly)?.status == AnalysisStatus.pending,
                  isPaused:
                      _isAnalyzing &&
                      _frameAt(_currentPly)?.status != AnalysisStatus.ready,
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
                          if (_displayFenOverride != null)
                            Positioned(
                              top: 8,
                              left: 8,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xCC262421),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: const Text(
                                  'Previewing best line',
                                  style: TextStyle(fontSize: 11),
                                ),
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
          MoveReviewPanel(review: review, showingBestLine: _isShowAutoplaying),
        ],
      ),
    );
  }

  Widget _buildSidePanel() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Column(
        children: <Widget>[
          _buildMistakeJumpRow(),
          const SizedBox(height: 8),
          Expanded(
            child: AnnotatedMoveList(
              sanMoves: widget.sanMoves,
              annotations: _annotations,
              statuses: _moveStatuses(),
              currentPly: _currentPly,
              onJumpToPly: _jumpToPly,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMistakeJumpRow() {
    return Row(
      children: <Widget>[
        Expanded(
          child: OutlinedButton.icon(
            onPressed: _prevMistake,
            icon: const Icon(Icons.keyboard_double_arrow_left),
            label: const Text('Prev mistake'),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: OutlinedButton.icon(
            onPressed: _nextMistake,
            icon: const Icon(Icons.keyboard_double_arrow_right),
            label: const Text('Next mistake'),
          ),
        ),
      ],
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
        spacing: 8,
        runSpacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: <Widget>[
          IconButton(
            onPressed: _jumpToStart,
            icon: const Icon(Icons.first_page),
          ),
          IconButton(onPressed: _prevPly, icon: const Icon(Icons.chevron_left)),
          Text('Move $_currentPly'),
          IconButton(
            onPressed: _nextPly,
            icon: const Icon(Icons.chevron_right),
          ),
          IconButton(onPressed: _jumpToEnd, icon: const Icon(Icons.last_page)),
          FilledButton(
            onPressed: _toggleShowAutoplay,
            child: Text(_isShowAutoplaying ? 'Stop' : 'Show'),
          ),
          if (_displayFenOverride != null)
            TextButton(onPressed: _resetPreview, child: const Text('Reset')),
        ],
      ),
    );
  }

  void _cancelAnalysis() {
    _analysisCancelled = true;
    _pipeline.cancel();
    _engineManager.setAnalysisActive(false);
    _engineManager.stopSearch();
    setState(() {
      _isAnalyzing = false;
    });
  }

  void _resetPreview() {
    _showTimer?.cancel();
    setState(() {
      _isShowAutoplaying = false;
      _displayFenOverride = null;
    });
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

  void _prevMistake() {
    for (
      int i = (_currentPly - 2).clamp(0, _annotations.length - 1);
      i >= 0;
      i--
    ) {
      final MoveAnnotation? ann = i < _annotations.length
          ? _annotations[i]
          : null;
      if (ann != null && _isMistakeOrWorse(ann.classification)) {
        _jumpToPly(i + 1);
        return;
      }
    }
  }

  void _nextMistake() {
    for (int i = _currentPly; i < _annotations.length; i++) {
      final MoveAnnotation? ann = _annotations[i];
      if (ann != null && _isMistakeOrWorse(ann.classification)) {
        _jumpToPly(i + 1);
        return;
      }
    }
  }

  bool _isMistakeOrWorse(MoveClass c) {
    return c == MoveClass.inaccuracy ||
        c == MoveClass.mistake ||
        c == MoveClass.blunder;
  }

  void _toggleShowAutoplay() {
    if (_isShowAutoplaying) {
      _resetPreview();
      return;
    }

    final EvalResult? eval = _frameAt(_currentPly)?.eval;
    if (eval == null || eval.pv.isEmpty) {
      return;
    }

    final List<String> sequence = _buildFenSequenceForPv(
      startFen: widget.fenHistory[_currentPly],
      pv: eval.pv,
    );
    if (sequence.length <= 1) {
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

  ReviewedMoveViewModel _buildReviewModelForPly(int ply) {
    final int moveIndex = ply - 1;
    final AnalysisFrame? beforeFrame = _frameAt(moveIndex);
    final AnalysisFrame? afterFrame = _frameAt(moveIndex + 1);
    final String? playedUci =
        (moveIndex >= 0 && moveIndex < widget.playedMovesUci.length)
        ? widget.playedMovesUci[moveIndex]
        : null;
    final String? playedSan =
        (moveIndex >= 0 && moveIndex < widget.sanMoves.length)
        ? widget.sanMoves[moveIndex]
        : null;
    final EvalResult? evalBefore = beforeFrame?.eval;
    final String? bestUci = evalBefore?.bestMove;
    final String? bestSan = bestUci == null || bestUci.isEmpty
        ? null
        : _uciMoveToSan(beforeFrame!.fen, bestUci);
    final List<String> pvUci = evalBefore?.pv ?? const <String>[];
    final List<String> pvSan = evalBefore == null
        ? const <String>[]
        : _uciToSanList(beforeFrame!.fen, pvUci);
    final MoveAnnotation? annotation =
        (moveIndex >= 0 && moveIndex < _annotations.length)
        ? _annotations[moveIndex]
        : null;
    final AnalysisStatus status = beforeFrame?.status ?? AnalysisStatus.pending;

    return ReviewedMoveViewModel(
      plyIndex: ply,
      fen: widget.fenHistory[ply.clamp(0, widget.fenHistory.length - 1)],
      playedMoveUci: playedUci,
      playedMoveSan: playedSan,
      bestMoveUci: bestUci,
      bestMoveSan: bestSan,
      pvUci: pvUci,
      pvSan: pvSan,
      annotation: annotation,
      evalBefore: evalBefore,
      evalAfter: afterFrame?.eval,
      status: status,
    );
  }

  AnalysisFrame? _frameAt(int index) {
    if (index < 0 || index >= _frames.length) {
      return null;
    }
    return _frames[index];
  }

  List<AnalysisStatus> _moveStatuses() {
    final List<AnalysisStatus> out = <AnalysisStatus>[];
    for (int i = 0; i < widget.sanMoves.length; i++) {
      final AnalysisFrame? before = _frameAt(i);
      final AnalysisFrame? after = _frameAt(i + 1);
      if (before == null || after == null) {
        out.add(AnalysisStatus.pending);
        continue;
      }
      if (before.status == AnalysisStatus.pending ||
          after.status == AnalysisStatus.pending) {
        out.add(AnalysisStatus.pending);
      } else if (before.status == AnalysisStatus.error ||
          after.status == AnalysisStatus.error) {
        out.add(AnalysisStatus.error);
      } else if (before.status == AnalysisStatus.timeout ||
          after.status == AnalysisStatus.timeout) {
        out.add(AnalysisStatus.timeout);
      } else {
        out.add(AnalysisStatus.ready);
      }
    }
    return out;
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
