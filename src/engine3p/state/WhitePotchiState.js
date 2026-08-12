// WhitePotchiState (白ポッチ, spec section 17): tracks whether a player
// has revealed the haku-potchi tile while in riichi, which makes its
// special effect permanently active for the rest of the hand.
//
// The exact scoring value of a haku-potchi win ("チューリップとして扱う",
// "即白ポッチは出目金の対象") is not specified precisely enough to
// implement safely yet — this module only tracks the structural
// reveal/active state; the win-value hook is a documented TODO for a
// later phase, the same pattern used for Alice/Shuba in Phase 1.

export function createWhitePotchiState(playerCount = 3) {
  return {
    revealedBySeat: Array.from({ length: playerCount }, () => false),
    activeBySeat: Array.from({ length: playerCount }, () => false),
    immediateBySeat: Array.from({ length: playerCount }, () => false), // 即白ポッチ: drawn before any riichi this hand
  };
}

// Call whenever a haku tile is drawn/revealed into a player's hand.
// `riichiActive` is that player's riichi state at the moment of the draw.
export function markHakuPotchiIfDrawn(state, seat, tile, { riichiActive, riichiEverDeclared }) {
  if (tile.suit !== 'z' || tile.rank !== 5 || tile.variant !== 'potchi') return state;
  const revealedBySeat = [...state.revealedBySeat];
  const activeBySeat = [...state.activeBySeat];
  const immediateBySeat = [...state.immediateBySeat];
  revealedBySeat[seat] = true;
  if (riichiActive) activeBySeat[seat] = true;
  if (!riichiEverDeclared) immediateBySeat[seat] = true; // 即白ポッチ
  return { revealedBySeat, activeBySeat, immediateBySeat };
}
