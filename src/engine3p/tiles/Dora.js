// Dora indicator -> dora tile mapping (spec section 8).
//
// Pin/sou/honors follow the standard successor cycle. Man suit only has
// rank 1 and 9 (spec section 4), so there is no literal "next number" —
// the two existing man tiles are treated as each other's successor
// (1 -> 9 -> 1), the natural reduction of the standard cycle to a suit
// with just two members.

const HONOR_WIND_CYCLE = [1, 2, 3, 4]; // East -> South -> West -> North -> East
const HONOR_DRAGON_CYCLE = [5, 6, 7]; // Haku -> Hatsu -> Chun -> Haku

export function doraSuccessor(indicator) {
  if (indicator.suit === 'm') {
    return { suit: 'm', rank: indicator.rank === 1 ? 9 : 1 };
  }
  if (indicator.suit === 'p' || indicator.suit === 's') {
    const nextRank = indicator.rank === 9 ? 1 : indicator.rank + 1;
    return { suit: indicator.suit, rank: nextRank };
  }
  if (indicator.suit === 'z') {
    if (HONOR_WIND_CYCLE.includes(indicator.rank)) {
      const idx = HONOR_WIND_CYCLE.indexOf(indicator.rank);
      return { suit: 'z', rank: HONOR_WIND_CYCLE[(idx + 1) % HONOR_WIND_CYCLE.length] };
    }
    const idx = HONOR_DRAGON_CYCLE.indexOf(indicator.rank);
    return { suit: 'z', rank: HONOR_DRAGON_CYCLE[(idx + 1) % HONOR_DRAGON_CYCLE.length] };
  }
  // Flower indicators are handled by the (future) SeasonTileState hook,
  // not by the plain dora count.
  return null;
}

export function countDoraMatches(handTiles, indicators) {
  const doraTiles = indicators.map(doraSuccessor).filter(Boolean);
  let count = 0;
  for (const tile of handTiles) {
    for (const dora of doraTiles) {
      if (tile.suit === dora.suit && tile.rank === dora.rank) count += 1;
    }
  }
  return count;
}
