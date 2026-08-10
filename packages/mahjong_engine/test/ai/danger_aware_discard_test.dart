import 'package:mahjong_engine/mahjong_engine.dart';
import 'package:test/test.dart';

NumberTile man(int n) => NumberTile(NumberSuit.man, n);
NumberTile pin(int n) => NumberTile(NumberSuit.pin, n);
NumberTile sou(int n) => NumberTile(NumberSuit.sou, n);

List<Tile> run(NumberTile Function(int) suit, int start) =>
    [suit(start), suit(start + 1), suit(start + 2)];

Hand _testHand() => Hand(concealedTiles: [
      ...run(pin, 1),
      ...run(pin, 4),
      ...run(pin, 7),
      DragonTile(Dragon.white),
      DragonTile(Dragon.white),
      sou(4),
      sou(5),
      man(1), // pure tile-efficiency picks this one (see heuristic_discard_test.dart).
    ]);

void main() {
  group('chooseDiscardAgainstRiichi', () {
    test('prefers a genbutsu tile over the pure-efficiency pick', () {
      final hand = _testHand();
      // sou(5) is the only tile in hand matching this discard — it's the
      // unique safe candidate, even though man(1) is the efficient one.
      final discarded = chooseDiscardAgainstRiichi(hand, riichiOpponentDiscards: [sou(5)]);
      expect(discarded, sou(5));
      expect(discarded, isNot(chooseDiscard(hand)));
    });

    test('falls back to pure tile efficiency when nothing in hand is safe', () {
      final hand = _testHand();
      final discarded = chooseDiscardAgainstRiichi(
        hand,
        riichiOpponentDiscards: [const WindTile(Wind.east)],
      );
      expect(discarded, chooseDiscard(hand));
    });

    test('falls back to pure tile efficiency when no one is in riichi', () {
      final hand = _testHand();
      final discarded = chooseDiscardAgainstRiichi(hand, riichiOpponentDiscards: const []);
      expect(discarded, chooseDiscard(hand));
    });
  });
}
