import 'package:mahjong_engine/mahjong_engine.dart';
import 'package:test/test.dart';

NumberTile pin(int n, {TileMark mark = TileMark.none}) =>
    NumberTile(NumberSuit.pin, n, mark: mark);

void main() {
  group('Meld.shuntsu', () {
    test('accepts three consecutive tiles in one suit', () {
      final meld = Meld.shuntsu([pin(3), pin(4), pin(5)]);
      expect(meld.kind, MeldKind.shuntsu);
    });

    test('accepts the tiles in any order', () {
      final meld = Meld.shuntsu([pin(5), pin(3), pin(4)]);
      expect(meld.kind, MeldKind.shuntsu);
    });

    test('rejects man (only 1m/9m exist, never consecutive)', () {
      expect(
        () => Meld.shuntsu([
          NumberTile(NumberSuit.man, 1),
          NumberTile(NumberSuit.man, 1),
          NumberTile(NumberSuit.man, 1),
        ]),
        throwsArgumentError,
      );
    });

    test('rejects non-consecutive numbers', () {
      expect(() => Meld.shuntsu([pin(3), pin(4), pin(6)]), throwsArgumentError);
    });

    test('rejects mixed suits', () {
      expect(
        () => Meld.shuntsu([pin(3), pin(4), NumberTile(NumberSuit.sou, 5)]),
        throwsArgumentError,
      );
    });

    test('rejects a wrong tile count', () {
      expect(() => Meld.shuntsu([pin(3), pin(4)]), throwsArgumentError);
    });
  });

  group('Meld.kotsu', () {
    test('accepts three tiles of the same kind regardless of mark', () {
      final meld = Meld.kotsu([pin(5, mark: TileMark.red), pin(5), pin(5)]);
      expect(meld.kind, MeldKind.kotsu);
    });

    test('accepts three winds', () {
      final meld = Meld.kotsu([
        const WindTile(Wind.east),
        const WindTile(Wind.east),
        const WindTile(Wind.east),
      ]);
      expect(meld.kind, MeldKind.kotsu);
    });

    test('rejects mismatched kinds', () {
      expect(() => Meld.kotsu([pin(5), pin(5), pin(6)]), throwsArgumentError);
    });
  });

  group('Meld.kantsu', () {
    test('accepts four tiles of the same kind', () {
      final meld = Meld.kantsu([pin(5), pin(5), pin(5), pin(5)]);
      expect(meld.kind, MeldKind.kantsu);
    });

    test('rejects a chi source (kan cannot come from chi)', () {
      expect(
        () => Meld.kantsu(
          [pin(5), pin(5), pin(5), pin(5)],
          source: CallSource.chi,
        ),
        throwsArgumentError,
      );
    });
  });

  group('Meld.pair', () {
    test('accepts two tiles of the same kind', () {
      final meld = Meld.pair([pin(5), pin(5, mark: TileMark.red)]);
      expect(meld.kind, MeldKind.pair);
    });

    test('rejects a wrong tile count', () {
      expect(() => Meld.pair([pin(5)]), throwsArgumentError);
    });
  });

  group('Meld.isOpen', () {
    test('chi and pon are open', () {
      expect(Meld.shuntsu([pin(3), pin(4), pin(5)], source: CallSource.chi).isOpen, isTrue);
      expect(Meld.kotsu([pin(5), pin(5), pin(5)], source: CallSource.pon).isOpen, isTrue);
    });

    test('daiminkan and shouminkan are open', () {
      for (final source in [CallSource.daiminkan, CallSource.shouminkan]) {
        final meld = Meld.kantsu([pin(5), pin(5), pin(5), pin(5)], source: source);
        expect(meld.isOpen, isTrue, reason: '$source should be open');
      }
    });

    test('concealed and ankan are not open', () {
      expect(Meld.kotsu([pin(5), pin(5), pin(5)]).isOpen, isFalse);
      expect(
        Meld.kantsu([pin(5), pin(5), pin(5), pin(5)], source: CallSource.ankan).isOpen,
        isFalse,
      );
    });
  });
}
