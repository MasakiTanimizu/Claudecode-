/// Pure-Dart mahjong rules engine shared by the Flutter client and the
/// Serverpod server (STEP1/STEP2, docs/design). No Flutter or Serverpod
/// dependency here — see docs/design/01-tech-stack.md for why.
library;

export 'src/core/hand.dart';
export 'src/core/meld.dart';
export 'src/core/tile.dart';
export 'src/core/tile_set.dart';
export 'src/core/wall.dart';
export 'src/engine/shanten.dart';
