// Central source of tunable numbers for the 3-player ruleset (spec section 58).
// Nothing in the engine should hardcode these values directly.

const HAKU_POTCHI_COUNT = 1;

export const DEFAULT_RULE_CONFIG = {
  RULE_NORTH_COUNT: 4,
  RULE_FLOWER_COUNT: 4,
  RULE_DORA_DISPLAY_COUNT: 2,
  RULE_DEAD_WALL_SIZE: 14,

  RULE_HONBA_RON: 2000,
  RULE_HONBA_TSUMO: 1000,
  RULE_NOTEN_POOL: 2000,

  RULE_RIICHI_STICK: 1000,
  RULE_SHURABA_HONBA_STEP: 1,

  RULE_OPEN_RIICHI_HAN: 2,
  RULE_FURO_RIICHI_HAN: 0,

  // House rule: chi is removed entirely. Pon and kan (open/daiminkan)
  // share equal call priority; ron always outranks both.
  RULE_CHI_ENABLED: false,
  RULE_PON_KAN_EQUAL_PRIORITY: true,

  RULE_ALICE_CHIP: 1,

  RULE_SHUBA_MULTIPLIER: 2,
  RULE_SHUBA_ZOMA_MULTIPLIER: 3,
  RULE_SHUBANTE_MULTIPLIER: 10,
  RULE_SHUBA_STICK_VALUE: 100,
  RULE_SHUBANTE_MIN_EXTRA: 60000,
  RULE_SHUBA_ZOMA_EXTRA: 10000,

  RULE_CHIP_VALUES: {
    ippatsu: 1,
    uradora: 1,
    kita: 1,
    alice: 1,
    red: 3,
    kinsei: 3,
    triple: 3,
    daikinsei: 5,
    countedYakuman: 5,
    countedYakumanNatsu: 8,
    pureYakuman: 10,
    tobashi: 10,
    pureYakumanNatsu: 15,
    fourFlowerFourNorth: 50,
  },

  // Which physical copies of which tiles are red/blue/potchi variants.
  // Configurable per spec section 5 ("設定ファイルから変更できる設計") and
  // section 17 (白ポッチ — one of the 4 haku tiles).
  RULE_SPECIAL_TILE_MAP: [
    { suit: 'p', rank: 5, variant: 'red', count: 1 },
    { suit: 'p', rank: 5, variant: 'blue', count: 1 },
    { suit: 's', rank: 5, variant: 'red', count: 1 },
    { suit: 's', rank: 5, variant: 'blue', count: 1 },
    { suit: 'z', rank: 5, variant: 'potchi', count: HAKU_POTCHI_COUNT },
  ],

  RULE_HAKU_POTCHI_COUNT: HAKU_POTCHI_COUNT,

  RULE_STARTING_SCORE: 35000,

  // Denominations available for converting an integer score into a
  // physical stick display (section 13). Special high sticks are listed
  // alongside the standard ones so the greedy conversion covers any score.
  RULE_SCORE_UNITS: [
    { value: 100000, count: 10, special: true },
    { value: 90000, count: 6, special: true },
    { value: 80000, count: 4, special: true },
    { value: 10000, count: Infinity, special: false },
    { value: 5000, count: Infinity, special: false },
    { value: 1000, count: Infinity, special: false },
    { value: 100, count: Infinity, special: false },
  ],
};

export function createRuleConfig(overrides = {}) {
  return { ...DEFAULT_RULE_CONFIG, ...overrides, RULE_CHIP_VALUES: {
    ...DEFAULT_RULE_CONFIG.RULE_CHIP_VALUES,
    ...(overrides.RULE_CHIP_VALUES ?? {}),
  } };
}
