// Shanten calculator: how many tile exchanges away from a complete
// hand. Used by the CPU AI (spec section 42) for discard/call
// decisions. Follows the same tile-count convention as
// HandParser.isTenpai — shanten 0 means tenpai (getWinningTiles is
// non-empty), -1 means already complete.
//
// Standard-hand shanten uses the well known block-decomposition search:
// recursively pull complete melds (triplet/sequence), partial melds
// (pair, ryanmen/penchan, kanchan) and at most one reserved pair-head
// out of the tile multiset, memoized on the remaining counts, then
// shanten = 8 - 2*melds - min(partials, 4-melds) - (head ? 1 : 0),
// minimized over every reachable (melds, partials, head) combination.

import { tileKey } from '../tiles/Tiles.js';

const SEQUENCE_SUITS = new Set(['p', 's']);

function countsKey(counts) {
  return [...counts.entries()]
    .filter(([, n]) => n > 0)
    .sort(([a], [b]) => (a < b ? -1 : 1))
    .map(([k, n]) => `${k}${n}`)
    .join('|');
}

// Returns a Pareto-pruned array of { melds, partials } reachable from
// this tile multiset with `headAvailable` telling whether a pair-head
// bonus is still up for grabs (folded into `head` in the result).
function search(counts, headAvailable, memo) {
  const entries = [...counts.entries()].filter(([, n]) => n > 0);
  if (entries.length === 0) return [{ melds: 0, partials: 0, head: false }];

  const cacheKey = `${countsKey(counts)}#${headAvailable ? 1 : 0}`;
  if (memo.has(cacheKey)) return memo.get(cacheKey);

  const [key, count] = entries[0];
  const suit = key[0];
  const rank = Number(key.slice(1));
  const results = [];

  const withDelta = (next, dMelds, dPartials, dHead, nextHeadAvailable) => {
    for (const r of search(next, nextHeadAvailable, memo)) {
      results.push({ melds: r.melds + dMelds, partials: r.partials + dPartials, head: r.head || dHead });
    }
  };

  // Skip this tile type entirely (treat remaining copies as isolated).
  {
    const next = new Map(counts);
    next.delete(key);
    withDelta(next, 0, 0, false, headAvailable);
  }

  // Triplet.
  if (count >= 3) {
    const next = new Map(counts);
    next.set(key, count - 3);
    withDelta(next, 1, 0, false, headAvailable);
  }

  // Pair, used as a partial toward a triplet.
  if (count >= 2) {
    const next = new Map(counts);
    next.set(key, count - 2);
    withDelta(next, 0, 1, false, headAvailable);
  }

  // Pair, reserved as the hand's head (only once).
  if (count >= 2 && headAvailable) {
    const next = new Map(counts);
    next.set(key, count - 2);
    withDelta(next, 0, 0, true, false);
  }

  if (SEQUENCE_SUITS.has(suit)) {
    // Complete sequence.
    if (rank <= 7) {
      const k2 = tileKey(suit, rank + 1);
      const k3 = tileKey(suit, rank + 2);
      const c2 = counts.get(k2) ?? 0;
      const c3 = counts.get(k3) ?? 0;
      if (c2 >= 1 && c3 >= 1) {
        const next = new Map(counts);
        next.set(key, count - 1);
        next.set(k2, c2 - 1);
        next.set(k3, c3 - 1);
        withDelta(next, 1, 0, false, headAvailable);
      }
    }
    // Adjacent partial (ryanmen/penchan): n, n+1.
    if (rank <= 8) {
      const k2 = tileKey(suit, rank + 1);
      const c2 = counts.get(k2) ?? 0;
      if (c2 >= 1) {
        const next = new Map(counts);
        next.set(key, count - 1);
        next.set(k2, c2 - 1);
        withDelta(next, 0, 1, false, headAvailable);
      }
    }
    // Gap partial (kanchan): n, n+2.
    if (rank <= 7) {
      const k3 = tileKey(suit, rank + 2);
      const c3 = counts.get(k3) ?? 0;
      if (c3 >= 1) {
        const next = new Map(counts);
        next.set(key, count - 1);
        next.set(k3, c3 - 1);
        withDelta(next, 0, 1, false, headAvailable);
      }
    }
  }

  const pruned = pruneDominated(results);
  memo.set(cacheKey, pruned);
  return pruned;
}

// A result is dominated (and safe to drop) if another result is at
// least as good on every axis (melds, partials, head) and strictly
// better on at least one — it can never be the unique best choice.
function dominates(a, b) {
  const atLeastAsGood = a.melds >= b.melds && a.partials >= b.partials && (a.head || !b.head);
  const strictlyBetter = a.melds > b.melds || a.partials > b.partials || (a.head && !b.head);
  return atLeastAsGood && strictlyBetter;
}

function pruneDominated(results) {
  return results.filter((r, i) => !results.some((o, j) => j !== i && dominates(o, r)));
}

// meldCount already-called melds count as free/complete melds toward
// the 4-meld target, on top of whatever is found in the concealed tiles.
function metricToShanten({ melds, partials, head }, meldCount) {
  const totalMelds = melds + meldCount;
  const cappedPartials = Math.min(partials, 4 - totalMelds);
  return 8 - 2 * totalMelds - cappedPartials - (head ? 1 : 0);
}

export function standardShanten(concealedTiles, meldCount = 0) {
  const counts = new Map();
  for (const t of concealedTiles) {
    const key = tileKey(t.suit, t.rank);
    counts.set(key, (counts.get(key) ?? 0) + 1);
  }
  const memo = new Map();
  const combos = search(counts, true, memo);
  return Math.min(...combos.map((c) => metricToShanten(c, meldCount)));
}

export function chiitoiShanten(concealedTiles) {
  const counts = new Map();
  for (const t of concealedTiles) {
    const key = tileKey(t.suit, t.rank);
    counts.set(key, (counts.get(key) ?? 0) + 1);
  }
  const kinds = counts.size;
  const pairs = [...counts.values()].filter((n) => n >= 2).length;
  return 6 - pairs + Math.max(0, 7 - kinds);
}

const KOKUSHI_KEYS = new Set([
  'm1', 'm9', 'p1', 'p9', 's1', 's9',
  'z1', 'z2', 'z3', 'z4', 'z5', 'z6', 'z7',
]);

export function kokushiShanten(concealedTiles) {
  const present = new Set();
  let hasPair = false;
  for (const t of concealedTiles) {
    const key = tileKey(t.suit, t.rank);
    if (!KOKUSHI_KEYS.has(key)) continue;
    if (present.has(key)) hasPair = true;
    present.add(key);
  }
  return 13 - present.size - (hasPair ? 1 : 0);
}

// meldCount: number of already-called melds (each removes 3 tiles from
// the standard-shanten search space, and disqualifies chiitoi/kokushi).
export function shanten(concealedTiles, meldCount = 0) {
  if (meldCount > 0) return standardShanten(concealedTiles, meldCount);
  return Math.min(
    standardShanten(concealedTiles, 0),
    chiitoiShanten(concealedTiles),
    kokushiShanten(concealedTiles),
  );
}
