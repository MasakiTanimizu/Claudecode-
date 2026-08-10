/// CPU difficulty tiers (STEP8「難易度別パラメータ」), directly aligned with
/// the difficulty=rate mapping from docs/design/03 (簡単0.5 / 中100 / 難200)
/// — this is the one enum every other `ai/` module parameterizes on.
library;

enum CpuDifficulty { beginner, intermediate, advanced }
