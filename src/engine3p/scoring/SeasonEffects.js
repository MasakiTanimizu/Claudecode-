// SeasonTileState effects (spec sections 28-30).
//
// - 春 (Spring, f1): awards chips immediately on extraction, equal to
//   the number of flower tiles the player holds at that moment.
// - 夏 (Summer, f2): the winner's hand ranks up one tier (mangan ->
//   haneman -> baiman -> sanbaiman -> yakuman; yakuman -> 5x yakuman).
// - 秋 (Autumn, f3): every 5-tile in the winner's hand gets an extra
//   dora rank: black 5 -> dora 1, red/blue 5 -> dora 2 (i.e. +1 on top
//   of whatever aka/ura-dora-equivalent bonus it already earns).
// - 冬 (Winter, f4): "上下段アリス" — Alice engine hook (Phase 4), not
//   implemented here.
//
// A season is "active" for a win if the winner personally extracted
// that flower, OR that flower turned up as a dora/ura-dora indicator
// (spec section 30 — the effect then belongs to whoever wins the hand).

const SPRING = 1;
const SUMMER = 2;
const AUTUMN = 3;
const WINTER = 4;

export function computeSpringChips(flowerCountAtExtraction) {
  return flowerCountAtExtraction;
}

export function getActiveSeasons(playerFlowerTiles, doraIndicators, uraDoraIndicators) {
  const seasons = new Set();
  for (const t of playerFlowerTiles ?? []) seasons.add(t.rank);
  for (const t of [...(doraIndicators ?? []), ...(uraDoraIndicators ?? [])]) {
    if (t.suit === 'f') seasons.add(t.rank);
  }
  return seasons;
}

export function computeAutumnBonusHan(handTiles, activeSeasons) {
  if (!activeSeasons.has(AUTUMN)) return 0;
  let bonus = 0;
  for (const t of handTiles ?? []) {
    if (t.rank !== 5 || (t.suit !== 'p' && t.suit !== 's')) continue;
    bonus += 1; // black5 -> dora1, red/blue5 -> dora2 (their own +1 already counted elsewhere)
  }
  return bonus;
}

const RANK_UP_TIERS = [2000, 3000, 4000, 6000, 8000]; // mangan..yakuman

export function applySummerRankUp(base, activeSeasons, { isYakuman = false } = {}) {
  if (!activeSeasons.has(SUMMER)) return base;
  if (isYakuman) return base * 5; // yakuman -> 5倍満
  const idx = RANK_UP_TIERS.indexOf(base);
  if (idx === -1) return base < RANK_UP_TIERS[0] ? RANK_UP_TIERS[0] : base;
  return RANK_UP_TIERS[Math.min(idx + 1, RANK_UP_TIERS.length - 1)];
}

export function isWinterActive(activeSeasons) {
  return activeSeasons.has(WINTER);
}

export { SPRING, SUMMER, AUTUMN, WINTER };
