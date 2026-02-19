import 'package:chess/chess.dart' as chess;
import 'package:flutter/material.dart';

void main() {
  runApp(const MChessApp());
}

class MChessApp extends StatelessWidget {
  const MChessApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'MChess',
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF1E1E1B),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF7FA650),
          secondary: Color(0xFFBACA44),
          surface: Color(0xFF262421),
        ),
      ),
      home: const ChessGamePage(),
    );
  }
}

class ChessGamePage extends StatefulWidget {
  const ChessGamePage({super.key});

  @override
  State<ChessGamePage> createState() => _ChessGamePageState();
}

class _ChessGamePageState extends State<ChessGamePage> {
  final dynamic _game = chess.Chess();
  final List<Map<String, dynamic>> _redoMoves = <Map<String, dynamic>>[];

  String? _selectedSquare;
  Set<String> _legalTargets = <String>{};

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
  Widget build(BuildContext context) {
    final List<String> history = _buildSanHistory();

    return Scaffold(
      appBar: AppBar(
        title: const Text('MChess'),
        backgroundColor: const Color(0xFF262421),
        actions: <Widget>[
          IconButton(
            onPressed: _undo,
            tooltip: 'Undo',
            icon: const Icon(Icons.undo),
          ),
          IconButton(
            onPressed: _redo,
            tooltip: 'Redo',
            icon: const Icon(Icons.redo),
          ),
        ],
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (BuildContext context, BoxConstraints constraints) {
            final bool compact = constraints.maxWidth < 900;
            if (compact) {
              return Column(
                children: <Widget>[
                  _buildStatusBar(),
                  Expanded(child: _buildBoardArea()),
                  SizedBox(height: 240, child: _buildMoveHistory(history)),
                ],
              );
            }

            return Row(
              children: <Widget>[
                Expanded(
                  flex: 3,
                  child: Column(
                    children: <Widget>[
                      _buildStatusBar(),
                      Expanded(child: _buildBoardArea()),
                    ],
                  ),
                ),
                Expanded(flex: 2, child: _buildMoveHistory(history)),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildStatusBar() {
    return Container(
      width: double.infinity,
      color: const Color(0xFF262421),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Text(
        _statusText(),
        style: const TextStyle(fontWeight: FontWeight.w600),
      ),
    );
  }

  Widget _buildBoardArea() {
    return Center(
      child: AspectRatio(
        aspectRatio: 1,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: GridView.builder(
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 8,
            ),
            itemCount: 64,
            itemBuilder: (BuildContext context, int index) {
              final int rankIndex = index ~/ 8;
              final int fileIndex = index % 8;
              final String square = '${_files[fileIndex]}${8 - rankIndex}';
              return _buildSquare(square, rankIndex, fileIndex);
            },
          ),
        ),
      ),
    );
  }

  Widget _buildSquare(String square, int rankIndex, int fileIndex) {
    final bool light = (rankIndex + fileIndex).isEven;
    final bool isSelected = square == _selectedSquare;
    final bool isLegal = _legalTargets.contains(square);
    final dynamic piece = _game.get(square);

    Color color = light ? const Color(0xFFEEEED2) : const Color(0xFF769656);
    if (isSelected) {
      color = const Color(0xFFF6F669);
    } else if (isLegal) {
      color = const Color(0xFFBACA44);
    }

    final Widget pieceWidget = Center(
      child: Text(
        _pieceSymbol(piece),
        style: const TextStyle(fontSize: 34),
      ),
    );

    return DragTarget<String>(
      onWillAcceptWithDetails: (DragTargetDetails<String> details) {
        return _legalMovesFrom(details.data).contains(square);
      },
      onAcceptWithDetails: (DragTargetDetails<String> details) {
        _attemptMove(details.data, square);
      },
      builder:
          (
            BuildContext context,
            List<String?> candidateData,
            List<dynamic> rejectedData,
          ) {
            return GestureDetector(
              onTap: () => _handleTap(square),
              child: Container(
                color: color,
                child: piece == null
                    ? null
                    : Draggable<String>(
                        data: square,
                        feedback: Material(
                          color: Colors.transparent,
                          child: SizedBox(
                            width: 48,
                            height: 48,
                            child: pieceWidget,
                          ),
                        ),
                        childWhenDragging: const SizedBox.shrink(),
                        child: pieceWidget,
                      ),
              ),
            );
          },
    );
  }

  Widget _buildMoveHistory(List<String> history) {
    return Container(
      margin: const EdgeInsets.all(12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF262421),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Text(
            'Moves',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 10),
          Expanded(
            child: history.isEmpty
                ? const Text('No moves yet.')
                : ListView.builder(
                    itemCount: (history.length / 2).ceil(),
                    itemBuilder: (BuildContext context, int index) {
                      final int whiteMoveIndex = index * 2;
                      final int blackMoveIndex = whiteMoveIndex + 1;
                      final String white = history[whiteMoveIndex];
                      final String black = blackMoveIndex < history.length
                          ? history[blackMoveIndex]
                          : '';

                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 2),
                        child: Text(
                          '${index + 1}. $white ${black.trimRight()}',
                          style: const TextStyle(fontSize: 14),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  void _handleTap(String square) {
    if (_selectedSquare == null) {
      final Set<String> legal = _legalMovesFrom(square);
      if (legal.isNotEmpty) {
        setState(() {
          _selectedSquare = square;
          _legalTargets = legal;
        });
      }
      return;
    }

    if (square == _selectedSquare) {
      setState(_clearSelection);
      return;
    }

    if (_legalTargets.contains(square)) {
      _attemptMove(_selectedSquare!, square);
      return;
    }

    final Set<String> legal = _legalMovesFrom(square);
    setState(() {
      _selectedSquare = legal.isEmpty ? null : square;
      _legalTargets = legal;
    });
  }

  Set<String> _legalMovesFrom(String square) {
    final List<dynamic> moves = _game.moves(<String, dynamic>{
      'square': square,
      'verbose': true,
    }) as List<dynamic>;

    return moves
        .map((dynamic move) => (move as Map<String, dynamic>)['to'] as String)
        .toSet();
  }

  Future<void> _attemptMove(String from, String to) async {
    final List<dynamic> legalMoves = _game.moves(<String, dynamic>{
      'square': from,
      'verbose': true,
    }) as List<dynamic>;

    if (legalMoves.isEmpty) {
      setState(_clearSelection);
      return;
    }

    String? promotion;
    final bool needsPromotion = legalMoves.any((dynamic move) {
      final Map<String, dynamic> mapped = move as Map<String, dynamic>;
      return mapped['to'] == to && (mapped['flags'] as String).contains('p');
    });

    if (needsPromotion) {
      promotion = await _showPromotionPicker();
      if (promotion == null) {
        return;
      }
    }

    final Map<String, dynamic> payload = <String, dynamic>{
      'from': from,
      'to': to,
    };
    if (promotion != null) {
      payload['promotion'] = promotion;
    }

    final bool moved = _game.move(payload) as bool;
    if (!moved) {
      return;
    }

    setState(() {
      _redoMoves.clear();
      _clearSelection();
    });
  }

  Future<String?> _showPromotionPicker() {
    return showDialog<String>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Promote to'),
          content: Wrap(
            spacing: 8,
            children: <Widget>[
              _promotionChoice('q', 'Queen'),
              _promotionChoice('r', 'Rook'),
              _promotionChoice('b', 'Bishop'),
              _promotionChoice('n', 'Knight'),
            ],
          ),
        );
      },
    );
  }

  Widget _promotionChoice(String code, String label) {
    return ElevatedButton(
      onPressed: () => Navigator.of(context).pop(code),
      child: Text(label),
    );
  }

  void _undo() {
    final dynamic undone = _game.undo();
    if (undone == null) {
      return;
    }

    setState(() {
      _redoMoves.add(Map<String, dynamic>.from(undone as Map));
      _clearSelection();
    });
  }

  void _redo() {
    if (_redoMoves.isEmpty) {
      return;
    }

    final Map<String, dynamic> move = _redoMoves.removeLast();
    final bool reapplied = _game.move(<String, dynamic>{
      'from': move['from'],
      'to': move['to'],
      if (move['promotion'] != null) 'promotion': move['promotion'],
    }) as bool;

    if (!reapplied) {
      return;
    }

    setState(_clearSelection);
  }

  List<String> _buildSanHistory() {
    final List<dynamic> moves = _game.getHistory(<String, dynamic>{
      'verbose': true,
    }) as List<dynamic>;

    return moves
        .map((dynamic move) => (move as Map<String, dynamic>)['san'] as String)
        .toList();
  }

  void _clearSelection() {
    _selectedSquare = null;
    _legalTargets = <String>{};
  }

  String _statusText() {
    if (_game.in_checkmate == true) {
      return 'Checkmate';
    }
    if (_game.in_draw == true) {
      return 'Draw';
    }
    if (_game.in_check == true) {
      return 'Check';
    }
    final String turn = _game.turn == chess.Color.WHITE ? 'White' : 'Black';
    return '$turn to move';
  }

  String _pieceSymbol(dynamic piece) {
    if (piece == null) {
      return '';
    }

    final bool isWhite = piece.color == chess.Color.WHITE;
    final String type = piece.type.toString();

    const Map<String, String> white = <String, String>{
      'k': '?',
      'q': '?',
      'r': '?',
      'b': '?',
      'n': '?',
      'p': '?',
    };
    const Map<String, String> black = <String, String>{
      'k': '?',
      'q': '?',
      'r': '?',
      'b': '?',
      'n': '?',
      'p': '?',
    };

    return isWhite ? white[type] ?? '' : black[type] ?? '';
  }
}
