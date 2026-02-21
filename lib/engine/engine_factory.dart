import 'uci_engine.dart';
import 'stockfish_engine_stub.dart'
    if (dart.library.io) 'stockfish_engine_mobile.dart' as stockfish_impl;

UciEngine createUciEngine() => stockfish_impl.createUciEngine();
