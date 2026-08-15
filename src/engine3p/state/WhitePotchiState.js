// WhitePotchiState (白ポッチ, spec section 17): tracks whether a player
// has revealed the haku-potchi tile while in riichi, which makes its
// special effect permanently active for the rest of the hand.
//
// The user has explicitly shelved the "チューリップとして扱う" win-value
// rule for now (revealedBySeat/activeBySeat exist for whenever that
// rule comes back, but nothing currently reads activeBySeat for
// scoring). immediateBySeat ("即白ポッチ") stays live and in use — it's
// one of DemekinRule's four trigger conditions (spec section 35),
// independent of the shelved tulip mechanic.

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
