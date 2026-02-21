import 'package:chess/chess.dart' as chess;
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:http/http.dart' as http;

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
  chess.Chess _game = chess.Chess();
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
      drawer: _buildDrawer(),
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

  Widget _buildDrawer() {
    return Drawer(
      child: SafeArea(
        child: Column(
          children: <Widget>[
            const DrawerHeader(
              margin: EdgeInsets.only(bottom: 8),
              child: Align(
                alignment: Alignment.bottomLeft,
                child: Text(
                  'MChess',
                  style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
                ),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.home_outlined),
              title: const Text('Home'),
              onTap: () {
                Navigator.of(context).pop();
              },
            ),
            ListTile(
              leading: const Icon(Icons.upload_file_outlined),
              title: const Text('Import Game'),
              onTap: () {
                Navigator.of(context).pop();
                _openImportDialog();
              },
            ),
          ],
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

    final Widget pieceWidget = piece == null
        ? const SizedBox.shrink()
        : Center(
            child: SvgPicture.asset(
              _pieceAsset(piece),
              width: 42,
              height: 42,
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

  Future<void> _openImportDialog() async {
    final TextEditingController linkController = TextEditingController();
    final TextEditingController pgnController = TextEditingController();

      await showDialog<void>(
        context: context,
        builder: (BuildContext dialogContext) {
          return AlertDialog(
            title: const Text('Import Game'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  const Text('Paste a game link'),
                  const SizedBox(height: 8),
                  TextField(
                    controller: linkController,
                    minLines: 1,
                    maxLines: 2,
                    decoration: const InputDecoration(
                      hintText: 'https://lichess.org/... or direct .pgn URL',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 14),
                  const Text('Or paste PGN'),
                  const SizedBox(height: 8),
                  TextField(
                    controller: pgnController,
                    minLines: 6,
                    maxLines: 10,
                    decoration: const InputDecoration(
                      hintText: '[Event "..."]\n1. e4 e5 2. Nf3 ...',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ],
              ),
            ),
            actions: <Widget>[
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () async {
                  // final NavigatorState dialogNavigator = dialogContext.findAncestorStateOfType<NavigatorState>()!;
                  final String rawPgn = pgnController.text.trim();
                  final String rawLink = linkController.text.trim();
                  if (rawPgn.isEmpty && rawLink.isEmpty) {
                    _showMessage('Add a PGN or a game link first.');
                    return;
                  }

                  Navigator.of(dialogContext).pop();

                  String pgnText = rawPgn;
                  if (pgnText.isEmpty) {
                    try {
                      pgnText = await _fetchPgnFromLink(rawLink);
                    } catch (error) {
                      _showMessage('Could not fetch PGN from link: $error');
                      return;
                    }
                  }

                  final bool imported = _importPgnIntoBoard(pgnText);
                  if (!imported) {
                    _showMessage('Invalid PGN. Please check and try again.');
                    return;
                  }

                  if (!mounted) {
                    return;
                  }
                  // dialogNavigator.pop();
                  _showMessage('Game imported successfully.');
                },
                child: const Text('Import'),
              ),
            ],
          );
        },
      );
  }

  Future<String> _fetchPgnFromLink(String rawLink) async {
    final Uri? uri = _normalizePgnUri(rawLink);
    if (uri == null) {
      throw 'Invalid URL format.';
    }

    final http.Response response = await http
        .get(uri, headers: <String, String>{'Accept': 'application/x-chess-pgn'})
        .timeout(const Duration(seconds: 12));
    if (response.statusCode != 200) {
      throw 'HTTP ${response.statusCode}';
    }

    final String body = response.body.trim();
    if (body.isEmpty) {
      throw 'Empty response.';
    }
    return body;
  }

  Uri? _normalizePgnUri(String rawLink) {
    final Uri? original = Uri.tryParse(rawLink.trim());
    if (original == null || !original.hasScheme || !original.hasAuthority) {
      return null;
    }

    final bool isLichess =
        original.host == 'lichess.org' || original.host.endsWith('.lichess.org');
    if (!isLichess) {
      return original;
    }

    if (original.path.endsWith('.pgn')) {
      return original;
    }

    return original.replace(path: '${original.path}.pgn');
  }

  bool _importPgnIntoBoard(String pgnText) {
    final chess.Chess importedGame = chess.Chess();
    final bool loaded = importedGame.load_pgn(pgnText);
    if (!loaded) {
      return false;
    }

    setState(() {
      _game = importedGame;
      _redoMoves.clear();
      _clearSelection();
    });
    return true;
  }

  void _showMessage(String message) {
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
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
    });

    return moves
        .map((dynamic move) => (move as Map<String, dynamic>)['to'] as String)
        .toSet();
  }

  Future<void> _attemptMove(String from, String to) async {
    final List<dynamic> legalMoves = _game.moves(<String, dynamic>{
      'square': from,
      'verbose': true,
    });

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

    final bool moved = _game.move(payload);
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
    });

    if (!reapplied) {
      return;
    }

    setState(_clearSelection);
  }

  List<String> _buildSanHistory() {
    final List<dynamic> moves = _game.getHistory(<String, dynamic>{
      'verbose': true,
    });

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

  String _pieceAsset(dynamic piece) {
    if (piece == null) {
      return '';
    }

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
