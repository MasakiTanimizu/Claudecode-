// FlowerState / SeasonTileState (spec section 41): tracks which flower
// tiles each player has extracted this hand.

export function createFlowerState(playerCount = 3) {
  return {
    drawnBySeat: Array.from({ length: playerCount }, () => []),
  };
}
