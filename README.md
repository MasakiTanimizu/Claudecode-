# 三人麻雀 - チューリップ祝儀ルール

A custom three-player mahjong game (React + Vite) with house rules: no man
suit, extra 7p/7s tiles, a "Tulip" bonus-chip mechanic on riichi wins, and a
few other original rules. Open the in-app "ルール確認" panel for the full
list of implementation decisions.

## Development

```bash
npm install
npm run dev      # start the dev server
npm run build    # production build
npm run preview  # preview the production build
```

## Sanma rules engine (`src/engine3p/`)

A separate, much more extensive 3-player rules engine (custom house
rules, chip/celebration currency, CPU AI, WebSocket multiplayer) is
under active development in `src/engine3p/` and `server/`, independent
of the React app above. See:

- `docs/DESIGN_3P_ONLINE.md` — architecture and every confirmed rule
  decision, in the order they were made
- `docs/UNITY_INTEGRATION.md` — the WebSocket server + Unity client
  protocol for playing 1-human-vs-2-CPU locally

```bash
npm test          # run the engine's unit test suite (vitest)
npm run server     # start the local CPU-battle WebSocket server
```
