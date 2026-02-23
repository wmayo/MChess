# MChess

## Stockfish Setup (Android/iOS)

This project uses `stockfish: ^1.8.1` through a mobile-only engine wrapper.

- Supported runtime platforms: Android, iOS
- Unsupported (web/desktop): guarded by a stub implementation
- iOS deployment target must be `12.0` or higher

### Android prerequisites

- Android `minSdk` must be at least 21 (Flutter default satisfies this).
- First native build downloads Stockfish NNUE network files.
- Network access is required during the first Android build.

Build command:

```bash
flutter build apk --debug
```

### iOS prerequisites

- Build on macOS with Xcode + CocoaPods installed.
- Ensure `platform :ios, '12.0'` in `ios/Podfile`.
- If `ios/Podfile` is missing in a fresh checkout, generate iOS pod setup by
  running a first iOS build on macOS.
- The Stockfish plugin downloads NNUE files during native build.

Build command:

```bash
flutter build ios --simulator
```

## Stockfish UCI Smoke Test

Smoke test file:

- `integration_test/stockfish_uci_smoke_test.dart`

Behavior:

- Creates `Stockfish()`
- Waits for engine ready state
- Sends `uci`
- Asserts `uciok` appears on stdout within timeout
- Disposes immediately after handshake
- Repeats once to verify singleton release on dispose

Run commands:

```bash
# Android
flutter test integration_test/stockfish_uci_smoke_test.dart -d <android-device-id>

# iOS
flutter test integration_test/stockfish_uci_smoke_test.dart -d <ios-device-id>
```

## Analysis Features

Implemented analysis features:

- Analyse trigger appears after game over and after any successful PGN import.
- Post-game/import analysis page runs full-ply evaluation pipeline with progress.
- Progressive analysis updates: reviewed moves become available as each ply completes.
- Move annotations: best/excellent/good/inaccuracy/mistake/blunder.
- Best move + PV display and board arrow overlay.
- Selected-move review panel shows played move, best move, cp loss, class, and PV.
- Analysis summary header shows result, move counts, class counts, and rough accuracy.
- Navigation controls: start, previous, next, end, next mistake, previous mistake, and move-list jump.
- `Show` button autoplay for the principal variation.
- Completed analysis results are cached in-session for faster re-open of the same game.
- In-game quick eval bar (live mode), with busy/paused indicators and mate display.
- Quick eval is suspended while full analysis is active and paused on app background.
