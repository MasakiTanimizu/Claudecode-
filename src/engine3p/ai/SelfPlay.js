// SelfPlay: the "parameter self-update" learning loop the CPU AI uses
// instead of training a neural network. A candidate weight vector is a
// small random mutation of the current one; it's kept only if it
// out-performs the baseline across a batch of self-played hands
// (simple hill-climbing / (1+1)-style evolution strategy).
//
// The self-play hand runner is intentionally simplified: draw/discard
// only, no calls, no riichi, no kita/hana. It reuses the real
// TurnEngine/YakuEngine, so a "win" here is a genuine, rule-legal win —
// the simplification is in what actions the AI can take, not in what
// counts as winning. Calls/riichi decisions are a natural next step
// once their own AI decision functions exist; wiring them in doesn't
// change this module's learning loop, only what happens inside
// `runSelfPlayHand`.

import { createGameState } from '../state/GameState.js';
import { drawForTurn, discardTile, checkTsumoWin, resolveWin, resolveExhaustiveDraw, seatWindOf } from '../engine/TurnEngine.js';
import { chooseDiscard } from './DiscardAI.js';
import { perturbWeights } from './AIWeights.js';

const MAX_TURNS = 200; // defensive cap; a real 3p hand exhausts well before this

export function runSelfPlayHand(weightsBySeat, { ruleConfig, wallOptions } = {}) {
  const game = createGameState({ ruleConfig, wallOptions });
  let seat = game.round.dealerSeat;

  for (let i = 0; i < MAX_TURNS; i++) {
    const drawn = drawForTurn(game, seat);
    if (!drawn) {
      const { tenpaiFlags } = resolveExhaustiveDraw(game);
      return { winner: null, exhaustive: true, tenpaiFlags, finalScore: game.score };
    }

    const win = checkTsumoWin(game, seat);
    if (win.canWin) {
      const result = resolveWin(game, win);
      return { winner: seat, exhaustive: false, result, finalScore: game.score };
    }

    const player = game.players[seat];
    const { tileId } = chooseDiscard({
      hand: player.hand,
      meldCount: player.melds.length,
      doraIndicators: game.round.doraIndicators,
      uraDoraIndicators: game.round.uraDoraIndicators,
      riichiActive: false,
      kitaCount: 0,
      roundWind: game.round.roundWind,
      seatWind: seatWindOf(seat, game.round.dealerSeat),
      isMenzen: true,
      opponentsDiscards: game.players.filter((p) => p.seat !== seat).map((p) => p.discards),
    }, weightsBySeat[seat]);

    discardTile(game, seat, tileId);
    seat = (seat + 1) % 3;
  }

  return { winner: null, exhaustive: true, timedOut: true, finalScore: game.score };
}

// Simple rank-based reward: 1st +2, 2nd 0, 3rd -2. Ties share the
// average of the ranks they'd occupy.
export function rankRewards(finalScore) {
  const order = finalScore.map((score, seat) => ({ seat, score }))
    .sort((a, b) => b.score - a.score);
  const rewardForPlace = [2, 0, -2];
  const rewards = [0, 0, 0];
  let i = 0;
  while (i < order.length) {
    let j = i;
    while (j + 1 < order.length && order[j + 1].score === order[i].score) j++;
    const avg = rewardForPlace.slice(i, j + 1).reduce((a, b) => a + b, 0) / (j - i + 1);
    for (let k = i; k <= j; k++) rewards[order[k].seat] = avg;
    i = j + 1;
  }
  return rewards;
}

// Runs `hands` self-play hands, each time randomly seating the
// candidate weights against two baseline-weight opponents, and accepts
// the candidate as the new baseline only if its average reward beats
// the baseline's average reward over the same batch.
export function evolveWeights(baseWeights, {
  hands = 20,
  scale = 1,
  rng = Math.random,
  ruleConfig,
  wallOptions,
} = {}) {
  const candidate = perturbWeights(baseWeights, { scale, rng });

  let candidateTotal = 0;
  let candidateCount = 0;
  let baseTotal = 0;
  let baseCount = 0;

  for (let h = 0; h < hands; h++) {
    const candidateSeat = Math.floor(rng() * 3);
    const weightsBySeat = [0, 1, 2].map((seat) => (seat === candidateSeat ? candidate : baseWeights));

    const { finalScore } = runSelfPlayHand(weightsBySeat, { ruleConfig, wallOptions });
    const rewards = rankRewards(finalScore);

    rewards.forEach((reward, seat) => {
      if (seat === candidateSeat) {
        candidateTotal += reward;
        candidateCount += 1;
      } else {
        baseTotal += reward;
        baseCount += 1;
      }
    });
  }

  const candidateAvg = candidateCount > 0 ? candidateTotal / candidateCount : 0;
  const baseAvg = baseCount > 0 ? baseTotal / baseCount : 0;

  if (candidateAvg > baseAvg) {
    return { weights: candidate, accepted: true, candidateAvg, baseAvg };
  }
  return { weights: baseWeights, accepted: false, candidateAvg, baseAvg };
}
