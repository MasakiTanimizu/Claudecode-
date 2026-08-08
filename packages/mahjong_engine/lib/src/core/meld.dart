import 'tile.dart';

enum MeldKind { shuntsu, kotsu, kantsu, pair }

/// How a meld came to exist. [concealed] covers both "still in hand" groups
/// (used only for pair/kotsu bookkeeping before a hand is finalized) and
/// ankan; the rest are calls off a discard. There is no `chi` — this
/// ruleset doesn't use it (docs/design/05「鳴き・後付け」), so every
/// [MeldKind.shuntsu] is necessarily concealed.
enum CallSource { concealed, pon, daiminkan, shouminkan, ankan }

/// A validated group of tiles: 順子/刻子/槓子/対子.
///
/// Construction goes through the named factories below rather than a public
/// generative constructor, because each [MeldKind] has a different validity
/// rule and "a Meld that happens to hold garbage tiles" should not be
/// representable at all.
class Meld {
  final MeldKind kind;
  final List<Tile> tiles;
  final CallSource source;

  const Meld._(this.kind, this.tiles, this.source);

  /// 順子: three consecutive numbers in one suit. Man is excluded on purpose
  /// — this ruleset only has 1m/9m, so a man shuntsu can never exist
  /// (docs/design/05 §1, "順子は成立しない").
  factory Meld.shuntsu(List<NumberTile> tiles, {CallSource source = CallSource.concealed}) {
    if (tiles.length != 3) {
      throw ArgumentError('shuntsu needs exactly 3 tiles, got ${tiles.length}');
    }
    final suit = tiles.first.suit;
    if (suit == NumberSuit.man) {
      throw ArgumentError('man has no shuntsu in this ruleset (only 1m/9m exist)');
    }
    if (tiles.any((t) => t.suit != suit)) {
      throw ArgumentError('shuntsu tiles must share one suit');
    }
    final numbers = tiles.map((t) => t.number).toList()..sort();
    if (numbers[0] + 1 != numbers[1] || numbers[1] + 1 != numbers[2]) {
      throw ArgumentError('shuntsu numbers must be consecutive, got $numbers');
    }
    return Meld._(MeldKind.shuntsu, List.unmodifiable(tiles), source);
  }

  /// 刻子: three tiles of the same [TileKind.tileKind] (marks may differ).
  factory Meld.kotsu(List<Tile> tiles, {CallSource source = CallSource.concealed}) {
    return Meld._(MeldKind.kotsu, _sameKind(tiles, 3), source);
  }

  /// 槓子: four tiles of the same [TileKind.tileKind].
  factory Meld.kantsu(List<Tile> tiles, {CallSource source = CallSource.concealed}) {
    return Meld._(MeldKind.kantsu, _sameKind(tiles, 4), source);
  }

  /// 対子: two tiles of the same [TileKind.tileKind]. Used both as a hand's
  /// pair and as one of chiitoitsu's seven pairs.
  factory Meld.pair(List<Tile> tiles) {
    return Meld._(MeldKind.pair, _sameKind(tiles, 2), CallSource.concealed);
  }

  static List<Tile> _sameKind(List<Tile> tiles, int expectedCount) {
    if (tiles.length != expectedCount) {
      throw ArgumentError('expected $expectedCount tiles, got ${tiles.length}');
    }
    final kind = tiles.first.tileKind;
    if (tiles.any((t) => t.tileKind != kind)) {
      throw ArgumentError('all tiles in this meld must be the same kind, got $tiles');
    }
    return List.unmodifiable(tiles);
  }

  /// Whether this meld is visible to other players (pon/daiminkan and the
  /// exposed shouminkan). Ankan is concealed for yaku purposes even though
  /// its tiles are shown face-up on the table.
  bool get isOpen =>
      source == CallSource.pon ||
      source == CallSource.daiminkan ||
      source == CallSource.shouminkan;

  @override
  String toString() => '$kind(${tiles.map((t) => t.label).join()}, $source)';
}
