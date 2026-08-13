// PlayerState (spec section 41).
//
// Score is deliberately not tracked here — it lives in ScoreState
// (GameState.score, one array indexed by seat) per spec section 12/41's
// separation of Score/Chip/RankPoint/Bonus into independent state
// slices. Keeping a second copy on PlayerState invites the two to drift
// out of sync (see TurnEngine.declareRiichi's history).

export function createPlayerState(seat, { isDealer = false } = {}) {
  return {
    seat, // 0 = East, 1 = South, 2 = West
    isDealer,
    hand: [],
    discards: [],
    melds: [], // { type: 'chi' | 'pon' | 'kan', tiles, calledFrom, concealed }
    kitaTiles: [],
    flowerTiles: [],
    // Base (1x) hana chips already paid out this hand at extraction
    // time (spec section 29) — tracked so a later shuba win can top it
    // up to the multiplied amount without double-paying the base.
    hanaChipsThisHand: 0,
    riichi: {
      active: false,
      open: false, // OpenRiichiState: hand revealed at declaration
      furo: false, // FuroRiichiState: riichi declared with melds on the table
      ippatsu: false,
      declaredAtTurn: null,
    },
    furiten: false,
    temporaryFuriten: false,
  };
}

export function isMenzen(player) {
  return player.melds.every((m) => m.type === 'kan' && m.concealed);
}
