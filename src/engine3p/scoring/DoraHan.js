// Dora-derived han, kept separate from yaku han per spec section 39
// (ScoreEngine takes "ドラ・赤ドラ・青牌" as explicit inputs distinct
// from 役/翻数). Regular dora and aka-dora(red) always count; ura-dora
// and its blue-tile equivalent only count for a riichi hand, matching
// standard mahjong's ura-dora gating.

import { countDoraMatches } from '../tiles/Dora.js';

export function computeDoraHan({
  handTiles,
  doraIndicators,
  uraDoraIndicators,
  riichiActive,
  kitaCount,
}) {
  const tiles = handTiles ?? [];

  const normalDora = countDoraMatches(tiles, doraIndicators ?? []);
  const akaDora = tiles.filter((t) => t.variant === 'red').length;

  // Blue tiles are always-hit ura-dora targets (spec section 5).
  const uraDora = riichiActive
    ? countDoraMatches(tiles, uraDoraIndicators ?? []) + tiles.filter((t) => t.variant === 'blue').length
    : 0;

  // Kita counts as an extracted "抜きドラ" (spec section 6).
  const nukiDora = kitaCount ?? 0;

  return {
    normalDora,
    akaDora,
    uraDora,
    nukiDora,
    total: normalDora + akaDora + uraDora + nukiDora,
  };
}
