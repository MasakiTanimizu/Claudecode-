// GameState: top-level container combining the per-hand and per-game
// state slices described in spec section 41. Wires up the pieces needed
// to play a hand end-to-end; Alice and completed-game ranking are still
// later-phase stubs that plug into this shape without changes.

import { createRuleConfig } from '../rules/RuleConfig.js';
import { createWall, dealHands } from '../wall/Wall.js';
import { createPlayerState } from './PlayerState.js';
import { createRoundState } from './RoundState.js';
import { createScoreState, createChipState } from './ScoreState.js';
import { createFlowerState } from './FlowerState.js';
import { createWhitePotchiState, markHakuPotchiIfDrawn } from './WhitePotchiState.js';
import { createShubaState } from './ShubaState.js';

export function createGameState(overrides = {}) {
  const ruleConfig = createRuleConfig(overrides.ruleConfig);
  const playerCount = 3;

  const wall = createWall(ruleConfig, overrides.wallOptions);
  const hands = dealHands(wall, playerCount, 13);

  let whitePotchi = createWhitePotchiState(playerCount);
  const players = hands.map((hand, seat) => {
    const p = createPlayerState(seat, { isDealer: seat === 0 });
    p.hand = hand;
    for (const tile of hand) {
      whitePotchi = markHakuPotchiIfDrawn(whitePotchi, seat, tile, { riichiActive: false, riichiEverDeclared: false });
    }
    return p;
  });

  const round = createRoundState({ dealerSeat: 0 });
  round.doraIndicators = wall.deadWall.doraIndicators;
  round.uraDoraIndicators = wall.deadWall.uraDoraIndicators;

  return {
    ruleConfig,
    wall,
    players,
    round,
    score: createScoreState(playerCount, ruleConfig),
    chip: createChipState(playerCount),
    flower: createFlowerState(playerCount),
    whitePotchi,
    shubariichi: createShubaState(playerCount),
    // Phase 4 hooks — populated by their own engines once implemented.
    alice: { active: false, chain: 0, revealedTiles: [] },
    ranking: { finished: false, order: [], rankPoints: [0, 0, 0] },
  };
}
