// DiceEngine: secure dice rolls, used by 出目金 (spec section 35). Uses
// Web Crypto like Wall.js's shuffle, rather than Math.random, so a
// server-authoritative deployment (spec section 52-53) can't have its
// roll predicted or biased by a client.

export function rollDice(sides = 6) {
  const bytes = new Uint32Array(1);
  crypto.getRandomValues(bytes);
  return (bytes[0] % sides) + 1;
}
