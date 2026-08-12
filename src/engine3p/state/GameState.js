// GameState: top-level container combining the per-hand and per-game
// state slices described in spec section 41. Phase 1 wires up the
// pieces needed to play a hand end-to-end; later phases (Alice, Shuba,
// seasonal tiles, ranking) plug into the stub slices below without
// requiring changes to this shape.

import { createRuleConfig } from '../rules/RuleConfig.js';
import { createWall, dealHands } from '../wall/Wall.js';
import { createPlayerState } from './PlayerState.js';
import { createRoundState } from './RoundState.js';
import { createScoreState, createChipState } from './ScoreState.js';

export function createGameState(overrides = {}) {
  const ruleConfig = createRuleConfig(overrides.ruleConfig);
  const playerCount = 3;

  const wall = createWall(ruleConfig, overrides.wallOptions);
  const hands = dealHands(wall, playerCount, 13);

  const players = hands.map((hand, seat) => {
    const p = createPlayerState(seat, { isDealer: seat === 0 });
    p.hand = hand;
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
    // Phase 4/5 hooks — populated by their own engines once implemented.
    flower: { drawnBySeat: [[], [], []] },
    alice: { active: false, chain: 0, revealedTiles: [] },
    shubariichi: { usedBySeat: [false, false, false], tier: [null, null, null] },
    ranking: { finished: false, order: [], rankPoints: [0, 0, 0] },
  };
}
