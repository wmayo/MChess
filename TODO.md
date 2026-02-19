# MChess TODO

## Phase 0 - Project Setup
- [x] Initialize Flutter project in repository.
- [x] Define Phase 1 execution tracker in `TODO.md`.
- [x] Add chess logic dependency (`chess`).
- [x] Add temporary navigation drawer with Home and Import Game.
- [ ] Add state management package (evaluate `riverpod` vs `bloc`).
- [ ] Add routing skeleton for auth/lobby/game/profile.

## Phase 1.1 - Board and Piece Movement
- [x] Replace starter counter app with chess app shell.
- [x] Build 8x8 board UI with chess.com-like color palette.
- [x] Render all pieces from game state.
- [x] Implement drag-and-drop move interaction.
- [x] Implement tap-to-select and tap-to-move interaction.
- [x] Highlight selected square and legal target squares.
- [x] Validate moves via chess logic library before commit.
- [x] Support special moves through engine rules (castling, en passant, promotion).
- [x] Add promotion piece picker.
- [x] Add undo for local game.
- [x] Add redo for local game.
- [x] Show move history in SAN algebraic notation.
- [x] Replace text/unicode piece rendering with SVG assets via `flutter_svg`.
- [ ] Add captured pieces panel.
- [ ] Add board orientation toggle.
- [ ] Add analysis arrows/circles drawing layer.
- [x] Add import flow that accepts PGN text or game URL (PGN fetch).

## Phase 1.2 - Game Modes
- [ ] Define game mode domain model (`local`, `ai`, `online`).
- [ ] Add pre-game modal for mode and time-control selection.
- [ ] Implement local pass-and-play mode plumbing.
- [ ] Integrate Stockfish for AI mode.
- [ ] Add AI difficulty mapping to engine depth/skill.
- [ ] Add game clock model and pause/resume lifecycle hooks.
- [ ] Implement presets: bullet, blitz, rapid, classical.
- [ ] Implement custom time control form.
- [ ] Define online real-time architecture (transport, events, reconnect).
- [ ] Add multiplayer sync client abstraction.

## Phase 1.3 - User System
- [ ] Define auth provider abstraction.
- [ ] Implement email/password registration and login UI.
- [ ] Add social login providers (Google, Apple).
- [ ] Add session persistence and logout flow.
- [ ] Create player profile screen.
- [ ] Track and display basic stats (games, win/loss/draw, streak).
- [ ] Implement ELO calculation service.
- [ ] Persist rating history for charting.
- [ ] Create friends list data model.
- [ ] Implement add/remove/search friends workflow.

## Phase 1.4 - Stockfish Analysis (In-Game/Post-Game)
- [ ] Select Stockfish integration package and platform setup.
- [ ] Implement engine process lifecycle manager.
- [ ] Implement UCI command adapter.
- [ ] Add in-game quick evaluation bar updates.
- [ ] Add post-game full analysis pipeline.
- [ ] Classify mistakes/blunders/inaccuracies based on eval swings.
- [ ] Annotate move list with engine insights.
- [ ] Add "best move" and principal variation display.

## Validation and Quality
- [x] Add initial widget smoke test for app shell.
- [x] Run `flutter analyze` for baseline correctness.
- [ ] Add unit tests for move application, undo/redo, and promotion.
- [ ] Add widget tests for board interaction and highlights.
- [ ] Add integration smoke test for complete local game flow.
- [ ] Add CI workflow for analyze, test, and formatting.
