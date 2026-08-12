// PlayerState (spec section 41).

export function createPlayerState(seat, { isDealer = false, score } = {}) {
  return {
    seat, // 0 = East, 1 = South, 2 = West
    isDealer,
    score,
    hand: [],
    discards: [],
    melds: [], // { type: 'chi' | 'pon' | 'kan', tiles, calledFrom, concealed }
    kitaTiles: [],
    flowerTiles: [],
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
