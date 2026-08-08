/// Tile types for the SixKa6PeiSanma tile set (STEP5, docs/design/05).
///
/// Modeled as a sealed hierarchy rather than the standard 34-type index used
/// by four-player engines, because this ruleset's tiles genuinely differ in
/// kind: man only has two ranks, north is never a playable wind, and hana
/// tiles carry individual identities. Forcing them into a generic index would
/// hide invalid states (e.g. "2 man") that this hierarchy makes unrepresentable.
library;

/// Suits that carry a 1-9 rank. Man is restricted to {1, 9} by [NumberTile]'s
/// constructor — 2-8 man are not part of this ruleset (STEP5 §1).
enum NumberSuit { man, pin, sou }

/// The three playable winds. North is intentionally absent: it exists only
/// as [KitaTile], the nuki-dora / hand-held-yaku tile (STEP5 "北の扱い").
enum Wind { east, south, west }

enum Dragon { white, green, red }

/// The six hana (flower) tiles. The two physical Mighty tiles share this one
/// [HanaKind.mighty] value — they are interchangeable by rule (STEP5追補1).
enum HanaKind { spring, summer, autumn, winter, mighty }

/// Whether a specific physical 5p/5s copy is dyed as a bonus dora tile.
/// Only ever non-[none] on a [NumberTile] with `suit != man && number == 5`.
enum TileMark { none, red, blue }

sealed class Tile {
  const Tile();

  /// A short human-readable label, e.g. "1m", "5p(赤)", "北", "春".
  String get label;
}

class NumberTile extends Tile {
  final NumberSuit suit;
  final int number;
  final TileMark mark;

  NumberTile(this.suit, this.number, {this.mark = TileMark.none})
      : assert(number >= 1 && number <= 9, 'number must be 1-9'),
        assert(
          suit != NumberSuit.man || number == 1 || number == 9,
          'man suit only has 1m and 9m in this ruleset (STEP5 §1)',
        ),
        assert(
          mark == TileMark.none || number == 5,
          'only the 5-rank can be marked red/blue',
        ),
        assert(
          mark == TileMark.none || suit != NumberSuit.man,
          'man has no red/blue variant (5m does not exist)',
        );

  static const _suitLabel = {
    NumberSuit.man: 'm',
    NumberSuit.pin: 'p',
    NumberSuit.sou: 's',
  };

  @override
  String get label {
    final markSuffix = switch (mark) {
      TileMark.none => '',
      TileMark.red => '(赤)',
      TileMark.blue => '(青)',
    };
    return '$number${_suitLabel[suit]}$markSuffix';
  }

  @override
  bool operator ==(Object other) =>
      other is NumberTile &&
      other.suit == suit &&
      other.number == number &&
      other.mark == mark;

  @override
  int get hashCode => Object.hash(suit, number, mark);

  @override
  String toString() => 'NumberTile($label)';
}

class WindTile extends Tile {
  final Wind wind;

  const WindTile(this.wind);

  static const _label = {Wind.east: '東', Wind.south: '南', Wind.west: '西'};

  @override
  String get label => _label[wind]!;

  @override
  bool operator ==(Object other) => other is WindTile && other.wind == wind;

  @override
  int get hashCode => wind.hashCode;

  @override
  String toString() => 'WindTile($label)';
}

class DragonTile extends Tile {
  final Dragon dragon;

  /// True for the single marked copy of white dragon (STEP5 "白ポッチ").
  final bool isHakuPocchi;

  DragonTile(this.dragon, {this.isHakuPocchi = false})
      : assert(
          !isHakuPocchi || dragon == Dragon.white,
          '白ポッチ (haku-pocchi) only applies to the white dragon',
        );

  static const _label = {Dragon.white: '白', Dragon.green: '發', Dragon.red: '中'};

  @override
  String get label => isHakuPocchi ? '白•' : _label[dragon]!;

  @override
  bool operator ==(Object other) =>
      other is DragonTile &&
      other.dragon == dragon &&
      other.isHakuPocchi == isHakuPocchi;

  @override
  int get hashCode => Object.hash(dragon, isHakuPocchi);

  @override
  String toString() => 'DragonTile($label)';
}

/// North: never a playable wind in this ruleset, only the nuki-dora /
/// kokushi-musou-eligible tile (STEP5 "北の扱い改定").
class KitaTile extends Tile {
  const KitaTile();

  @override
  String get label => '北';

  @override
  bool operator ==(Object other) => other is KitaTile;

  @override
  int get hashCode => (KitaTile).hashCode;

  @override
  String toString() => 'KitaTile()';
}

class HanaTile extends Tile {
  final HanaKind kind;

  const HanaTile(this.kind);

  static const _label = {
    HanaKind.spring: '春',
    HanaKind.summer: '夏',
    HanaKind.autumn: '秋',
    HanaKind.winter: '冬',
    HanaKind.mighty: 'マイティ',
  };

  @override
  String get label => _label[kind]!;

  @override
  bool operator ==(Object other) => other is HanaTile && other.kind == kind;

  @override
  int get hashCode => kind.hashCode;

  @override
  String toString() => 'HanaTile($label)';
}

/// Groups tiles by everything except cosmetic markers (red/blue dora color,
/// haku-pocchi). Two tiles with the same [tileKind] are interchangeable for
/// forming a pair/kotsu/kantsu — e.g. a plain 5p and a red 5p are "the same
/// tile" for meld-building even though [Tile.==] treats them as distinct
/// (STEP5: marks are cosmetic/scoring properties, not a different tile type).
extension TileKind on Tile {
  Object get tileKind => switch (this) {
        NumberTile t => (t.suit, t.number),
        WindTile t => t.wind,
        DragonTile t => t.dragon,
        KitaTile _ => KitaTile,
        HanaTile t => t.kind,
      };
}
