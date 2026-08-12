// HandParser: decomposes a 14-tile hand (13 concealed + winning tile, plus
// any melds already on the table) into standard 4-sets-and-a-pair
// decompositions, plus chiitoitsu and kokushi detection.
//
// Because man suit only has rank 1 and 9 (spec section 4), a run (chi) of
// three consecutive man tiles is structurally impossible; the sequence
// search below naturally never finds one since it only looks at
// consecutive ranks within a suit that actually has consecutive ranks.

import { tileKey } from '../tiles/Tiles.js';

function groupByKey(tiles) {
  const map = new Map();
  for (const t of tiles) {
    const key = tileKey(t.suit, t.rank);
    if (!map.has(key)) map.set(key, []);
    map.get(key).push(t);
  }
  return map;
}

// Sequences only exist for suits with consecutive ranks 1-9 (pin/sou).
// Man suit is excluded entirely since it only contains 1 and 9.
const SEQUENCE_SUITS = new Set(['p', 's']);

function cloneCounts(counts) {
  return new Map(counts);
}

// Recursively decomposes a multiset of concealed tiles (grouped by key,
// counts only — suit/rank recovered from the key) into melds (triplet or
// sequence) + exactly one pair. Returns an array of decompositions, each
// `{ melds: [{ type: 'triplet' | 'sequence', suit, rank }], pair: { suit, rank } }`.
function decompose(counts, meldsSoFar, pair) {
  const entries = [...counts.entries()].filter(([, n]) => n > 0);
  if (entries.length === 0) {
    return pair ? [{ melds: meldsSoFar, pair }] : [];
  }

  const [key, count] = entries[0];
  const suit = key[0];
  const rank = Number(key.slice(1));
  const results = [];

  // Try pair (only if not already taken).
  if (!pair && count >= 2) {
    const next = cloneCounts(counts);
    next.set(key, count - 2);
    for (const r of decompose(next, meldsSoFar, { suit, rank })) {
      results.push(r);
    }
  }

  // Try triplet.
  if (count >= 3) {
    const next = cloneCounts(counts);
    next.set(key, count - 3);
    const meld = { type: 'triplet', suit, rank };
    for (const r of decompose(next, [...meldsSoFar, meld], pair)) {
      results.push(r);
    }
  }

  // Try sequence (rank, rank+1, rank+2) within the same suit.
  if (SEQUENCE_SUITS.has(suit) && rank <= 7) {
    const k1 = key;
    const k2 = tileKey(suit, rank + 1);
    const k3 = tileKey(suit, rank + 2);
    const c2 = counts.get(k2) ?? 0;
    const c3 = counts.get(k3) ?? 0;
    if (c2 >= 1 && c3 >= 1) {
      const next = cloneCounts(counts);
      next.set(k1, (next.get(k1) ?? 0) - 1);
      next.set(k2, c2 - 1);
      next.set(k3, c3 - 1);
      const meld = { type: 'sequence', suit, rank };
      for (const r of decompose(next, [...meldsSoFar, meld], pair)) {
        results.push(r);
      }
    }
  }

  return results;
}

// tiles: concealed tiles only (does not include already-called melds).
// Returns an array of possible decompositions (there can be more than
// one interpretation, e.g. for iipeikou vs. two identical sequences).
export function decomposeStandardHand(tiles) {
  const counts = new Map();
  for (const t of tiles) {
    const key = tileKey(t.suit, t.rank);
    counts.set(key, (counts.get(key) ?? 0) + 1);
  }
  return decompose(counts, [], null);
}

export function isChiitoitsu(tiles) {
  if (tiles.length !== 14) return false;
  const counts = groupByKey(tiles);
  if (counts.size !== 7) return false;
  return [...counts.values()].every((arr) => arr.length === 2);
}

const KOKUSHI_KEYS = new Set([
  'm1', 'm9', 'p1', 'p9', 's1', 's9',
  'z1', 'z2', 'z3', 'z4', 'z5', 'z6', 'z7',
]);

export function isKokushi(tiles) {
  if (tiles.length !== 14) return false;
  const counts = new Map();
  for (const t of tiles) {
    const key = tileKey(t.suit, t.rank);
    if (!KOKUSHI_KEYS.has(key)) return false;
    counts.set(key, (counts.get(key) ?? 0) + 1);
  }
  if (counts.size !== 13) return false;
  return [...counts.values()].some((n) => n >= 2);
}

// A hand (concealed tiles + melds) is a complete standard hand if the
// concealed portion decomposes into (4 - meldCount) melds + 1 pair.
export function isCompleteStandardHand(concealedTiles, meldCount = 0) {
  const decompositions = decomposeStandardHand(concealedTiles);
  const requiredMelds = 4 - meldCount;
  return decompositions.some((d) => d.melds.length === requiredMelds);
}

export function isComplete(concealedTiles, meldCount = 0) {
  const allTiles = [...concealedTiles];
  if (meldCount === 0 && allTiles.length === 14) {
    if (isChiitoitsu(allTiles)) return true;
    if (isKokushi(allTiles)) return true;
  }
  return isCompleteStandardHand(concealedTiles, meldCount);
}

const ALL_TILE_KEYS = [
  ...[1, 9].map((r) => tileKey('m', r)),
  ...Array.from({ length: 9 }, (_, i) => tileKey('p', i + 1)),
  ...Array.from({ length: 9 }, (_, i) => tileKey('s', i + 1)),
  ...Array.from({ length: 7 }, (_, i) => tileKey('z', i + 1)),
];

// Given a tenpai (13-tile-equivalent) concealed hand, returns the set of
// tile keys ('p5', 'z1', ...) that would complete it. Used for furiten
// checks and CPU tenpai evaluation.
export function getWinningTiles(concealedTiles, meldCount = 0) {
  const winners = [];
  for (const key of ALL_TILE_KEYS) {
    const suit = key[0];
    const rank = Number(key.slice(1));
    if (isComplete([...concealedTiles, { suit, rank }], meldCount)) winners.push(key);
  }
  return winners;
}

export function isTenpai(concealedTiles, meldCount = 0) {
  return getWinningTiles(concealedTiles, meldCount).length > 0;
}
