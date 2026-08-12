// WallState: wall generation, dealing, dora indicators, and the
// rinshan/kita/hana replacement mechanism (spec sections 6-8, 53).
//
// Conservation model (matches standard riichi mahjong mechanics):
//   - Dead wall has a fixed size (RULE_DEAD_WALL_SIZE, default 14):
//     RULE_DORA_DISPLAY_COUNT dora indicators + the same number of ura
//     indicators + a replacement ("rinshan") pool for the rest.
//   - Every kan/kita/flower replacement draw pulls one tile from the
//     front of the replacement pool and pushes one tile from the tail
//     of the live wall into the pool, keeping the dead wall size
//     constant while the live wall shrinks by exactly one tile.
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

  const allTiles = shuffle(createTileSet(ruleConfig));
  const deadWallTiles = allTiles.slice(0, deadWallSize);
  const liveWall = allTiles.slice(deadWallSize);

  const doraIndicators = deadWallTiles.slice(0, doraCount);
  const uraDoraIndicators = deadWallTiles.slice(doraCount, doraCount * 2);
  const replacementPool = deadWallTiles.slice(doraCount * 2);

  return {
    liveWall,
    deadWall: {
      doraIndicators,
      uraDoraIndicators,
      replacementPool,
    },
  };
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
