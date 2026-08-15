// WallState: wall generation, dealing, dora indicators, and the
// rinshan/kita/hana replacement mechanism (spec sections 6-8, 53).
//
// Conservation model (matches standard riichi mahjong mechanics):
//   - Dead wall has a fixed size (RULE_DEAD_WALL_SIZE, default 14):
//     RULE_DORA_DISPLAY_COUNT dora indicators + the same number of ura
//     indicators + up to RULE_MAX_KAN_DORA reserved kan-dora slots (and
//     a matching reserved kan-uradora pool) + a replacement ("rinshan")
//     pool for whatever's left.
//   - Every kan/kita/flower replacement draw pulls one tile from the
//     front of the replacement pool and pushes one tile from the tail
//     of the live wall into the pool, keeping the dead wall size
//     constant while the live wall shrinks by exactly one tile.
//   - Every kan additionally reveals the next kan-dora indicator (per
//     the user's confirmation that kan-dora is implemented, contrary to
//     the earlier fixed-2-dora assumption) — see revealKanDora/
//     revealKanUraDora. Once a hand has used more kans than
//     RULE_MAX_KAN_DORA, further kans simply don't add more dora.
//   - Live wall reaching zero tiles ends the hand in an exhaustive draw.

import { createTileSet } from '../tiles/Tiles.js';

function secureShuffle(tiles) {
  const arr = tiles.slice();
  for (let i = arr.length - 1; i > 0; i--) {
    const bytes = new Uint32Array(1);
    crypto.getRandomValues(bytes);
    // Rejection-free enough for a game wall shuffle; uniformity bias is negligible at this scale.
    const j = bytes[0] % (i + 1);
    [arr[i], arr[j]] = [arr[j], arr[i]];
  }
  return arr;
}

export function createWall(ruleConfig, { shuffle = secureShuffle } = {}) {
  const deadWallSize = ruleConfig.RULE_DEAD_WALL_SIZE ?? 14;
  const doraCount = ruleConfig.RULE_DORA_DISPLAY_COUNT ?? 2;
  const maxKanDora = ruleConfig.RULE_MAX_KAN_DORA ?? 4;

  const allTiles = shuffle(createTileSet(ruleConfig));
  const deadWallTiles = allTiles.slice(0, deadWallSize);
  const liveWall = allTiles.slice(deadWallSize);

  let cursor = 0;
  const take = (n) => {
    const slice = deadWallTiles.slice(cursor, cursor + n);
    cursor += n;
    return slice;
  };

  const doraIndicators = take(doraCount);
  const uraDoraIndicators = take(doraCount);
  const kanDoraPool = take(maxKanDora);
  const kanUraDoraPool = take(maxKanDora);
  const replacementPool = deadWallTiles.slice(cursor);

  return {
    liveWall,
    deadWall: {
      doraIndicators,
      uraDoraIndicators,
      kanDoraPool,
      kanUraDoraPool,
      replacementPool,
    },
  };
}

// Reveals the next kan-dora indicator (spec section 8, extended per the
// user's kan-dora confirmation). Returns null once RULE_MAX_KAN_DORA
// kans have already revealed one each this hand — the caller decides
// what (if anything) that means for further kans.
export function revealKanDora(wall) {
  if (wall.deadWall.kanDoraPool.length === 0) return null;
  return wall.deadWall.kanDoraPool.shift();
}

export function revealKanUraDora(wall) {
  if (wall.deadWall.kanUraDoraPool.length === 0) return null;
  return wall.deadWall.kanUraDoraPool.shift();
}

// The tile Alice (Phase 4, not yet implemented) would start revealing
// from: per the user, "次に槓する予定だった牌からアリス開始" — i.e.
// whatever kan-dora slot is next up but hasn't been used yet. Exposed
// now so the wall's dead-wall layout is already correct/ready for
// Alice's engine to consume later without another redesign.
export function peekNextAliceTile(wall) {
  if (wall.deadWall.kanDoraPool.length > 0) return wall.deadWall.kanDoraPool[0];
  return wall.deadWall.replacementPool[0] ?? null;
}

export function dealHands(wall, playerCount = 3, handSize = 13) {
  const hands = [];
  for (let p = 0; p < playerCount; p++) {
    hands.push(wall.liveWall.splice(0, handSize));
  }
  return hands;
}

export function drawTile(wall) {
  if (wall.liveWall.length === 0) return null;
  return wall.liveWall.shift();
}

export function drawReplacement(wall) {
  if (wall.liveWall.length === 0) return null;
  const tile = wall.deadWall.replacementPool.shift();
  const moved = wall.liveWall.pop();
  wall.deadWall.replacementPool.push(moved);
  return tile;
}

export function remainingDraws(wall) {
  return wall.liveWall.length;
}

export function isExhausted(wall) {
  return wall.liveWall.length === 0;
}

export { secureShuffle };
