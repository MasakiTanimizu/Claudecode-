import { describe, it, expect } from 'vitest';
import { createRuleConfig } from '../rules/RuleConfig.js';
import { createPlayerState } from '../state/PlayerState.js';
import { createRoundState } from '../state/RoundState.js';
import { createScoreState, createChipState } from '../state/ScoreState.js';
import { createFlowerState } from '../state/FlowerState.js';
import { createWhitePotchiState } from '../state/WhitePotchiState.js';
import { createShubaState } from '../state/ShubaState.js';
import {
  drawForTurn,
  discardTile,
  declareKita,
  declareFlowerDraw,
  declareRiichi,
  declarePon,
  declareDaiminkan,
  declareAnkan,
  declareShouminkan,
  checkTsumoWin,
  checkRonWin,
  resolveWin,
  resolveExhaustiveDraw,
  canDeclareChi,
  refreshFuriten,
} from '../engine/TurnEngine.js';

const rules = createRuleConfig();

function t(suit, rank, variant = null) {
  return { id: `${suit}${rank}-${Math.random()}`, suit, rank, variant };
}

function makeGame({ liveWall = [] } = {}) {
  const ruleConfig = createRuleConfig();
  const players = [0, 1, 2].map((seat) => createPlayerState(seat, { isDealer: seat === 0 }));
  const round = createRoundState({ dealerSeat: 0 });
  round.doraIndicators = [t('z', 6)];
  round.uraDoraIndicators = [t('z', 6)];
  return {
    ruleConfig,
    players,
    round,
    score: createScoreState(3, ruleConfig),
    chip: createChipState(3),
    wall: {
      liveWall,
      deadWall: { doraIndicators: [], uraDoraIndicators: [], replacementPool: [t('p', 9)] },
    },
    flower: createFlowerState(3),
    whitePotchi: createWhitePotchiState(3),
    shubariichi: createShubaState(3),
  };
}

// Tanyao tsumo hand: 234p 456p 678s 345s 22p pair.
function tanyaoTiles() {
  return [
    t('p', 2), t('p', 3), t('p', 4),
    t('p', 4), t('p', 5), t('p', 6),
    t('s', 6), t('s', 7), t('s', 8),
    t('s', 3), t('s', 4), t('s', 5),
    t('p', 2), t('p', 2),
  ];
}

describe('TurnEngine', () => {
  it('detects and resolves a menzen tsumo win, paying the winner from both opponents', () => {
    const game = makeGame();
    game.players[1].hand = tanyaoTiles();

    const win = checkTsumoWin(game, 1);
    expect(win.canWin).toBe(true);
    expect(win.yakuResult.yakuList.map((y) => y.name)).toEqual(expect.arrayContaining(['タンヤオ', '門前自摸']));

    const before = [...game.score];
    resolveWin(game, win);
    expect(game.score[1]).toBeGreaterThan(before[1]);
    expect(game.score[0]).toBeLessThan(before[0]);
    expect(game.score[2]).toBeLessThan(before[2]);
  });

  it('detects and resolves a ron win, paying only the discarder', () => {
    const game = makeGame();
    const hand13 = tanyaoTiles().slice(0, 13);
    game.players[1].hand = hand13;
    const winTile = tanyaoTiles()[13];

    const win = checkRonWin(game, 1, 2, winTile);
    expect(win.canWin).toBe(true);

    const before = [...game.score];
    resolveWin(game, win);
    expect(game.score[1]).toBeGreaterThan(before[1]);
    expect(game.score[2]).toBeLessThan(before[2]);
    expect(game.score[0]).toBe(before[0]);
  });

  it('marks a player furiten when a winning tile is in their own discards, blocking ron', () => {
    const game = makeGame();
    const hand13 = tanyaoTiles().slice(0, 13);
    game.players[1].hand = hand13;
    game.players[1].discards.push(tanyaoTiles()[13]);
    refreshFuriten(game, 1);

    expect(game.players[1].furiten).toBe(true);
    const win = checkRonWin(game, 1, 2, tanyaoTiles()[13]);
    expect(win.canWin).toBe(false);
    expect(win.reason).toBe('furiten');
  });

  it('extracts a north tile into kitaTiles and draws a replacement', () => {
    const game = makeGame({ liveWall: [t('s', 1)] });
    const north = t('z', 4);
    game.players[0].hand = [north];

    const { extracted, replacement } = declareKita(game, 0, north.id);
    expect(extracted.suit).toBe('z');
    expect(extracted.rank).toBe(4);
    expect(game.players[0].kitaTiles.length).toBe(1);
    expect(replacement).toBeTruthy();
    expect(game.players[0].hand).toContain(replacement);
  });

  it('draws from the live wall on a normal turn', () => {
    const tile = t('p', 1);
    const game = makeGame({ liveWall: [tile] });
    const drawn = drawForTurn(game, 2);
    expect(drawn).toBe(tile);
    expect(game.players[2].hand).toContain(tile);
    expect(game.wall.liveWall.length).toBe(0);
  });

  it('discards a tile out of a players hand', () => {
    const tile = t('p', 1);
    const game = makeGame();
    game.players[0].hand = [tile];
    const discarded = discardTile(game, 0, tile.id);
    expect(discarded).toBe(tile);
    expect(game.players[0].hand.length).toBe(0);
    expect(game.players[0].discards).toContain(tile);
  });

  it('pays noten players into tenpai players at an exhaustive draw', () => {
    const game = makeGame();
    // seat 0 tenpai (needs one p2/p5/p8 to complete a simple pinfu-ish shape... use a clean 13-tile tenpai hand)
    game.players[0].hand = tanyaoTiles().slice(0, 13);
    game.players[1].hand = [t('z', 1), t('z', 2), t('z', 3), t('m', 1), t('m', 9), t('p', 1), t('s', 1)];
    game.players[2].hand = [t('z', 1), t('z', 2), t('z', 3), t('m', 1), t('m', 9), t('p', 1), t('s', 1)];

    const before = [...game.score];
    const { tenpaiFlags } = resolveExhaustiveDraw(game);
    expect(tenpaiFlags[0]).toBe(true);
    expect(game.score[0]).toBeGreaterThan(before[0]);
    expect(game.score[1]).toBeLessThan(before[1]);
  });

  it('never allows chi — it is removed from this ruleset (RULE_CHI_ENABLED: false)', () => {
    expect(canDeclareChi(rules, { suit: 'p', rank: 4 })).toBe(false);
    expect(canDeclareChi(rules, { suit: 'm', rank: 1 })).toBe(false);
  });

  it('would still exclude man/honor/flower even if chi were re-enabled for a variant ruleset', () => {
    const chiEnabled = createRuleConfig({ RULE_CHI_ENABLED: true });
    expect(canDeclareChi(chiEnabled, { suit: 'p', rank: 4 })).toBe(true);
    expect(canDeclareChi(chiEnabled, { suit: 'm', rank: 1 })).toBe(false);
    expect(canDeclareChi(chiEnabled, { suit: 'z', rank: 5 })).toBe(false);
    expect(canDeclareChi(chiEnabled, { suit: 'f', rank: 1 })).toBe(false);
  });

  it('awards spring chips equal to the total flowers held at the moment spring is extracted', () => {
    const game = makeGame();
    const summer = t('f', 2);
    const spring = t('f', 1);
    game.players[0].hand = [summer];
    declareFlowerDraw(game, 0, summer.id);
    expect(game.chip[0]).toBe(0); // summer alone does not burst chips

    game.players[0].hand.push(spring);
    const { springChips } = declareFlowerDraw(game, 0, spring.id);
    expect(springChips).toBe(2); // summer + spring held at this moment
    expect(game.chip[0]).toBe(2);
  });

  it('adds regular dora matches to the winning hands han', () => {
    const game = makeGame();
    game.round.doraIndicators = [t('p', 1)]; // dora is p2
    game.players[1].hand = tanyaoTiles();

    const win = checkTsumoWin(game, 1);
    expect(win.canWin).toBe(true);
    const result = resolveWin(game, win);
    // 3 p2 tiles in the hand: one in the 234p sequence, two as the pair.
    expect(result.doraResult.normalDora).toBe(3);
    expect(result.han).toBe(win.yakuResult.han + 3);
  });

  it('adds nuki-dora han equal to the winners extracted kita count', () => {
    const game = makeGame();
    game.players[1].hand = tanyaoTiles();
    game.players[1].kitaTiles = [t('z', 4), t('z', 4)];

    const win = checkTsumoWin(game, 1);
    const result = resolveWin(game, win);
    expect(result.doraResult.nukiDora).toBe(2);
    expect(result.han).toBe(win.yakuResult.han + 2);
  });

  it('detects a kokushi tsumo end-to-end and scores it as a pure yakuman (base 8000)', () => {
    const game = makeGame();
    game.players[1].hand = [
      t('m', 1), t('m', 1), t('m', 9), t('p', 1), t('p', 9),
      t('s', 1), t('s', 9), t('z', 1), t('z', 2), t('z', 3),
      t('z', 4), t('z', 5), t('z', 6), t('z', 7),
    ];

    const win = checkTsumoWin(game, 1);
    expect(win.canWin).toBe(true);
    expect(win.isYakuman).toBe(true);

    const result = resolveWin(game, win);
    expect(result.isYakuman).toBe(true);
    expect(result.han).toBe(13);
    expect(result.base).toBe(8000);
    expect(result.yakuList.map((y) => y.name)).toContain('国士無双');
    expect(result.chipResult.breakdown.find((b) => b.name === 'yakuman').chips).toBe(rules.RULE_CHIP_VALUES.pureYakuman);
  });

  it('rejects a "complete" hand that uses north outside kokushi/tsuuiisou/shousuushii/daisuushii', () => {
    const game = makeGame();
    // Structurally decomposes as 4 sets + pair, but one triplet is north
    // (z4), which is never usable as an ordinary hand tile.
    game.players[1].hand = [
      t('z', 4), t('z', 4), t('z', 4),
      t('p', 2), t('p', 3), t('p', 4),
      t('s', 6), t('s', 7), t('s', 8),
      t('m', 1), t('m', 1), t('m', 1),
      t('p', 7), t('p', 7),
    ];

    const win = checkTsumoWin(game, 1);
    expect(win.canWin).toBe(false);
    expect(win.reason).toBe('invalid_north_usage');
  });

  it('allows north as the shousuushii pair (one of its 4 legitimate uses)', () => {
    const game = makeGame();
    game.players[1].hand = [
      t('z', 1), t('z', 1), t('z', 1),
      t('z', 2), t('z', 2), t('z', 2),
      t('z', 3), t('z', 3), t('z', 3),
      t('p', 1), t('p', 2), t('p', 3),
      t('z', 4), t('z', 4),
    ];

    const win = checkTsumoWin(game, 1);
    expect(win.canWin).toBe(true);
    expect(win.isYakuman).toBe(true);
    expect(win.yakumanResult.names).toContain('小四喜');
  });

  it('declarePon claims the last discard, forms an open meld, and passes the turn to the caller', () => {
    const game = makeGame();
    const p1a = t('p', 1);
    const p1b = t('p', 1);
    const discarded = t('p', 1);
    game.players[1].hand = [p1a, p1b];
    game.players[0].discards = [discarded];

    const meld = declarePon(game, 1, 0, [p1a.id, p1b.id]);

    expect(meld).toEqual({ type: 'pon', suit: 'p', rank: 1, concealed: false, calledFrom: 0, tiles: [p1a, p1b, discarded] });
    expect(game.players[1].hand.length).toBe(0);
    expect(game.players[0].discards.length).toBe(0);
    expect(game.round.turn).toBe(1);
    expect(game.round.anyCallMade).toBe(true);
  });

  it('declarePon throws when the discarder\'s last discard does not match', () => {
    const game = makeGame();
    const p1a = t('p', 1);
    const p1b = t('p', 1);
    game.players[1].hand = [p1a, p1b];
    game.players[0].discards = [t('p', 2)];
    expect(() => declarePon(game, 1, 0, [p1a.id, p1b.id])).toThrow();
  });

  it('declareDaiminkan forms an open kan off a discard and draws a replacement', () => {
    const game = makeGame({ liveWall: [t('s', 9)] });
    const tiles = [t('p', 5), t('p', 5), t('p', 5)];
    game.players[1].hand = [...tiles];
    game.players[0].discards = [t('p', 5)];

    const { meld, replacement } = declareDaiminkan(game, 1, 0, tiles.map((x) => x.id));
    expect(meld.type).toBe('kan');
    expect(meld.concealed).toBe(false);
    expect(meld.tiles.length).toBe(4);
    expect(replacement).toBeTruthy();
    expect(game.players[1].hand).toContain(replacement);
    expect(game.round.turn).toBe(1);
    expect(game.round.anyCallMade).toBe(true);
  });

  it('declareAnkan forms a concealed kan from 4 hand tiles without changing the turn', () => {
    const game = makeGame({ liveWall: [t('s', 9)] });
    const tiles = [t('m', 1), t('m', 1), t('m', 1), t('m', 1)];
    game.players[0].hand = [...tiles];
    game.round.turn = 0;

    const { meld, replacement } = declareAnkan(game, 0, tiles.map((x) => x.id));
    expect(meld.type).toBe('kan');
    expect(meld.concealed).toBe(true);
    expect(meld.calledFrom).toBeUndefined();
    expect(replacement).toBeTruthy();
    expect(game.round.turn).toBe(0); // ankan is a self-declared action, no interruption
  });

  it('declareShouminkan upgrades an existing pon into a kan using a newly drawn tile', () => {
    const game = makeGame({ liveWall: [t('s', 9)] });
    const [t1, t2, t3] = [t('z', 6), t('z', 6), t('z', 6)];
    game.players[0].melds = [{ type: 'pon', suit: 'z', rank: 6, concealed: false, calledFrom: 1, tiles: [t1, t2, t3] }];
    const fourth = t('z', 6);
    game.players[0].hand = [fourth];

    const { meld, addedTile, replacement } = declareShouminkan(game, 0, fourth.id);
    expect(meld.type).toBe('kan');
    expect(meld.tiles.length).toBe(4);
    expect(addedTile).toBe(fourth);
    expect(replacement).toBeTruthy();
  });

  it('allows chankan: robbing a shouminkans added tile completes another players hand for 槍槓', () => {
    const game = makeGame({ liveWall: [t('s', 9)] });
    const [t1, t2, t3] = [t('z', 6), t('z', 6), t('z', 6)];
    game.players[0].melds = [{ type: 'pon', suit: 'z', rank: 6, concealed: false, calledFrom: 1, tiles: [t1, t2, t3] }];
    const fourth = t('z', 6);
    game.players[0].hand = [fourth];

    // seat 2 is tenpai waiting specifically on z6 (tanki wait).
    game.players[2].hand = [
      t('p', 1), t('p', 2), t('p', 3),
      t('s', 4), t('s', 5), t('s', 6),
      t('m', 1), t('m', 1), t('m', 1),
      t('p', 7), t('p', 8), t('p', 9),
      t('z', 6),
    ];

    const { addedTile } = declareShouminkan(game, 0, fourth.id);
    const win = checkRonWin(game, 2, 0, addedTile, { isChankan: true });
    expect(win.canWin).toBe(true);
    expect(win.yakuResult.yakuList.map((y) => y.name)).toContain('槍槓');
  });

  it('allows rinshan kaihou: winning off a kans replacement draw', () => {
    // drawReplacement pulls from the dead wall's replacement pool, not
    // straight off the live wall — arrange the pool so the replacement
    // is exactly the tile that completes the hand (a tanki wait on s1,
    // after the 4-tile ankan and 2 other complete sets + a triplet).
    const winningTile = t('s', 1);
    const game = makeGame({ liveWall: [t('s', 9)] });
    game.wall.deadWall.replacementPool = [winningTile];
    const tiles = [t('m', 1), t('m', 1), t('m', 1), t('m', 1)];
    game.players[0].hand = [
      ...tiles,
      t('p', 2), t('p', 3), t('p', 4),
      t('s', 6), t('s', 7), t('s', 8),
      t('p', 8), t('p', 8), t('p', 8),
      t('s', 1),
    ];

    const { replacement } = declareAnkan(game, 0, tiles.map((x) => x.id));
    expect(replacement).toBe(winningTile);

    const win = checkTsumoWin(game, 0, { isRinshan: true });
    expect(win.canWin).toBe(true);
    expect(win.yakuResult.yakuList.map((y) => y.name)).toContain('嶺上開花');
  });

  it('declareRiichi deposits 1000 points into the kyoutaku pot for a plain riichi', () => {
    const game = makeGame();
    declareRiichi(game, 0);
    expect(game.score[0]).toBe(35000 - 1000);
    expect(game.round.kyoutakuPoints).toBe(1000);
    expect(game.players[0].riichi.active).toBe(true);
  });

  it('declareRiichi with shubaTier "shuba" costs the same 1000 kyoutaku and consumes the shuba token', () => {
    const game = makeGame();
    declareRiichi(game, 0, { shubaTier: 'shuba' });
    expect(game.score[0]).toBe(35000 - 1000);
    expect(game.round.kyoutakuPoints).toBe(1000);
    expect(game.shubariichi.availableBySeat[0]).toBe(false);
    expect(game.shubariichi.tierBySeat[0]).toBe('shuba');
  });

  it('throws if the shuba stick was already used this hand', () => {
    const game = makeGame();
    game.players[0].hand = [t('p', 1)]; // needs a tile to discard/redeclare in a real flow, unused here
    declareRiichi(game, 0, { shubaTier: 'shuba' });
    // A fresh riichi declaration call on the same seat re-checks availability.
    game.players[0].riichi.active = false; // simulate a hand reset without resetting the shuba token
    expect(() => declareRiichi(game, 0, { shubaTier: 'shubazoma' })).toThrow();
  });

  it('rejects shubante when the players score is not above RULE_SHUBANTE_MIN_SCORE', () => {
    const game = makeGame();
    game.score[0] = 60000; // exactly at the threshold, not above it
    expect(() => declareRiichi(game, 0, { shubaTier: 'shubante' })).toThrow();
  });

  it('shubante deposits the players entire score into the kyoutaku pot', () => {
    const game = makeGame();
    game.score[0] = 70000;
    declareRiichi(game, 0, { shubaTier: 'shubante' });
    expect(game.score[0]).toBe(0);
    expect(game.round.kyoutakuPoints).toBe(70000);
    expect(game.shubariichi.tierBySeat[0]).toBe('shubante');
  });

  it('pays the winner everything sitting in the kyoutaku pot, including a shubante deposit', () => {
    const game = makeGame();
    game.score[0] = 70000;
    declareRiichi(game, 0, { shubaTier: 'shubante' }); // deposits 70000
    game.players[1].hand = tanyaoTiles();

    const before = game.score[1];
    const win = checkTsumoWin(game, 1);
    resolveWin(game, win);
    // Winner gets their normal tsumo payout plus the full 70000 kyoutaku pot.
    expect(game.score[1]).toBeGreaterThanOrEqual(before + 70000);
    expect(game.round.kyoutakuPoints).toBe(0);
  });

  it('retroactively tops up already-paid hana chips to the shuba-multiplied amount on a shuba win', () => {
    const game = makeGame({ liveWall: [t('s', 9)] });
    const spring = t('f', 1);
    game.players[1].hand = [spring];
    const { springChips } = declareFlowerDraw(game, 1, spring.id);
    expect(springChips).toBe(1);
    expect(game.chip[1]).toBe(1); // paid immediately at 1x

    declareRiichi(game, 1, { shubaTier: 'shuba' }); // x2 multiplier, but riichi needs a menzen hand — set it up next
    game.players[1].hand = tanyaoTiles();

    const win = checkTsumoWin(game, 1);
    const result = resolveWin(game, win);
    // Hana owed in total: 1 * 2 = 2. Already paid: 1. This win's chip
    // delta should include exactly 1 more for hana (netted into total).
    expect(result.chipResult.alreadyPaid).toBe(1);
    expect(game.chip[1]).toBeGreaterThan(1 + springChips); // more than just the immediate base
  });

  it('pays kinsei chips zero-sum from both opponents on a junme-8 tsumo win', () => {
    const game = makeGame();
    game.round.totalDiscards = 22; // junme = ceil(22/3) = 8
    game.players[1].hand = tanyaoTiles();

    const win = checkTsumoWin(game, 1);
    const result = resolveWin(game, win);
    expect(result.specialBonus.name).toBe('kinsei');
    expect(game.chip).toEqual([-3, 6, -3]);
  });

  it('pays daikinsei chips only from the discarder on a junme-16 ron win', () => {
    const game = makeGame();
    game.round.totalDiscards = 46; // junme = ceil(46/3) = 16
    const hand13 = tanyaoTiles().slice(0, 13);
    game.players[1].hand = hand13;
    const winTile = tanyaoTiles()[13];

    const win = checkRonWin(game, 1, 2, winTile);
    const result = resolveWin(game, win);
    expect(result.specialBonus.name).toBe('daikinsei');
    expect(game.chip).toEqual([0, 5, -5]);
  });

  it('junme advances by discard count, not draw count, so a pon-caller\'s free discard still counts', () => {
    const game = makeGame({ liveWall: [t('p', 9)] });
    // 21 ordinary discards have happened (junme 7). A pon call lets the
    // caller discard without drawing from the wall — this 22nd discard
    // must still land in junme 8 (ceil(22/3) = 8), even though it
    // wasn't preceded by a drawForTurn.
    game.round.totalDiscards = 21;
    const p9a = t('p', 9);
    const p9b = t('p', 9);
    game.players[0].hand = [p9a, p9b];
    game.players[2].discards = [t('p', 9)];
    declarePon(game, 0, 2, [p9a.id, p9b.id]); // caller discards next without drawing

    const followUpTile = t('m', 1);
    game.players[0].hand = [followUpTile];
    discardTile(game, 0, followUpTile.id);

    expect(game.round.totalDiscards).toBe(22);
  });

  it('does not pay kinsei/daikinsei on any other junme', () => {
    const game = makeGame();
    game.round.totalDiscards = 10; // junme = 4
    game.players[1].hand = tanyaoTiles();

    const win = checkTsumoWin(game, 1);
    const result = resolveWin(game, win);
    expect(result.specialBonus.name).toBeNull();
    expect(game.chip[0]).toBe(0);
    expect(game.chip[2]).toBe(0);
  });

  it('pays ordinary chip categories (e.g. red tiles) zero-sum from opponents too, not from a pool', () => {
    const game = makeGame();
    game.players[1].hand = [
      t('p', 2), t('p', 3), t('p', 4),
      t('p', 4), t('p', 5, 'red'), t('p', 6),
      t('s', 6), t('s', 7), t('s', 8),
      t('s', 3), t('s', 4), t('s', 5),
      t('p', 2), t('p', 2),
    ];

    const win = checkTsumoWin(game, 1);
    const result = resolveWin(game, win);
    expect(result.chipResult.total).toBe(3); // 1 red tile = 3 chips (ron-equivalent baseline)
    // Tsumo: each opponent pays the full 3, winner receives 3+3=6.
    expect(game.chip).toEqual([-3, 6, -3]);
  });

  it('triggers demekin (dice-roll chips) on a pure yakuman win, paid zero-sum on top of the yakuman chips', () => {
    const game = makeGame();
    game.players[1].hand = [
      t('m', 1), t('m', 1), t('m', 9), t('p', 1), t('p', 9),
      t('s', 1), t('s', 9), t('z', 1), t('z', 2), t('z', 3),
      t('z', 4), t('z', 5), t('z', 6), t('z', 7),
    ];

    const win = checkTsumoWin(game, 1);
    const result = resolveWin(game, win);
    expect(result.demekin.diceValue).toBeGreaterThanOrEqual(1);
    expect(result.demekin.diceValue).toBeLessThanOrEqual(6);
    // Each opponent pays the dice value on top of the yakuman chips.
    const yakumanChips = rules.RULE_CHIP_VALUES.pureYakuman;
    expect(game.chip[1]).toBe((yakumanChips + result.demekin.diceValue) * 2);
  });

  it('triggers demekin for holding all 4 kita, even without a yakuman', () => {
    const game = makeGame();
    game.players[1].hand = tanyaoTiles();
    game.players[1].kitaTiles = [t('z', 4), t('z', 4), t('z', 4), t('z', 4)];

    const win = checkTsumoWin(game, 1);
    const result = resolveWin(game, win);
    expect(result.demekin.diceValue).not.toBeNull();
  });

  it('does not trigger demekin on an ordinary win with none of the 4 conditions', () => {
    const game = makeGame();
    game.players[1].hand = tanyaoTiles();

    const win = checkTsumoWin(game, 1);
    const result = resolveWin(game, win);
    expect(result.demekin.diceValue).toBeNull();
    expect(result.demekin.deltas).toEqual([0, 0, 0]);
  });
});
