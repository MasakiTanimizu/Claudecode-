import 'package:mahjong_engine/mahjong_engine.dart';
import 'package:test/test.dart';

NumberTile man(int n) => NumberTile(NumberSuit.man, n);
NumberTile pin(int n) => NumberTile(NumberSuit.pin, n);
NumberTile sou(int n) => NumberTile(NumberSuit.sou, n);
DragonTile white() => DragonTile(Dragon.white);
DragonTile green() => DragonTile(Dragon.green);
DragonTile red() => DragonTile(Dragon.red);
const east = WindTile(Wind.east);
const south = WindTile(Wind.south);
const west = WindTile(Wind.west);

List<Tile> triple(Tile tile) => [tile, tile, tile];
List<Tile> pair(Tile tile) => [tile, tile];

void main() {
  group('detectStandardYaku', () {
    test('tanyao: four simple sequences + a simple pair', () {
      final hand = Hand(concealedTiles: [
        pin(2), pin(3), pin(4),
        pin(5), pin(6), pin(7),
        sou(2), sou(3), sou(4),
        sou(5), sou(6), sou(7),
        sou(8), sou(8),
      ]);
      expect(detectStandardYaku(hand), contains(StandardYaku.tanyao));
    });

    test('open pon + 3 concealed triplets: toitoi + sanankou + yakuhai', () {
      final hand = Hand(
        concealedTiles: [
          ...triple(pin(3)),
          ...triple(pin(5)),
          ...triple(sou(7)),
          ...pair(pin(6)),
        ],
        melds: [Meld.kotsu(triple(white()), source: CallSource.pon)],
      );
      final yaku = detectStandardYaku(hand);
      expect(yaku, containsAll([StandardYaku.toitoi, StandardYaku.sanankou, StandardYaku.yakuhaiWhite]));
      expect(yaku, isNot(contains(StandardYaku.honroutou)));
    });

    test('mixed terminal/honor toitoi: honroutou + toitoi + sanankou', () {
      final hand = Hand(
        concealedTiles: [
          ...triple(pin(1)),
          ...triple(sou(9)),
          ...triple(pin(9)),
          ...pair(green()),
        ],
        melds: [Meld.kotsu(triple(east), source: CallSource.pon)],
      );
      final yaku = detectStandardYaku(hand);
      expect(
        yaku,
        containsAll([StandardYaku.honroutou, StandardYaku.toitoi, StandardYaku.sanankou]),
      );
      expect(yaku, isNot(contains(StandardYaku.tanyao)));
    });

    test('shousangen: 2 dragon triplets + dragon pair', () {
      final hand = Hand(concealedTiles: [
        ...triple(white()),
        ...triple(green()),
        ...pair(red()),
        pin(4), pin(5), pin(6),
        sou(2), sou(3), sou(4),
      ]);
      final yaku = detectStandardYaku(hand);
      expect(
        yaku,
        containsAll([StandardYaku.shousangen, StandardYaku.yakuhaiWhite, StandardYaku.yakuhaiGreen]),
      );
    });

    test('junchan: all-terminal groups, no honors, includes a sequence', () {
      final hand = Hand(concealedTiles: [
        pin(1), pin(2), pin(3),
        sou(7), sou(8), sou(9),
        pin(7), pin(8), pin(9),
        ...triple(sou(1)),
        ...pair(pin(9)),
      ]);
      final yaku = detectStandardYaku(hand);
      expect(yaku, contains(StandardYaku.junchan));
      expect(yaku, isNot(contains(StandardYaku.chanta)));
      expect(yaku, isNot(contains(StandardYaku.chinroutou)));
    });

    test('chanta: terminal-or-honor groups, honor triplet present', () {
      final hand = Hand(concealedTiles: [
        pin(1), pin(2), pin(3),
        sou(7), sou(8), sou(9),
        pin(7), pin(8), pin(9),
        ...triple(east),
        ...pair(pin(9)),
      ]);
      final yaku = detectStandardYaku(hand);
      expect(yaku, contains(StandardYaku.chanta));
      expect(yaku, isNot(contains(StandardYaku.junchan)));
    });

    test('ittsuu: 1-9 run in one suit (pin/sou only)', () {
      final hand = Hand(concealedTiles: [
        pin(1), pin(2), pin(3),
        pin(4), pin(5), pin(6),
        pin(7), pin(8), pin(9),
        ...triple(sou(5)),
        ...pair(sou(2)),
      ]);
      expect(detectStandardYaku(hand), contains(StandardYaku.ittsuu));
    });

    test('chinitsu: single suit, no honors', () {
      final hand = Hand(concealedTiles: [
        pin(1), pin(2), pin(3),
        pin(4), pin(5), pin(6),
        pin(7), pin(8), pin(9),
        ...triple(pin(5)),
        ...pair(pin(2)),
      ]);
      final yaku = detectStandardYaku(hand);
      expect(yaku, contains(StandardYaku.chinitsu));
      expect(yaku, isNot(contains(StandardYaku.honitsu)));
    });

    test('honitsu: single suit + honor groups', () {
      final hand = Hand(concealedTiles: [
        pin(1), pin(2), pin(3),
        pin(4), pin(5), pin(6),
        pin(7), pin(8), pin(9),
        ...triple(east),
        ...pair(pin(2)),
      ]);
      final yaku = detectStandardYaku(hand);
      expect(yaku, contains(StandardYaku.honitsu));
      expect(yaku, isNot(contains(StandardYaku.chinitsu)));
    });

    test('daisangen: three dragon triplets (yakuman-only result)', () {
      final hand = Hand(concealedTiles: [
        ...triple(white()),
        ...triple(green()),
        ...triple(red()),
        pin(3), pin(4), pin(5),
        ...pair(pin(2)),
      ]);
      expect(detectStandardYaku(hand), [StandardYaku.daisangen]);
    });

    test('four concealed terminal/simple-mixed triplets: suuankou only', () {
      final hand = Hand(concealedTiles: [
        ...triple(pin(1)),
        ...triple(pin(3)),
        ...triple(pin(5)),
        ...triple(pin(7)),
        ...pair(green()),
      ]);
      expect(detectStandardYaku(hand), [StandardYaku.suuankou]);
    });

    test('chinroutou co-occurring with suuankou (all-terminal concealed triplets)', () {
      final hand = Hand(concealedTiles: [
        ...triple(pin(1)),
        ...triple(pin(9)),
        ...triple(sou(1)),
        ...triple(sou(9)),
        ...pair(man(1)),
      ]);
      expect(detectStandardYaku(hand).toSet(), {StandardYaku.suuankou, StandardYaku.chinroutou});
    });

    test('tsuiisou co-occurring with suuankou (all-honor concealed triplets)', () {
      final hand = Hand(concealedTiles: [
        ...triple(east),
        ...triple(south),
        ...triple(west),
        ...triple(white()),
        ...pair(green()),
      ]);
      expect(detectStandardYaku(hand).toSet(), {StandardYaku.suuankou, StandardYaku.tsuiisou});
    });

    test('suukantsu co-occurring with suuankou (four ankan)', () {
      final hand = Hand(
        concealedTiles: [...pair(white())],
        melds: [
          Meld.kantsu(List.generate(4, (_) => pin(1)), source: CallSource.ankan),
          Meld.kantsu(List.generate(4, (_) => pin(9)), source: CallSource.ankan),
          Meld.kantsu(List.generate(4, (_) => sou(1)), source: CallSource.ankan),
          Meld.kantsu(List.generate(4, (_) => sou(9)), source: CallSource.ankan),
        ],
      );
      expect(detectStandardYaku(hand).toSet(), {StandardYaku.suukantsu, StandardYaku.suuankou});
    });

    test('empty for a hand that is not actually complete', () {
      final hand = Hand(concealedTiles: [
        pin(1), pin(2), pin(3),
        pin(4), pin(5), pin(6),
        pin(7), pin(8), pin(9),
        ...pair(white()),
        sou(4), sou(5),
      ]);
      expect(decomposeStandardHand(hand), isEmpty);
      expect(detectStandardYaku(hand), isEmpty);
    });

    test('a declared 北 ankan never yields a standard decomposition', () {
      final hand = Hand(
        concealedTiles: [
          pin(1), pin(2), pin(3),
          pin(4), pin(5), pin(6),
          pin(7), pin(8), pin(9),
          ...pair(pin(2)),
        ],
        melds: [Meld.kantsu(List.generate(4, (_) => const KitaTile()), source: CallSource.ankan)],
      );
      expect(decomposeStandardHand(hand), isEmpty);
    });
  });
}
