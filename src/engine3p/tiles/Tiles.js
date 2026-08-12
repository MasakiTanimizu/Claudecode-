// Tile definitions for the 3-player ruleset (spec section 4-7).
//
// Suits:
//   m = man   (only rank 1 and 9 exist, 4 copies each -> 8 tiles)
//   p = pin   (rank 1-9, 4 copies each -> 36 tiles)
//   s = sou   (rank 1-9, 4 copies each -> 36 tiles)
//   z = honor (1 East, 2 South, 3 West, 4 North, 5 Haku, 6 Hatsu, 7 Chun; 4 copies each -> 28 tiles)
//   f = flower(1 Spring, 2 Summer, 3 Autumn, 4 Winter; 1 copy each -> 4 tiles)
//
// Total: 8 + 36 + 36 + 28 + 4 = 112 tiles.

export const HONOR_NAMES = {
  1: 'East',
  2: 'South',
  3: 'West',
  4: 'North',
  5: 'Haku',
  6: 'Hatsu',
  7: 'Chun',
};

export const FLOWER_NAMES = {
  1: 'Spring',
  2: 'Summer',
  3: 'Autumn',
  4: 'Winter',
};

export const MAN_RANKS = [1, 9];
export const SUIT_RANKS = [1, 2, 3, 4, 5, 6, 7, 8, 9];

function tileSpec() {
  const spec = [];
  for (const rank of MAN_RANKS) spec.push({ suit: 'm', rank, copies: 4 });
  for (const rank of SUIT_RANKS) spec.push({ suit: 'p', rank, copies: 4 });
  for (const rank of SUIT_RANKS) spec.push({ suit: 's', rank, copies: 4 });
  for (let rank = 1; rank <= 7; rank++) spec.push({ suit: 'z', rank, copies: 4 });
  for (let rank = 1; rank <= 4; rank++) spec.push({ suit: 'f', rank, copies: 1 });
  return spec;
}

export const TILE_SPEC = tileSpec();

export function tileKey(suit, rank) {
  return `${suit}${rank}`;
}

export function isHonor(tile) {
  return tile.suit === 'z';
}

export function isFlower(tile) {
  return tile.suit === 'f';
}

export function isNorth(tile) {
  return tile.suit === 'z' && tile.rank === 4;
}

export function isHaku(tile) {
  return tile.suit === 'z' && tile.rank === 5;
}

export function isSimple(tile) {
  if (tile.suit === 'z' || tile.suit === 'f') return false;
  if (tile.suit === 'm') return false; // only 1/9 exist, always terminal
  return tile.rank >= 2 && tile.rank <= 8;
}

export function isTerminal(tile) {
  if (tile.suit === 'm') return true;
  if (tile.suit === 'z' || tile.suit === 'f') return false;
  return tile.rank === 1 || tile.rank === 9;
}

export function isTerminalOrHonor(tile) {
  return isTerminal(tile) || isHonor(tile);
}

// Builds the full 112-tile set as plain, immutable-ish tile objects.
// `ruleConfig.RULE_SPECIAL_TILE_MAP` decides which copies of which
// suited tiles are red/blue variants; remaining copies of a tile that
// appears in the map become 'black' (visually distinct, same value),
// tiles not mentioned in the map are ordinary (variant: null).
export function createTileSet(ruleConfig) {
  const specialMap = ruleConfig.RULE_SPECIAL_TILE_MAP ?? [];
  const tiles = [];
  let seq = 0;

  for (const { suit, rank, copies } of TILE_SPEC) {
    const entries = specialMap.filter((e) => e.suit === suit && e.rank === rank);
    const variantAssignment = [];
    for (const entry of entries) {
      for (let i = 0; i < entry.count; i++) variantAssignment.push(entry.variant);
    }
    const hasSpecial = entries.length > 0;

    for (let copyIndex = 0; copyIndex < copies; copyIndex++) {
      const variant = copyIndex < variantAssignment.length
        ? variantAssignment[copyIndex]
        : (hasSpecial ? 'black' : null);
      tiles.push({
        id: `${tileKey(suit, rank)}-${seq++}`,
        suit,
        rank,
        variant,
      });
    }
  }

  return tiles;
}

export function countBySuit(tiles) {
  return tiles.reduce((acc, t) => {
    acc[t.suit] = (acc[t.suit] ?? 0) + 1;
    return acc;
  }, {});
}
