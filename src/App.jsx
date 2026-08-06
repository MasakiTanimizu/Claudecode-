import React, { useState, useEffect, useRef, useCallback } from "react";

/* =========================================================================
   カスタム三人麻雀 — チューリップ祝儀ルール版
   ---------------------------------------------------------------------
   ※実装上の解釈(あいまいなルールをどう実装したか)は画面右上の
     「ルール確認」パネルに明記しています。プレイしながら確認してください。
   ========================================================================= */

/* ----------------------------- 牌の定義 ----------------------------- */
// man: 萬子は1〜9すべて廃止(このゲームには萬子が存在しない)
// 1m/9mの代替として7p・7sを8枚ずつ採用
// pin: 1p-9p、7pは追加4枚で計8枚
// sou: 1s-9s、7sは追加4枚で計8枚
// 5s,5p は各2枚が赤(0s,0p)
// honors: E S W N P(白) F(發) C(中)
// flowers: H1-H4(花牌、手牌構成に参加しない)

const MAN = [2, 3, 4, 5, 6, 7, 8];
const NUM_SUITS = ["p", "s"]; // 1-9のあるスート
const ALL_TILE_CODES = [
  ...["p", "s"].flatMap((s) => [1, 2, 3, 4, 5, 6, 7, 8, 9].map((n) => `${n}${s}`)),
  "E", "S", "W", "N", "P", "F", "C",
];

// 牌ごとの枚数テーブル(1p-9p, 1s-9s とも7だけ8枚、他は4枚。5は赤2枚を含む)
const SUIT_COUNTS = { 1: 4, 2: 4, 3: 4, 4: 4, 5: 4, 6: 4, 7: 8, 8: 4, 9: 4 };

function buildWall() {
  const tiles = [];
  NUM_SUITS.forEach((suit) => {
    for (let n = 1; n <= 9; n++) {
      const copies = SUIT_COUNTS[n];
      for (let i = 0; i < copies; i++) {
        if (n === 5 && i < 2) tiles.push(`0${suit}`); // 赤5、2枚
        else tiles.push(`${n}${suit}`);
      }
    }
  });
  ["E", "S", "W", "N", "P", "F", "C"].forEach((h) => {
    for (let i = 0; i < 4; i++) {
      if (h === "P" && i === 0) tiles.push("K");
      else tiles.push(h);
    }
  });
  for (let i = 1; i <= 4; i++) tiles.push(`H${i}`);
  return tiles;
}

function shuffle(arr) {
  const a = arr.slice();
  for (let i = a.length - 1; i > 0; i--) {
    const j = Math.floor(Math.random() * (i + 1));
    [a[i], a[j]] = [a[j], a[i]];
  }
  return a;
}

function isFlower(t) {
  return t[0] === "H";
}
function isHonor(t) {
  return ["E", "S", "W", "N", "P", "F", "C", "K"].includes(t);
}
function isRed(t) {
  return t[0] === "0";
}
function baseNum(t) {
  if (isHonor(t) || isFlower(t)) return null;
  return t[0] === "0" ? 5 : parseInt(t[0], 10);
}
function suitOf(t) {
  if (isHonor(t) || isFlower(t)) return t[0] === "H" ? "h" : "z";
  return t[1];
}
function normTile(t) {
  if (isRed(t)) return `5${t[1]}`;
  if (t === "K") return "P";
  return t;
}

const TILE_LABEL = {
  P: "白", F: "發", C: "中", E: "東", S: "南", W: "西", N: "北", K: "白",
};
function tileMeta(t) {
  if (isFlower(t)) {
    return { main: "🌸", sub: "花", bg: "#fbe4f0", fg: "#8a2d5c", border: "#e5a9c6" };
  }
  if (isHonor(t)) {
    const isDragon = ["P", "F", "C"].includes(t);
    return {
      main: TILE_LABEL[t],
      sub: isDragon ? "字牌" : "風牌",
      bg: t === "P" ? "#fdfdfb" : "#fdeec9",
      fg: t === "P" ? "#8a8a72" : t === "C" ? "#b0262c" : t === "F" ? "#1f6b3a" : "#3a2c12",
      border: "#e0c383",
    };
  }
  const n = baseNum(t);
  const suit = suitOf(t);
  const suitLabel = suit === "m" ? "萬" : suit === "p" ? "筒" : "索";
  const palette = {
    m: { bg: "#eef7ee", fg: "#1f5c33", border: "#bfe0c4" },
    p: { bg: "#eaf3fb", fg: "#1e5488", border: "#bcd8ee" },
    s: { bg: "#fdf1e6", fg: "#9a4a12", border: "#f0cda1" },
  }[suit];
  const red = isRed(t);
  return {
    main: String(n),
    sub: suitLabel,
    bg: palette.bg,
    fg: red ? "#c22222" : palette.fg,
    border: red ? "#e79a9a" : palette.border,
    red,
  };
}
function tileText(t) {
  if (isFlower(t)) return `花${t[1]}`;
  if (t === "K") return "白ポッチ";
  if (TILE_LABEL[t]) return TILE_LABEL[t];
  const n = t[0] === "0" ? "0" : t[0];
  const suit = t[1] === "m" ? "萬" : t[1] === "p" ? "筒" : "索";
  return `${n}${suit}`;
}

const MAN_KANJI = { 2: "二", 3: "三", 4: "四", 5: "五", 6: "六", 7: "七", 8: "八" };

const PIN_BLUE = "#1c5fc0";
const WHEEL_RED = "#c0272d";
const SOU_GREEN = "#1a7a45";

function PinWheel({ cx, cy, r, color }) {
  const angles = [0, 60, 120];
  return (
    <g transform={`translate(${cx}, ${cy})`}>
      <circle r={r} fill="#161616" />
      <circle r={r * 0.84} fill={color} />
      <g stroke="#ffffff" strokeWidth={r * 0.15} strokeLinecap="round">
        {angles.map((a) => (
          <line key={a} x1={-r * 0.64} y1={0} x2={r * 0.64} y2={0} transform={`rotate(${a})`} />
        ))}
      </g>
      <g fill="#ffffff">
        {angles.flatMap((a) => [a, a + 180]).map((a) => (
          <circle key={a} cx={r * 0.64} cy={0} r={r * 0.1} transform={`rotate(${a})`} />
        ))}
      </g>
      <circle r={r * 0.28} fill="#161616" />
      <circle r={r * 0.28} fill="none" stroke={color} strokeWidth={r * 0.08} />
    </g>
  );
}

function PinFlower({ w, h }) {
  const size = Math.min(w, h) * 0.96;
  return (
    <svg width={size} height={size} viewBox="0 0 100 100">
      <circle cx="50" cy="50" r="47" fill="#20242c" />
      <circle
        cx="50" cy="50" r="38" fill="none" stroke="#fdfdfb" strokeWidth="13"
        strokeDasharray="9 6.2"
      />
      <circle cx="50" cy="50" r="29" fill="#20242c" />
      <PinWheel cx={50} cy={50} r={25} color={WHEEL_RED} />
    </svg>
  );
}

function BambooStick({ cx, cy, s, color }) {
  const w = s * 0.66, h = s;
  const rx = w * 0.5, ry = w * 0.42;
  return (
    <g transform={`translate(${cx - w / 2}, ${cy - h / 2})`}>
      <rect x={w * 0.22} y={ry * 0.5} width={w * 0.56} height={h - ry} fill={color} />
      <ellipse cx={w / 2} cy={ry * 0.85} rx={rx} ry={ry} fill={color} />
      <ellipse cx={w / 2} cy={h - ry * 0.85} rx={rx} ry={ry} fill={color} />
      <rect x={w * 0.22} y={h * 0.36} width={w * 0.56} height={h * 0.09} fill="#ffffff" />
      <rect x={w * 0.22} y={h * 0.62} width={w * 0.56} height={h * 0.09} fill="#ffffff" />
    </g>
  );
}

function SouBird({ w, h }) {
  const size = Math.min(w, h) * 0.9;
  return (
    <svg width={size} height={size} viewBox="0 0 100 100">
      <ellipse cx="50" cy="78" rx="10" ry="5" fill={SOU_GREEN} opacity="0.5" />
      <path d="M50 82 C 50 55, 30 50, 26 22 C 42 34, 50 46, 50 60 C 50 46, 58 34, 74 22 C 70 50, 50 55, 50 82 Z" fill={SOU_GREEN} />
      <path d="M50 82 C 50 60, 40 52, 34 34 C 46 42, 50 52, 50 62 Z" fill="#14713d" />
      <circle cx="50" cy="24" r="7" fill={WHEEL_RED} />
    </svg>
  );
}

const PIN_LAYOUT = {
  2: { r: 15, pts: [[50, 26, "b"], [50, 74, "b"]] },
  3: { r: 14, pts: [[50, 16, "b"], [50, 50, "r"], [50, 84, "b"]] },
  4: { r: 15, pts: [[30, 28, "b"], [70, 28, "b"], [30, 72, "b"], [70, 72, "b"]] },
  5: { r: 14, pts: [[28, 24, "b"], [72, 24, "b"], [50, 50, "r"], [28, 76, "b"], [72, 76, "b"]] },
  6: { r: 13.5, pts: [[35, 20, "b"], [65, 20, "b"], [32, 56, "r"], [68, 56, "r"], [32, 84, "r"], [68, 84, "r"]] },
  7: { r: 13, pts: [[28, 18, "b"], [50, 33, "b"], [72, 48, "b"], [34, 65, "r"], [66, 65, "r"], [34, 90, "r"], [66, 90, "r"]] },
  8: { r: 12, pts: [[32, 13, "b"], [68, 13, "b"], [32, 38, "b"], [68, 38, "b"], [32, 63, "b"], [68, 63, "b"], [32, 88, "b"], [68, 88, "b"]] },
  9: {
    r: 12.5,
    pts: [
      [25, 18, "b"], [50, 18, "r"], [75, 18, "b"],
      [25, 50, "b"], [50, 50, "r"], [75, 50, "b"],
      [25, 82, "b"], [50, 82, "r"], [75, 82, "b"],
    ],
  },
};
const SOU_LAYOUT = {
  2: { s: 30, pts: [[50, 26, "g"], [50, 74, "g"]] },
  3: { s: 27, pts: [[50, 20, "g"], [30, 75, "g"], [70, 75, "g"]] },
  4: { s: 26, pts: [[30, 28, "g"], [70, 28, "g"], [30, 72, "g"], [70, 72, "g"]] },
  5: { s: 24, pts: [[28, 24, "g"], [72, 24, "g"], [50, 50, "r"], [28, 76, "g"], [72, 76, "g"]] },
  6: { s: 24, pts: [[32, 20, "g"], [68, 20, "g"], [32, 50, "g"], [68, 50, "g"], [32, 80, "g"], [68, 80, "g"]] },
  7: { s: 22, pts: [[50, 15, "r"], [24, 46, "g"], [50, 46, "g"], [76, 46, "g"], [24, 80, "g"], [50, 80, "g"], [76, 80, "g"]] },
  8: {
    s: 21,
    pts: [
      [15, 25, "g"], [38, 25, "g"], [62, 25, "g"], [85, 25, "g"],
      [15, 75, "g"], [38, 75, "g"], [62, 75, "g"], [85, 75, "g"],
    ],
    cross: true,
  },
  9: {
    s: 19,
    pts: [
      [25, 18, "g"], [50, 18, "r"], [75, 18, "g"],
      [25, 50, "g"], [50, 50, "r"], [75, 50, "g"],
      [25, 82, "g"], [50, 82, "r"], [75, 82, "g"],
    ],
  },
};

function PinTileArt({ n, w, h, isAka }) {
  if (n === 1) return <PinFlower w={w} h={h} />;
  const layout = PIN_LAYOUT[n];
  const size = Math.min(w, h) * 0.98;
  return (
    <svg width={size} height={size} viewBox="0 0 100 100">
      {layout.pts.map(([cx, cy, c], i) => (
        <PinWheel key={i} cx={cx} cy={cy} r={layout.r} color={isAka || c === "r" ? WHEEL_RED : PIN_BLUE} />
      ))}
    </svg>
  );
}

function SouTileArt({ n, w, h, isAka }) {
  if (n === 1) return <SouBird w={w} h={h} />;
  const layout = SOU_LAYOUT[n];
  const size = Math.min(w, h) * 0.98;
  return (
    <svg width={size} height={size} viewBox="0 0 100 100">
      {layout.cross && (
        <g stroke={SOU_GREEN} strokeWidth="3.2" opacity="0.9">
          <line x1={26} y1={25} x2={50} y2={38} />
          <line x1={50} y1={38} x2={38} y2={25} />
          <line x1={62} y1={25} x2={86} y2={38} />
          <line x1={86} y1={25} x2={74} y2={38} />
          <line x1={26} y1={75} x2={50} y2={62} />
          <line x1={50} y1={62} x2={38} y2={75} />
          <line x1={62} y1={75} x2={86} y2={62} />
          <line x1={86} y1={75} x2={74} y2={62} />
        </g>
      )}
      {layout.pts.map(([cx, cy, c], i) => (
        <BambooStick key={i} cx={cx} cy={cy} s={layout.s} color={isAka || c === "r" ? WHEEL_RED : SOU_GREEN} />
      ))}
    </svg>
  );
}

function TileFace({ tile, w, h }) {
  if (isFlower(tile)) {
    return <span style={{ fontSize: h * 0.56 }}>🌸</span>;
  }
  if (isHonor(tile)) {
    if (tile === "P") {
      return <div style={{ width: 1, height: 1 }} />;
    }
    if (tile === "K") {
      return <div style={{ width: h * 0.16, height: h * 0.16, borderRadius: "50%", background: "#c0272d", boxShadow: "0 0 0 1.5px #20242c55" }} />;
    }
    const color = tile === "C" ? "#c0272d" : tile === "F" ? "#1f8a4c" : "#232830";
    return <span style={{ fontSize: h * 0.54, fontWeight: 800, color, textShadow: "0 1px 0 #ffffff80" }}>{TILE_LABEL[tile]}</span>;
  }
  const n = baseNum(tile);
  const suit = suitOf(tile);
  const red = isRed(tile);
  if (suit === "m") {
    return (
      <div style={{ display: "flex", flexDirection: "column", alignItems: "center", lineHeight: 1 }}>
        <span style={{ fontSize: h * 0.4, fontWeight: 800, color: red ? "#c0392b" : "#151b2e", fontFamily: "'Hiragino Mincho ProN', serif" }}>{MAN_KANJI[n]}</span>
        <span style={{ fontSize: h * 0.28, fontWeight: 700, color: "#c0272d", marginTop: h * 0.02, fontFamily: "'Hiragino Mincho ProN', serif" }}>萬</span>
      </div>
    );
  }
  if (suit === "p") return <PinTileArt n={n} w={w} h={h} isAka={red} />;
  return <SouTileArt n={n} w={w} h={h} isAka={red} />;
}

function MahjongTile({ tile, size = "lg", width, height, onClick, selected, faded, glow, rotateDeg = 0 }) {
  const preset = size === "lg" ? { w: 40, h: 54 } : size === "md" ? { w: 30, h: 40 } : { w: 20, h: 27 };
  const w = width || preset.w;
  const h = height || preset.h;
  const bevel = Math.max(2, h * 0.1);
  const isRotated = ((rotateDeg % 180) + 180) % 180 !== 0;
  const outerW = isRotated ? h : w;
  const outerH = isRotated ? w : h;
  return (
    <div
      onClick={onClick}
      style={{
        width: outerW,
        height: outerH,
        display: "flex",
        alignItems: "center",
        justifyContent: "center",
        flexShrink: 0,
        cursor: onClick ? "pointer" : "default",
      }}
    >
      <div
        style={{
          position: "relative",
          width: w,
          height: h,
          background: "linear-gradient(180deg,#ffffff,#eef1f4)",
          border: "1px solid #cfd4dc",
          borderBottom: `${bevel}px solid #c3c9d3`,
          borderRadius: Math.max(3, w * 0.16),
          display: "flex",
          alignItems: "center",
          justifyContent: "center",
          boxShadow: selected ? "0 0 0 2px #e3b968, 0 8px 16px #0007" : "0 1px 2px #0003, 0 2px 6px #0004, 0 0 0 1px rgba(79,214,255,0.12)",
          transform: isRotated ? `rotate(${rotateDeg}deg)` : selected ? "translateY(-8px)" : glow ? "translateY(-2px)" : "none",
          outline: glow ? "2px solid #e3b968" : isRotated ? "2px solid #ff8a3d" : "none",
          opacity: faded ? 0.55 : 1,
          userSelect: "none",
          overflow: "hidden",
        }}
      >
        <div style={{ position: "absolute", inset: 0, background: "linear-gradient(180deg, rgba(255,255,255,0.75), rgba(255,255,255,0) 42%)", pointerEvents: "none" }} />
        <TileFace tile={tile} w={w} h={h} />
        {!isHonor(tile) && !isFlower(tile) && (
          <span
            style={{
              position: "absolute", top: h * 0.03, left: w * 0.07, fontSize: Math.max(6, w * 0.24), fontWeight: 800,
              color: isRed(tile) ? "#c0272d" : "#00000075", lineHeight: 1, pointerEvents: "none",
              fontFamily: "'Hiragino Sans', sans-serif",
            }}
          >
            {baseNum(tile)}
          </span>
        )}
      </div>
    </div>
  );
}

function meldCallSide(who, from) {
  if (from === undefined || from === null || from === who) return null;
  const kamicha = (who - 1 + 3) % 3;
  const shimocha = (who + 1) % 3;
  if (from === kamicha) return "left";
  if (from === shimocha) return "right";
  return null;
}
function MeldGroup({ meld, who, size = "sm" }) {
  const count = meld.type.includes("kan") ? 4 : 3;
  const side = meldCallSide(who, meld.from);
  return (
    <div style={{ display: "flex", alignItems: "flex-end", gap: 1 }}>
      {Array.from({ length: count }).map((_, i) => {
        const isSourceTile = side === "left" ? i === 0 : side === "right" ? i === count - 1 : false;
        return <MahjongTile key={i} tile={meld.tile} size={size} rotateDeg={isSourceTile ? 90 : 0} />;
      })}
    </div>
  );
}

function BackTile({ size = "sm" }) {
  const dim = size === "md" ? { w: 22, h: 30 } : { w: 16, h: 22 };
  return (
    <div
      style={{
        width: dim.w,
        height: dim.h,
        background: "linear-gradient(155deg,#4a7fda,#2a4fa0)",
        border: "1px solid #1c3a80cc",
        borderBottom: `${Math.max(2, dim.h * 0.12)}px solid #1c3a80`,
        borderRadius: 4,
        flexShrink: 0,
      }}
    />
  );
}

/* ----------------------- チューリップ:隣接牌計算 ----------------------- */
const WIND_CYCLE = ["E", "S", "W", "N"];
const DRAGON_CYCLE = ["P", "F", "C"];

function neighborsOf(indicatorTile) {
  if (isFlower(indicatorTile)) return [];
  if (isHonor(indicatorTile)) {
    if (WIND_CYCLE.includes(indicatorTile)) {
      const i = WIND_CYCLE.indexOf(indicatorTile);
      return [
        WIND_CYCLE[(i + 1) % 4],
        WIND_CYCLE[(i + 3) % 4],
      ];
    } else {
      const i = DRAGON_CYCLE.indexOf(indicatorTile);
      return [DRAGON_CYCLE[(i + 1) % 3], DRAGON_CYCLE[(i + 2) % 3]];
    }
  }
  const n = baseNum(indicatorTile);
  const suit = suitOf(indicatorTile);
  const prev = n === 1 ? 9 : n - 1;
  const next = n === 9 ? 1 : n + 1;
  return [`${prev}${suit}`, `${next}${suit}`];
}

/* ----------------------------- 手牌形状判定 ----------------------------- */
function toCounts(tiles) {
  const c = {};
  tiles.forEach((t) => {
    const n = normTile(t);
    c[n] = (c[n] || 0) + 1;
  });
  return c;
}

function isAgariShape(counts, needSets, noSeq) {
  const keys = Object.keys(counts).filter((k) => counts[k] > 0);
  if (keys.length === 0) return needSets === 0;
  for (const k of keys) {
    if (counts[k] >= 2) {
      const c2 = { ...counts, [k]: counts[k] - 2 };
      if (tryDecompose(c2, needSets, noSeq)) return true;
    }
  }
  return false;
}

function tryDecompose(counts, needSets, noSeq) {
  const total = Object.values(counts).reduce((a, b) => a + b, 0);
  if (needSets === 0) return total === 0;
  if (total === 0) return needSets === 0;
  const keys = Object.keys(counts).filter((k) => counts[k] > 0).sort();
  const k = keys[0];
  const isHon = isHonor(k) || k[0] === "H";
  if (counts[k] >= 3) {
    const c2 = { ...counts, [k]: counts[k] - 3 };
    if (tryDecompose(c2, needSets - 1, noSeq)) return true;
  }
  if (!isHon && !noSeq) {
    const n = parseInt(k[0], 10);
    const suit = k[1];
    if (n <= 7) {
      const k2 = `${n + 1}${suit}`;
      const k3 = `${n + 2}${suit}`;
      if ((counts[k2] || 0) > 0 && (counts[k3] || 0) > 0) {
        const c2 = { ...counts };
        c2[k] -= 1;
        c2[k2] -= 1;
        c2[k3] -= 1;
        if (tryDecompose(c2, needSets - 1, noSeq)) return true;
      }
    }
  }
  return false;
}

function isChiitoi(tiles) {
  if (tiles.length !== 14) return false;
  const c = toCounts(tiles);
  const keys = Object.keys(c);
  if (keys.length !== 7) return false;
  return keys.every((k) => c[k] === 2);
}

function countSeven(tiles, suit) {
  return tiles.filter((t) => t === `7${suit}`).length;
}

const KOKUSHI_TILES = ["1p", "9p", "1s", "9s", "E", "S", "W", "N", "P", "F", "C", "7p", "7s"];
function isSevenShiMusou(tiles) {
  if (tiles.length !== 14) return false;
  const counts = toCounts(tiles);
  const keys = Object.keys(counts);
  if (!keys.every((k) => KOKUSHI_TILES.includes(k))) return false;
  if (!KOKUSHI_TILES.every((k) => (counts[k] || 0) >= 1)) return false;
  const total = Object.values(counts).reduce((a, b) => a + b, 0);
  return total === 14;
}

function findAnkanTiles(hand) {
  const counts = toCounts(hand);
  return Object.keys(counts).filter((k) => counts[k] === 4 && k[0] !== "H");
}
function findKakanTiles(hand, melds) {
  const ponTiles = melds.filter((m) => m.type === "pon").map((m) => m.tile);
  return ponTiles.filter((t) => hand.some((h) => normTile(h) === t));
}

/* ----------------------------- 役判定(簡易) ----------------------------- */
function countTilesUsed(tiles, code) {
  return tiles.filter((t) => normTile(t) === code).length;
}

function detectYaku({
  handTiles,
  winTile,
  isTsumo,
  melds,
  riichi,
  ippatsu,
  doraIndicators,
  uraIndicators,
  seatWind,
  isSevenShi,
}) {
  const yaku = [];
  const allTiles = [...handTiles, ...melds.flatMap((m) => Array(m.type.includes("kan") ? 4 : 3).fill(m.tile))];
  const isMenzen = melds.every((m) => m.type === "ankan");

  if (isSevenShi) {
    yaku.push({ name: "七士無双", han: 13, yakuman: true });
    return yaku;
  }

  if (riichi) yaku.push({ name: "立直", han: 1 });
  if (ippatsu) yaku.push({ name: "一発", han: 1 });
  if (isTsumo && isMenzen) yaku.push({ name: "門前清自摸和", han: 1 });

  const hasTerminalOrHonor = allTiles.some((t) => {
    if (isHonor(t)) return true;
    const n = baseNum(t);
    return n === 1 || n === 9;
  });
  if (!hasTerminalOrHonor) yaku.push({ name: "断幺九", han: 1 });

  ["P", "F", "C", "N"].forEach((h) => {
    const cnt = countTilesUsed(allTiles, h);
    if (cnt >= 3) yaku.push({ name: `役牌(${tileText(h)})`, han: 1 });
  });
  if (seatWind && countTilesUsed(allTiles, seatWind) >= 3) {
    yaku.push({ name: `役牌(自風 ${tileText(seatWind)})`, han: 1 });
  }

  const counts = toCounts(allTiles);
  const concealedNeedSets = 4 - melds.length;
  const concealedCounts = toCounts(handTiles);
  const groupsAreAllTriplets = isAgariShape(concealedCounts, concealedNeedSets, true);
  if (groupsAreAllTriplets) yaku.push({ name: "対々和", han: 2 });

  const suits = new Set(allTiles.filter((t) => !isHonor(t)).map((t) => suitOf(t)));
  const hasHonorTile = allTiles.some((t) => isHonor(t));
  if (suits.size === 1) {
    if (hasHonorTile) yaku.push({ name: "混一色", han: isMenzen ? 2 : 1 });
    else yaku.push({ name: "清一色", han: isMenzen ? 5 : 4 });
  }

  if (melds.length === 0 && isChiitoi(handTiles)) {
    yaku.push({ name: "七対子", han: 2 });
  }

  let doraCount = 0;
  doraIndicators.forEach((ind) => {
    const [d] = neighborsNext(ind);
    doraCount += countTilesUsed(allTiles, d);
  });
  if (riichi) {
    uraIndicators.forEach((ind) => {
      const [d] = neighborsNext(ind);
      doraCount += countTilesUsed(allTiles, d);
    });
  }
  const redCount = allTiles.filter((t) => isRed(t)).length;
  if (doraCount > 0) yaku.push({ name: "ドラ", han: doraCount, dora: true });
  if (redCount > 0) yaku.push({ name: "赤ドラ", han: redCount, dora: true });

  return yaku;
}

function neighborsNext(indicator) {
  if (isHonor(indicator)) {
    if (WIND_CYCLE.includes(indicator)) {
      const i = WIND_CYCLE.indexOf(indicator);
      return [WIND_CYCLE[(i + 1) % 4]];
    }
    const i = DRAGON_CYCLE.indexOf(indicator);
    return [DRAGON_CYCLE[(i + 1) % 3]];
  }
  const n = baseNum(indicator);
  const suit = suitOf(indicator);
  const next = n === 9 ? 1 : n + 1;
  return [`${next}${suit}`];
}

function hanToChipsScore(han, isDealer, isTsumo) {
  const table = {
    4: 8000, 5: 8000,
  };
  let base = han >= 6 && han <= 7 ? 12000 : han >= 8 && han <= 10 ? 16000 : han >= 11 && han <= 12 ? 24000 : han >= 13 ? 32000 : table[han] || 32000;
  if (isDealer) base = Math.round(base * 1.5 / 100) * 100;
  return base;
}

const FIXED_SCORE_TABLE = {
  dealer: {
    1: { ron: 2000, tsumoEach: 1000 },
    2: { ron: 4000, tsumoEach: 2000 },
    3: { ron: 6000, tsumoEach: 3000 },
  },
  child: {
    1: { ron: 1000, tsumoChild: 1000, tsumoDealer: 1000 },
    2: { ron: 2000, tsumoChild: 1000, tsumoDealer: 1000 },
    3: { ron: 4000, tsumoChild: 1000, tsumoDealer: 3000 },
  },
};

/* ============================== 本体コンポーネント ============================== */

const SEATS = ["あなた", "CPU1", "CPU2"];
const WIND_NAMES = { E: "東", S: "南", W: "西" };
function seatWindOf(playerIdx, dealerIdx) {
  const order = ["E", "S", "W"];
  return order[(playerIdx - dealerIdx + 3) % 3];
}

function initialPlayers() {
  return SEATS.map((name, i) => ({
    name,
    score: 30000,
    chips: 0,
    hand: [],
    discards: [],
    melds: [],
    riichi: false,
    riichiDiscardIndex: null,
    ippatsuLive: false,
    isDealer: i === 0,
    flowers: [],
    marker: "manrui",
  }));
}

export default function MahjongApp() {
  const [players, setPlayers] = useState(initialPlayers());
  const [wall, setWall] = useState([]);
  const [deadWall, setDeadWall] = useState([]);
  const [doraIndicators, setDoraIndicators] = useState([]);
  const [uraIndicators, setUraIndicators] = useState([]);
  const [tulipPtr, setTulipPtr] = useState(2);
  const [dealerIdx, setDealerIdx] = useState(0);
  const [current, setCurrent] = useState(0);
  const [log, setLog] = useState([]);
  const [phase, setPhase] = useState("title");
  const [pendingDiscard, setPendingDiscard] = useState(null);
  const [callChoices, setCallChoices] = useState(null);
  const [kanPrompt, setKanPrompt] = useState(null);
  const [hakuChoice, setHakuChoice] = useState(null);
  const [splash, setSplash] = useState(null);
  const splashTimerRef = useRef(null);
  const showSplash = useCallback((text) => {
    if (splashTimerRef.current) clearTimeout(splashTimerRef.current);
    setSplash({ text, key: Date.now() });
    splashTimerRef.current = setTimeout(() => setSplash(null), 1100);
  }, []);
  const [selectedTileIdx, setSelectedTileIdx] = useState(null);
  const [resultInfo, setResultInfo] = useState(null);
  const [round, setRound] = useState(1);
  const [diceRoll, setDiceRoll] = useState([1, 1]);
  const [showRules, setShowRules] = useState(false);
  const [vw, setVw] = useState(typeof window !== "undefined" ? window.innerWidth : 800);
  const [vh, setVh] = useState(typeof window !== "undefined" ? window.innerHeight : 390);

  useEffect(() => {
    const onResize = () => {
      setVw(window.innerWidth);
      setVh(window.innerHeight);
    };
    window.addEventListener("resize", onResize);
    window.addEventListener("orientationchange", onResize);
    return () => {
      window.removeEventListener("resize", onResize);
      window.removeEventListener("orientationchange", onResize);
    };
  }, []);
  const [tulipLevel, setTulipLevel] = useState(0);
  const [drewTile, setDrewTile] = useState(null);
  const [riichiArmed, setRiichiArmed] = useState(false);
  const [firstDiscardTurn, setFirstDiscardTurn] = useState(true);
  const [anyoneCalled, setAnyoneCalled] = useState(false);

  const addLog = useCallback((msg) => {
    setLog((l) => [msg, ...l].slice(0, 60));
  }, []);

  useEffect(() => {
    if (current !== 0 || phase !== "playing" || drewTile === null) return;
    if (riichiArmed || kanPrompt) return;
    const me = players[0];
    const winNow = tryResolveWin(0, players, drewTile, true, me.melds);
    if (winNow && winNow.ok) return;
    const ankanOpts = findAnkanTiles(me.hand);
    const kakanOpts = findKakanTiles(me.hand, me.melds);
    if (ankanOpts.length > 0) {
      setKanPrompt({ type: "ankan", tile: ankanOpts[0] });
    } else if (kakanOpts.length > 0) {
      setKanPrompt({ type: "kakan", tile: kakanOpts[0] });
    } else if (me.riichi) {
      const t = setTimeout(() => doDiscard(0, players[0].hand.length - 1, players), 500);
      return () => clearTimeout(t);
    }
  }, [drewTile, current, phase]);

  /* ------------------------- 配牌 ------------------------- */
  function startHand(dealerI) {
    setDiceRoll([1 + Math.floor(Math.random() * 6), 1 + Math.floor(Math.random() * 6)]);
    const full = shuffle(buildWall());
    const dw = full.slice(0, 14);
    const live = full.slice(14);
    const ps = initialPlayers().map((p, i) => ({
      ...p,
      isDealer: i === dealerI,
      score: players[i]?.score ?? 30000,
      chips: players[i]?.chips ?? 0,
      marker: players[i]?.marker ?? "manrui",
    }));
    let idx = 0;
    for (let r = 0; r < 13; r++) {
      for (let p = 0; p < 3; p++) {
        ps[p].hand.push(live[idx]);
        idx++;
      }
    }
    for (let p = 0; p < 3; p++) {
      while (ps[p].hand.some(isFlower)) {
        const fi = ps[p].hand.findIndex(isFlower);
        const fl = ps[p].hand.splice(fi, 1)[0];
        ps[p].flowers.push(fl);
        ps[p].chips += 3;
        ps[p].hand.push(live[idx]);
        idx++;
      }
    }
    ps.forEach((p) => (p.hand = sortHand(p.hand)));
    const remainWall = live.slice(idx);
    setWall(remainWall);
    setDeadWall(dw);
    setDoraIndicators([dw[0]]);
    setUraIndicators([]);
    setTulipPtr(2);
    setTulipLevel(0);
    setPlayers(ps);
    setDealerIdx(dealerI);
    setCurrent(dealerI);
    setPhase("playing");
    setPendingDiscard(null);
    setCallChoices(null);
    setResultInfo(null);
    setFirstDiscardTurn(true);
    setRiichiArmed(false);
    setAnyoneCalled(false);
    setTimeout(() => drawForCurrent(dealerI, ps, remainWall, dw), 300);
  }

  function sortHand(hand) {
    const order = (t) => {
      if (isFlower(t)) return 900;
      if (isHonor(t)) return 500 + ["E", "S", "W", "N", "P", "F", "C"].indexOf(t);
      const suitOrd = { m: 0, p: 100, s: 200 };
      return suitOrd[t[1]] + baseNum(t);
    };
    return hand.slice().sort((a, b) => order(a) - order(b));
  }

  /* ------------------------- ツモ処理 ------------------------- */
  function drawForCurrent(who, ps, wallArr, dw) {
    if (wallArr.length === 0) {
      handleDraw(ps);
      return;
    }
    const tile = wallArr[0];
    const rest = wallArr.slice(1);
    let newPs = ps.map((p, i) => (i === who ? { ...p, hand: [...p.hand, tile] } : p));
    if (isFlower(tile)) {
      newPs = newPs.map((p, i) =>
        i === who ? { ...p, hand: p.hand.filter((t) => t !== tile), flowers: [...p.flowers, tile], chips: p.chips + 3 } : p
      );
      addLog(`${SEATS[who]} が花牌(${tileText(tile)})をツモ。祝儀+3`);
      setWall(rest);
      setPlayers(newPs);
      drawForCurrent(who, newPs, rest, dw);
      return;
    }
    setWall(rest);
    setDrewTile(tile);
    setSelectedTileIdx(null);
    newPs[who].hand = sortHandKeepLast(newPs[who].hand, tile);
    setPlayers(newPs);
    if (who !== 0) {
      setTimeout(() => aiTurn(who, newPs, rest), 600);
    }
  }

  function sortHandKeepLast(hand, last) {
    const withoutOne = hand.slice();
    const li = withoutOne.lastIndexOf(last);
    withoutOne.splice(li, 1);
    return [...sortHand(withoutOne), last];
  }

  function handleDraw(ps) {
    addLog("--- 牌山が尽きました(流局) ---");
    setPhase("result");
    setResultInfo({ type: "draw" });
  }

  /* ------------------------- 和了判定 ------------------------- */
  function canWin(hand, melds, winTile) {
    if (melds.length === 0 && isSevenShiMusou(hand)) {
      return { ok: true, isSevenShi: true };
    }
    if (melds.length === 0 && isChiitoi(hand)) return { ok: true, isSevenShi: false };
    const needSets = 4 - melds.length;
    const counts = toCounts(hand);
    const totalTiles = Object.values(counts).reduce((a, b) => a + b, 0);
    if (totalTiles !== needSets * 3 + 2) return { ok: false };
    if (isAgariShape(counts, needSets, false)) return { ok: true, isSevenShi: false };
    return { ok: false };
  }

  function tryResolveWin(playerIdx, ps, winTile, isTsumo, melds) {
    const p = ps[playerIdx];
    const hand = p.hand.slice();
    const testHand = isTsumo ? hand : [...hand, winTile];
    const res = canWin(testHand, melds, winTile);
    if (!res.ok) return null;
    if (res.isSevenShi) return res;
    const ippatsu = p.ippatsuLive && !p.melds.some((m) => m.type !== "ankan");
    const yaku = detectYaku({
      handTiles: testHand,
      winTile,
      isTsumo,
      melds,
      riichi: p.riichi,
      ippatsu,
      doraIndicators,
      uraIndicators: [],
      seatWind: seatWindOf(playerIdx, dealerIdx),
      isSevenShi: res.isSevenShi,
    });
    const realYakuHan = yaku.filter((y) => !y.dora).reduce((a, y) => a + y.han, 0);
    if (realYakuHan === 0) return null;
    return res;
  }

  /* ------------------------- 自分(人間)の操作 ------------------------- */
  function humanDiscard(idx) {
    if (phase !== "playing" || current !== 0) return;
    if (kanPrompt) return;
    if (riichiArmed) {
      const after = players[0].hand.slice();
      after.splice(idx, 1);
      if (!isTenpaiHand(after, players[0].melds)) {
        addLog("その牌を切るとテンパイが崩れるため、リーチできません");
        return;
      }
      const np = players.map((p, i) =>
        i === 0 ? { ...p, riichi: true, score: p.score - 1000, ippatsuLive: true } : p
      );
      setPlayers(np);
      setRiichiArmed(false);
      addLog("あなたが立直!");
      doDiscard(0, idx, np, true);
      return;
    }
    doDiscard(0, idx, players);
  }

  function humanTsumo() {
    const ps = players;
    const res = tryResolveWin(0, ps, drewTile, true, ps[0].melds);
    if (!res) {
      addLog("和了形になっていません");
      return;
    }
    resolveWin(0, drewTile, true, res, ps);
  }

  function humanTsumoHaku() {
    const hand13 = players[0].hand.slice(0, -1);
    const waits = computeWaits(hand13, players[0].melds);
    if (waits.length === 0) {
      addLog("白ポッチで和了できる形になっていません");
      return;
    }
    if (waits.length === 1) {
      resolveHakuWin(hand13, waits[0]);
    } else {
      setHakuChoice({ hand13, waits });
    }
  }

  function resolveHakuWin(hand13, chosenWait) {
    setHakuChoice(null);
    const testHand = [...hand13, chosenWait];
    const res = canWin(testHand, players[0].melds, chosenWait);
    if (!res.ok) {
      addLog("和了形になっていません");
      return;
    }
    const psForWin = players.map((p, i) => (i === 0 ? { ...p, hand: testHand } : p));
    resolveWin(0, chosenWait, true, res, psForWin);
  }

  function humanRiichi() {
    if (players[0].riichi) return;
    if (players[0].melds.length > 0) {
      addLog("鳴いているとリーチできません");
      return;
    }
    if (players[0].score < 1000) {
      addLog("持ち点が足りません");
      return;
    }
    setRiichiArmed(true);
  }

  function humanCancelRiichi() {
    setRiichiArmed(false);
  }

  function resolveKanYes() {
    if (!kanPrompt) return;
    const { type, tile } = kanPrompt;
    setKanPrompt(null);
    if (type === "ankan") doAnkan(0, tile);
    else if (type === "kakan") doKakan(0, tile);
  }

  function resolveKanNo() {
    if (!kanPrompt) return;
    setKanPrompt(null);
    if (players[0].riichi) {
      setTimeout(() => doDiscard(0, players[0].hand.length - 1, players), 300);
    }
  }

  function doAnkan(who, tileNorm) {
    const np = players.slice();
    const p = { ...np[who] };
    let hand = p.hand.slice();
    let removed = 0;
    hand = hand.filter((t) => {
      if (removed < 4 && normTile(t) === tileNorm) {
        removed++;
        return false;
      }
      return true;
    });
    p.hand = hand;
    p.melds = [...p.melds, { type: "ankan", tile: tileNorm }];
    np[who] = p;
    addLog(`${SEATS[who]} が暗槓(${tileText(tileNorm)})`);
    showSplash("カン");
    const dw = deadWall.slice();
    const rinshan = dw.pop();
    setDeadWall(dw);
    if (rinshan) {
      p.hand = sortHandKeepLast([...p.hand, rinshan], rinshan);
      np[who] = p;
      setDrewTile(rinshan);
    }
    setPlayers(np);
  }

  function doKakan(who, tileNorm) {
    const np = players.slice();
    const p = { ...np[who] };
    const hand = p.hand.slice();
    const idx = hand.findIndex((t) => normTile(t) === tileNorm);
    if (idx === -1) return;
    hand.splice(idx, 1);
    p.hand = hand;
    p.melds = p.melds.map((m) => (m.type === "pon" && m.tile === tileNorm ? { ...m, type: "kakan" } : m));
    np[who] = p;
    addLog(`${SEATS[who]} が加槓(${tileText(tileNorm)})`);
    showSplash("カン");
    const dw = deadWall.slice();
    const rinshan = dw.pop();
    setDeadWall(dw);
    if (rinshan) {
      p.hand = sortHandKeepLast([...p.hand, rinshan], rinshan);
      np[who] = p;
      setDrewTile(rinshan);
    }
    setPlayers(np);
  }

  function doDiscard(who, idx, ps, riichiDeclare) {
    const tile = ps[who].hand[idx];
    const newHand = ps[who].hand.slice();
    newHand.splice(idx, 1);
    let np = ps.map((p, i) =>
      i === who
        ? {
            ...p,
            hand: newHand,
            discards: [...p.discards, tile],
            riichiDiscardIndex: riichiDeclare ? p.discards.length : p.riichiDiscardIndex,
            ippatsuLive: p.ippatsuLive,
          }
        : p
    );
    setPlayers(np);
    setDrewTile(null);
    addLog(`${SEATS[who]} 打 ${tileText(tile)}`);
    if (riichiDeclare) showSplash("まげ!!");

    const callers = [0, 1, 2].filter((i) => i !== who);
    for (const c of callers) {
      const res = tryResolveWin(c, np, tile, false, np[c].melds);
      if (res && res.ok) {
        if (c === 0) {
          setCallChoices({ ron: true, tile, from: who, res });
          setPhase("callwindow");
          return;
        } else {
          resolveWin(c, tile, false, res, np, who);
          return;
        }
      }
    }
    for (const c of callers) {
      const cnt = countTilesUsed(np[c].hand, normTile(tile));
      if (cnt >= 2 && !np[c].riichi) {
        if (c === 0) {
          setCallChoices({ ron: false, pon: cnt >= 2, kan: cnt >= 3, tile, from: who });
          setPhase("callwindow");
          return;
        } else {
          const isYakuTile = ["P", "F", "C", "N"].includes(tile) || tile === seatWindOf(c, dealerIdx);
          if (isYakuTile && Math.random() < 0.7) {
            doPon(c, tile, who, np);
            return;
          }
        }
      }
    }
    advanceTurn(who, np);
  }

  function doPon(who, tile, from, ps) {
    const np = ps.map((p) => ({ ...p, ippatsuLive: false }));
    const p = { ...np[who] };
    let removed = 0;
    p.hand = p.hand.filter((t) => {
      if (removed < 2 && normTile(t) === normTile(tile)) {
        removed++;
        return false;
      }
      return true;
    });
    p.melds = [...p.melds, { type: "pon", tile: normTile(tile), from }];
    np[who] = p;
    np[from] = { ...np[from], discards: np[from].discards.slice() };
    setPlayers(np);
    setDrewTile(null);
    addLog(`${SEATS[who]} がポン(${tileText(tile)})`);
    showSplash("ポキ!!");
    setCurrent(who);
    setCallChoices(null);
    setPhase("playing");
    if (who !== 0) {
      setTimeout(() => aiDiscardAfterCall(who, np), 500);
    }
  }

  function doDaiminkan(who, tile, from, ps) {
    const np = ps.map((p) => ({ ...p, ippatsuLive: false }));
    const p = { ...np[who] };
    let removed = 0;
    p.hand = p.hand.filter((t) => {
      if (removed < 3 && normTile(t) === normTile(tile)) {
        removed++;
        return false;
      }
      return true;
    });
    p.melds = [...p.melds, { type: "minkan", tile: normTile(tile), from }];
    np[who] = p;
    addLog(`${SEATS[who]} が大明槓(${tileText(tile)})`);
    showSplash("カン");
    setCurrent(who);
    setCallChoices(null);
    setPhase("playing");
    const dw = deadWall.slice();
    const rinshan = dw.pop();
    setDeadWall(dw);
    if (rinshan) {
      np[who] = { ...np[who], hand: sortHandKeepLast([...np[who].hand, rinshan], rinshan) };
      setDrewTile(rinshan);
    }
    setPlayers(np);
  }

  function humanCallRon() {
    const { tile, from, res } = callChoices;
    resolveWin(0, tile, false, res, players, from);
  }
  function humanCallPon() {
    if (countTilesUsed(players[0].hand, normTile(callChoices.tile)) < 2) {
      addLog("ポンできる牌がありません");
      setCallChoices(null);
      setPhase("playing");
      return;
    }
    doPon(0, callChoices.tile, callChoices.from, players);
  }
  function humanCallKan() {
    if (countTilesUsed(players[0].hand, normTile(callChoices.tile)) < 3) {
      addLog("カンできる牌がありません");
      setCallChoices(null);
      setPhase("playing");
      return;
    }
    doDaiminkan(0, callChoices.tile, callChoices.from, players);
  }
  function humanSkipCall() {
    setCallChoices(null);
    setPhase("playing");
    advanceTurn(callChoices.from, players);
  }

  function advanceTurn(who, ps) {
    const next = (who + 1) % 3;
    setCurrent(next);
    if (wall.length === 0) {
      handleDraw(ps);
      return;
    }
    setTimeout(() => drawForCurrent(next, ps, wall, deadWall), 300);
  }

  /* ------------------------- AI ------------------------- */
  function isTenpaiHand(hand, melds) {
    for (const cand of ALL_TILE_CODES) {
      const test = [...hand, cand];
      const r = canWin(test, melds, cand);
      if (r.ok) return true;
    }
    return false;
  }

  function computeWaits(hand, melds) {
    const waits = [];
    for (const cand of ALL_TILE_CODES) {
      const test = [...hand, cand];
      const r = canWin(test, melds, cand);
      if (r.ok) waits.push(cand);
    }
    return waits;
  }

  function tileKeepValue(hand, idx) {
    const t = hand[idx];
    const tn = normTile(t);
    const others = hand.filter((_, j) => j !== idx);
    let val = 0;
    const sameCount = others.filter((o) => normTile(o) === tn).length;
    val += sameCount * 10;
    if (!isHonor(t)) {
      const n = baseNum(t);
      const suit = suitOf(t);
      others.forEach((o) => {
        if (isHonor(o) || suitOf(o) !== suit) return;
        const d = Math.abs(baseNum(o) - n);
        if (d === 1) val += 6;
        else if (d === 2) val += 3;
      });
      if (n === 1 || n === 9) val -= 2;
    } else if (["P", "F", "C", "N"].includes(t) && sameCount >= 1) {
      val += 4;
    }
    if (isRed(t)) val += 18;
    if (tn === "7p" || tn === "7s") val += 5 + sameCount * 3;
    return val;
  }

  function chooseAiDiscardIndex(hand, melds) {
    const scored = hand.map((t, i) => ({ i, v: tileKeepValue(hand, i) }));
    scored.sort((a, b) => a.v - b.v);
    for (const cand of scored) {
      const after = hand.slice();
      after.splice(cand.i, 1);
      if (isTenpaiHand(after, melds)) return cand.i;
    }
    return scored[0].i;
  }

  function aiTurn(who, ps, wallArr) {
    const p = ps[who];
    const hand = p.hand;
    const res = tryResolveWin(who, ps, drewTile, true, p.melds);
    if (res && res.ok) {
      resolveWin(who, drewTile, true, res, ps);
      return;
    }
    if (p.riichi && p.melds.length === 0 && drewTile === "K") {
      const hand13 = hand.slice(0, -1);
      const waits = computeWaits(hand13, p.melds);
      if (waits.length > 0) {
        const chosen = waits[0];
        const testHand = [...hand13, chosen];
        const hakuRes = canWin(testHand, p.melds, chosen);
        if (hakuRes.ok) {
          const psForWin = ps.map((pl, i) => (i === who ? { ...pl, hand: testHand } : pl));
          addLog(`${SEATS[who]} が白ポッチで${tileText(chosen)}待ちを選択`);
          resolveWin(who, chosen, true, hakuRes, psForWin);
          return;
        }
      }
    }
    aiDiscardAfterCall(who, ps);
  }

  function aiDiscardAfterCall(who, ps) {
    const p = ps[who];
    const hand = p.hand;
    let idx;
    if (p.riichi) {
      idx = hand.length - 1;
    } else {
      idx = chooseAiDiscardIndex(hand, p.melds);
    }
    let nextPs = ps;
    let isRiichiDeclare = false;
    if (!p.riichi && p.melds.length === 0 && p.score >= 1000) {
      const after = hand.slice();
      after.splice(idx, 1);
      if (isTenpaiHand(after, p.melds)) {
        nextPs = ps.map((pl, i) =>
          i === who ? { ...pl, riichi: true, score: pl.score - 1000, ippatsuLive: true } : pl
        );
        setPlayers(nextPs);
        addLog(`${SEATS[who]} が立直!`);
        isRiichiDeclare = true;
      }
    }
    setTimeout(() => doDiscard(who, idx, nextPs, isRiichiDeclare), 400);
  }

  /* ------------------------- 和了処理(ドラ・チューリップ) ------------------------- */
  function resolveWin(winner, winTile, isTsumo, res, ps, ronFrom) {
    const p = ps[winner];
    const handForYaku = isTsumo ? p.hand : [...p.hand, winTile];
    const ippatsu = p.ippatsuLive && !p.melds.some((m) => m.type !== "ankan");

    const yaku = detectYaku({
      handTiles: handForYaku,
      winTile,
      isTsumo,
      melds: p.melds,
      riichi: p.riichi,
      ippatsu,
      doraIndicators,
      uraIndicators: [],
      seatWind: seatWindOf(winner, dealerIdx),
      isSevenShi: res.isSevenShi,
    });

    const dw = deadWall.slice();
    let uraTile = null;
    if (dw.length > 1) {
      uraTile = dw[1];
    }
    let uraDoraChips = 0;
    let uraDoraHan = 0;
    if (uraTile) {
      const uraDoraTiles = neighborsNext(uraTile);
      uraDoraTiles.forEach((d) => {
        const hit = countTilesUsed(handForYaku, d);
        uraDoraHan += hit;
        uraDoraChips += hit;
      });
    }
    if (uraDoraHan > 0) yaku.push({ name: "裏ドラ", han: uraDoraHan, dora: true });

    const isYakuman = yaku.some((y) => y.yakuman);
    const totalHan = isYakuman ? 13 : yaku.reduce((a, y) => a + y.han, 0);
    const realYakuHan = isYakuman ? 13 : yaku.filter((y) => !y.dora).reduce((a, y) => a + y.han, 0);

    if (!isYakuman && realYakuHan === 0) {
      addLog(`${SEATS[winner]} は役がなく和了できません`);
      setCallChoices(null);
      setPhase("playing");
      return;
    }

    const tulipResult = p.riichi
      ? runTulipStreak(ps, handForYaku, dw, tulipPtr, res)
      : { totalChips: 0, logs: [], is16R: false, isKakuhen: false, newDeadWall: dw, newPtr: tulipPtr, newLevel: tulipLevel };

    const isDealer = winner === dealerIdx;
    const fixedRow = !isYakuman && totalHan <= 3 ? FIXED_SCORE_TABLE[isDealer ? "dealer" : "child"][totalHan] : null;
    let scoreGain = isYakuman ? (isDealer ? 48000 : 32000) : fixedRow ? (isTsumo ? null : fixedRow.ron) : hanToChipsScore(totalHan, isDealer, isTsumo);

    const redChipCount = handForYaku.filter((t) => isRed(t)).length;
    const ippatsuChip = ippatsu ? 1 : 0;
    let chipGain = redChipCount + ippatsuChip + uraDoraChips + tulipResult.totalChips;
    if (isYakuman) chipGain += 20;
    if (tulipResult.is16R) chipGain = chipGain * 2;

    const markerBefore = p.marker || "manrui";
    const markerMult = markerBefore === "homerun" ? 2 : 1;
    chipGain = chipGain * markerMult;

    const newPs = ps.map((pl, i) => ({ ...pl }));
    if (isTsumo) {
      if (fixedRow) {
        let totalPaid = 0;
        newPs.forEach((pl, i) => {
          if (i === winner) return;
          const payerIsDealer = i === dealerIdx;
          const pay = isDealer ? fixedRow.tsumoEach : payerIsDealer ? fixedRow.tsumoDealer : fixedRow.tsumoChild;
          pl.score -= pay;
          totalPaid += pay;
        });
        newPs[winner].score += totalPaid;
        scoreGain = totalPaid;
      } else {
        newPs.forEach((pl, i) => {
          if (i === winner) return;
          let pay;
          if (isDealer) {
            pay = Math.round(scoreGain / 2 / 100) * 100;
          } else {
            const payerIsDealer = i === dealerIdx;
            pay = Math.round((scoreGain * (payerIsDealer ? 3 : 1)) / 4 / 100) * 100;
          }
          pl.score -= pay;
        });
        const totalPaid = newPs.reduce((a, pl, i) => (i === winner ? a : a + (ps[i].score - newPs[i].score)), 0);
        newPs[winner].score += totalPaid;
        scoreGain = totalPaid;
      }
    } else {
      newPs[ronFrom].score -= scoreGain;
      newPs[winner].score += scoreGain;
    }
    newPs[winner].chips += chipGain;
    if (markerBefore === "manrui") {
      newPs[winner].marker = "homerun";
      addLog(`${SEATS[winner]} のマーカーが満塁→ホームランに反転!`);
    }
    const revertedMarkers = [];
    if (isTsumo) {
      newPs.forEach((pl, i) => {
        if (i === winner) return;
        if (pl.marker === "homerun") {
          pl.marker = "manrui";
          revertedMarkers.push(i);
        }
      });
    } else if (ronFrom !== undefined && ronFrom !== winner) {
      if (newPs[ronFrom].marker === "homerun") {
        newPs[ronFrom].marker = "manrui";
        revertedMarkers.push(ronFrom);
      }
    }
    revertedMarkers.forEach((i) => addLog(`${SEATS[i]} のマーカーがホームラン→満塁に反転`));

    setPlayers(newPs);
    setUraIndicators(uraTile ? [uraTile] : []);
    setDeadWall(tulipResult.newDeadWall);
    setTulipPtr(tulipResult.newPtr);
    setTulipLevel(tulipResult.newLevel);

    const yakuText = yaku.map((y) => `${y.name}${y.yakuman ? "(役満)" : `${y.han}翻`}`).join("、");
    addLog(
      `【和了】${SEATS[winner]} ${isTsumo ? "ツモ" : "ロン"} ${yakuText} / 獲得${scoreGain}点 祝儀+${chipGain}枚`
    );
    showSplash(isTsumo ? "ツモりあげ!!" : "ロンじゃー!!");
    tulipResult.logs.forEach((l) => addLog(l));

    setCallChoices(null);
    setResultInfo({
      type: "win",
      winner,
      isTsumo,
      yaku,
      scoreGain,
      chipGain,
      tulip: tulipResult,
      uraTile,
      markerBefore,
      markerMult,
      revertedMarkers,
      winnerHand: handForYaku,
      winnerMelds: p.melds,
      winTile,
    });
    setPhase("result");
  }

  function runTulipStreak(ps, winnerHand, dw, ptr, res) {
    const logs = [];
    const flips = [];
    let totalChips = 0;
    let p = ptr;
    let level = tulipLevel;
    const use7s = countSeven(winnerHand, "s") >= 3;
    const use7p = countSeven(winnerHand, "p") >= 3;
    const isKakuhen = use7s || use7p;
    const is16R = use7s && use7p;
    let continueFlip = true;
    let newDw = dw.slice();

    while (continueFlip) {
      const stepCount = isKakuhen ? 2 : 1;
      const revealsThisFlip = [];
      for (let i = 0; i < stepCount; i++) {
        if (p >= newDw.length) break;
        const revealed = newDw[p];
        p++;
        if (isFlower(revealed)) continue;
        const neighbors = neighborsOf(revealed);
        let hits = 0;
        ps.forEach((pl) => {
          const allT = [...pl.hand, ...pl.melds.flatMap((m) => Array(m.type.includes("kan") ? 4 : 3).fill(m.tile))];
          neighbors.forEach((nb) => {
            hits += countTilesUsed(allT, nb);
          });
        });
        revealsThisFlip.push({ tile: revealed, neighbors, hits });
      }
      if (revealsThisFlip.length === 0) break;
      const hitsThisFlip = revealsThisFlip.reduce((a, r) => a + r.hits, 0);
      const chipsThisFlip = hitsThisFlip;
      totalChips += chipsThisFlip;
      flips.push({ reveals: revealsThisFlip, chips: chipsThisFlip });
      logs.push(
        `チューリップ! ${revealsThisFlip.map((r) => tileText(r.tile)).join("・")} 開放 → ヒット${hitsThisFlip}枚 (+${chipsThisFlip}枚)`
      );
      if (hitsThisFlip >= 6) {
        level++;
        logs.push(`突確! チューリップ状態が1段階アップ(Lv${level})`);
      }
      continueFlip = isKakuhen && hitsThisFlip > 0;
    }
    if (isKakuhen) {
      logs.unshift(
        is16R
          ? "【16R】7p・7sともに3枚以上使用! 上下段チューリップ＋最終チップ2倍!"
          : "【確変】7p or 7s 3枚以上使用! 上下段チューリップ継続!"
      );
    }
    return { totalChips, logs, flips, is16R, isKakuhen, newDeadWall: newDw, newPtr: p, newLevel: level };
  }

  /* ------------------------- 次局へ ------------------------- */
  function nextHand() {
    const dealerWon = resultInfo?.type === "win" && resultInfo.winner === dealerIdx;
    const isDraw = resultInfo?.type === "draw";
    let newDealer = dealerIdx;
    let newRound = round;
    if (dealerWon || isDraw) {
      addLog(`${SEATS[dealerIdx]} 連荘`);
    } else {
      newDealer = (dealerIdx + 1) % 3;
      newRound = round + 1;
    }
    const busted = players.some((p) => p.score <= 0);
    if (busted || newRound > 3) {
      setPhase("gameover");
      return;
    }
    setRound(newRound);
    startHand(newDealer);
  }

  /* ------------------------- UI ------------------------- */
  const you = players[0];
  const isMyTurn = current === 0 && phase === "playing";
  const expectedHandLen = 14 - 3 * you.melds.length;
  const canTsumo = isMyTurn && drewTile && you.hand.length === expectedHandLen && (() => {
    const r = tryResolveWin(0, players, drewTile, true, you.melds);
    return r && r.ok;
  })();
  const riichiCandidateIdx = riichiArmed
    ? you.hand.map((_, i) => i).filter((i) => {
        const after = you.hand.slice();
        after.splice(i, 1);
        return isTenpaiHand(after, you.melds);
      })
    : [];
  const canRiichi =
    isMyTurn &&
    drewTile &&
    you.hand.length === expectedHandLen &&
    !you.riichi &&
    you.melds.length === 0 &&
    you.score >= 1000 &&
    you.hand.some((_, i) => {
      const after = you.hand.slice();
      after.splice(i, 1);
      return isTenpaiHand(after, you.melds);
    });

  const hakuEligible =
    isMyTurn &&
    drewTile === "K" &&
    you.hand.length === expectedHandLen &&
    you.riichi &&
    you.melds.length === 0;
  const hakuWaitsPreview = hakuEligible ? computeWaits(you.hand.slice(0, -1), you.melds) : [];
  const canHakuTsumo = hakuWaitsPreview.length > 0;

  if (phase === "title") {
    return (
      <div style={styles.titleWrap}>
        <div style={styles.titleCard}>
          <div style={styles.titleFlower}>🌸</div>
          <h1 style={styles.titleH1}>三人麻雀</h1>
          <div style={styles.titleSub}>チューリップ祝儀ルール</div>
          <p style={styles.titleDesc}>
            萬子を全て廃止し、7ピンズ・7ソウズを各8枚に。
            <br />
            和了のたびに裏ドラとチューリップが咲く、祝儀チップ制の三人麻雀。
          </p>
          <button style={styles.bigBtn} onClick={() => startHand(0)}>
            対局開始
          </button>
          <button style={styles.linkBtn} onClick={() => setShowRules(true)}>
            ルール確認(実装上の解釈)
          </button>
        </div>
        {showRules && <RulesPanel onClose={() => setShowRules(false)} />}
      </div>
    );
  }

  if (phase === "gameover") {
    const ranked = players
      .map((p, i) => ({ ...p, i }))
      .sort((a, b) => b.score - a.score || b.chips - a.chips);
    return (
      <div style={styles.titleWrap}>
        <div style={styles.titleCard}>
          <h1 style={styles.titleH1}>対局終了</h1>
          {ranked.map((p, idx) => (
            <div key={p.i} style={styles.rankRow}>
              <span style={styles.rankNum}>{idx + 1}位</span>
              <span style={styles.rankName}>{p.name}</span>
              <span style={styles.rankScore}>{p.score}点</span>
              <span style={styles.rankChip}>🎫{p.chips}枚</span>
            </div>
          ))}
          <button style={styles.bigBtn} onClick={() => { setPlayers(initialPlayers()); setRound(1); startHand(0); }}>
            もう一度
          </button>
        </div>
      </div>
    );
  }

  return (
    <div style={styles.table}>
      <div style={styles.topBar}>
        <div style={styles.doraBox}>
          <span style={styles.doraLabel}>ドラ</span>
          {doraIndicators.map((d, i) => (
            <MahjongTile key={i} tile={d} size="sm" />
          ))}
        </div>
        {uraIndicators.length > 0 && (
          <div style={styles.doraBox}>
            <span style={styles.doraLabel}>裏ドラ</span>
            {uraIndicators.map((d, i) => <MahjongTile key={"u" + i} tile={d} size="sm" glow />)}
          </div>
        )}
        <div style={styles.doraBox}>
          <span style={styles.doraLabel}>山</span>
          <BackTile size="sm" />
          <span style={{ fontWeight: 800 }}>{wall.length}枚</span>
        </div>
      </div>

      <div style={styles.mainArea}>
        <TablePond players={players} dealerIdx={dealerIdx} round={round} dice={diceRoll} current={current} />
      </div>

      <div style={styles.logStrip}>{log[0] || ""}</div>

      <div style={styles.myArea}>
        <div style={styles.myInfoCol}>
          <div style={{ fontSize: 11 }}>🎫{you.chips} 🌸{you.flowers.length}</div>
          {you.melds.length > 0 && (
            <div style={styles.meldRowCompact}>
              {you.melds.map((m, i) => (
                <div key={i} style={styles.meldGroup}>
                  <MeldGroup meld={m} who={0} size="sm" />
                </div>
              ))}
            </div>
          )}
        </div>
        <div style={styles.handCol}>
          <div style={{ ...styles.handLabel, display: "flex", alignItems: "center", justifyContent: "flex-end", flexWrap: "wrap", gap: 6 }}>
            {kanPrompt ? (
              <>
                <span style={{ fontSize: 10, opacity: 0.8 }}>
                  {tileText(kanPrompt.tile)}で{kanPrompt.type === "ankan" ? "暗槓" : "加槓"}?
                </span>
                <button style={styles.actBtn} onClick={resolveKanYes}>カンする</button>
                <button style={styles.skipBtn} onClick={resolveKanNo}>キャンセル</button>
              </>
            ) : phase === "callwindow" && callChoices ? (
              (() => {
                const liveCnt = countTilesUsed(players[0].hand, normTile(callChoices.tile));
                const showPon = callChoices.pon && liveCnt >= 2;
                const showKan = callChoices.kan && liveCnt >= 3;
                return (
                  <>
                    <span style={{ fontSize: 10, opacity: 0.8 }}>
                      {SEATS[callChoices.from]}が{tileText(callChoices.tile)}
                    </span>
                    {callChoices.ron && (
                      <button style={styles.actBtn} onClick={humanCallRon}>ロン</button>
                    )}
                    {showKan && (
                      <button style={styles.actBtn} onClick={humanCallKan}>カンする</button>
                    )}
                    {showPon && (
                      <button style={styles.actBtn} onClick={humanCallPon}>ポン</button>
                    )}
                    <button style={styles.skipBtn} onClick={humanSkipCall}>
                      {callChoices.ron ? "スルー" : "キャンセル"}
                    </button>
                  </>
                );
              })()
            ) : (
              <>
                {isMyTurn && canTsumo && !riichiArmed && !hakuEligible && (
                  <button style={styles.actBtn} onClick={humanTsumo}>ツモ</button>
                )}
                {isMyTurn && canHakuTsumo && !riichiArmed && (
                  <button style={styles.actBtn} onClick={humanTsumoHaku}>白ポッチでツモ</button>
                )}
                {isMyTurn && canRiichi && !riichiArmed && (
                  <button style={styles.actBtn} onClick={humanRiichi}>リーチ</button>
                )}
                {riichiArmed && (
                  <>
                    <button style={{ ...styles.actBtn, opacity: 0.75 }} disabled>リーチ選択中…</button>
                    <button style={styles.skipBtn} onClick={humanCancelRiichi}>キャンセル</button>
                  </>
                )}
                {!isMyTurn && phase === "playing" && (
                  <span style={{ fontSize: 11, opacity: 0.6 }}>CPU対局中…</span>
                )}
              </>
            )}
            <span style={{ display: "flex", alignItems: "center", gap: 4 }}>
              {you.riichi && <span title="リーチ">🔴</span>}
              <TeamMarker state={you.marker} />
            </span>
          </div>
          <div style={{ ...styles.handRow, marginBottom: 0 }}>
            {(() => {
              const count = you.hand.length || 1;
              const gap = 3;
              const available = Math.max(260, vw - 150);
              let tileW = Math.floor((available - gap * (count - 1) - 10) / count);
              tileW = Math.max(22, Math.min(38, tileW));
              const tileH = Math.round(tileW * 1.35);
              return you.hand.map((t, i) => {
                const isDrawn = drewTile !== null && i === you.hand.length - 1 && t === drewTile;
                const isRiichiCandidate = riichiArmed && riichiCandidateIdx.includes(i);
                return (
                  <div key={i} style={isDrawn ? styles.drawnGap : undefined}>
                    <MahjongTile
                      tile={t}
                      width={tileW}
                      height={tileH}
                      selected={i === selectedTileIdx}
                      glow={isDrawn || isRiichiCandidate}
                      faded={riichiArmed && !isRiichiCandidate}
                      onClick={() => {
                        if (!isMyTurn) {
                          setSelectedTileIdx(i === selectedTileIdx ? null : i);
                          return;
                        }
                        if (selectedTileIdx === i) {
                          setSelectedTileIdx(null);
                          humanDiscard(i);
                        } else {
                          setSelectedTileIdx(i);
                        }
                      }}
                    />
                  </div>
                );
              });
            })()}
          </div>
        </div>
      </div>

      {hakuChoice && (
        <div style={styles.modalOverlay}>
          <div style={styles.modalCard}>
            <div style={{ fontSize: 15, marginBottom: 12 }}>どの待ちにしますか?</div>
            <div style={{ display: "flex", gap: 10, justifyContent: "center", flexWrap: "wrap", marginBottom: 10 }}>
              {hakuChoice.waits.map((w, i) => (
                <button key={i} style={styles.actBtn} onClick={() => resolveHakuWin(hakuChoice.hand13, w)}>
                  {tileText(w)}
                </button>
              ))}
            </div>
            <button style={styles.skipBtn} onClick={() => setHakuChoice(null)}>キャンセル</button>
          </div>
        </div>
      )}

      {phase === "result" && resultInfo && (
        <div style={styles.modalOverlay}>
          <div style={styles.modalCardWide}>
            {resultInfo.type === "draw" ? (
              <div style={{ fontSize: 20, marginBottom: 12 }}>流局</div>
            ) : (
              <>
                <div style={{ fontSize: 20, marginBottom: 6 }}>
                  {SEATS[resultInfo.winner]} {resultInfo.isTsumo ? "ツモ" : "ロン"}和了!
                </div>
                <div style={{ display: "flex", flexWrap: "wrap", gap: 2, justifyContent: "center", marginBottom: 8 }}>
                  {sortHand(resultInfo.winnerHand).map((t, i) => (
                    <MahjongTile key={i} tile={t} size="sm" glow={t === resultInfo.winTile} />
                  ))}
                  {resultInfo.winnerMelds.map((m, i) => (
                    <span key={i} style={{ marginLeft: 4 }}>
                      <MeldGroup meld={m} who={resultInfo.winner} size="sm" />
                    </span>
                  ))}
                </div>
                <div style={{ fontSize: 11, opacity: 0.6, marginBottom: 6, letterSpacing: 2 }}>役申告</div>
                <div style={{ display: "flex", flexWrap: "wrap", gap: 6, justifyContent: "center", marginBottom: 10 }}>
                  {resultInfo.yaku.map((y, i) => (
                    <span key={i} style={styles.yakuTag}>
                      {y.name}　{y.yakuman ? "役満" : `${y.han}翻`}
                    </span>
                  ))}
                </div>
                <div style={{ fontSize: 12, opacity: 0.75, marginBottom: 8 }}>
                  合計 {resultInfo.yaku.some((y) => y.yakuman) ? "役満" : `${resultInfo.yaku.reduce((a, y) => a + y.han, 0)}翻`}
                </div>
                <div style={{ fontSize: 15, marginBottom: 4 }}>獲得点数:{resultInfo.scoreGain}点</div>
                <div style={{ fontSize: 15, marginBottom: 4 }}>
                  祝儀チップ:+{resultInfo.chipGain}枚
                  {resultInfo.markerMult > 1 && <span style={{ color: "#ffd98a" }}>(ホームラン×2適用)</span>}
                </div>
                {resultInfo.markerBefore === "manrui" && (
                  <div style={{ fontSize: 12, color: "#ffd98a", marginBottom: 4 }}>🏟️ 満塁 → 🎉 ホームランに反転!</div>
                )}
                {resultInfo.revertedMarkers && resultInfo.revertedMarkers.length > 0 && (
                  <div style={{ fontSize: 12, opacity: 0.75, marginBottom: 8 }}>
                    {resultInfo.revertedMarkers.map((i) => SEATS[i]).join("・")} のマーカーがホームラン→満塁に反転
                  </div>
                )}
                {resultInfo.tulip.flips && resultInfo.tulip.flips.length > 0 && (
                  <div style={{ marginBottom: 8 }}>
                    <div style={{ fontSize: 11, opacity: 0.6, marginBottom: 4, letterSpacing: 2 }}>チューリップ公開</div>
                    <div style={{ display: "flex", flexWrap: "wrap", gap: 10, justifyContent: "center" }}>
                      {resultInfo.tulip.flips.map((f, i) => (
                        <div key={i} style={{ display: "flex", flexDirection: "column", alignItems: "center", gap: 3 }}>
                          <div style={{ display: "flex", gap: 4 }}>
                            {f.reveals.map((r, j) => (
                              <div key={j} style={{ display: "flex", flexDirection: "column", alignItems: "center", gap: 2 }}>
                                <MahjongTile tile={r.tile} size="md" glow />
                                <div style={{ display: "flex", gap: 1 }}>
                                  {r.neighbors.map((n, k) => (
                                    <MahjongTile key={k} tile={n} size="sm" />
                                  ))}
                                </div>
                              </div>
                            ))}
                          </div>
                          <div style={{ fontSize: 10, opacity: 0.8 }}>+{f.chips}枚</div>
                        </div>
                      ))}
                    </div>
                  </div>
                )}
                <div style={{ fontSize: 12, background: "#00000022", borderRadius: 8, padding: 8, textAlign: "left", maxHeight: 100, overflowY: "auto" }}>
                  {resultInfo.tulip.logs.map((l, i) => (
                    <div key={i}>{l}</div>
                  ))}
                </div>
              </>
            )}
            <div style={{ marginTop: 14, display: "flex", gap: 8, justifyContent: "center" }}>
              {players.map((p, i) => (
                <div key={i} style={styles.scoreChip}>
                  {p.name}: {p.score}点 / 🎫{p.chips}
                </div>
              ))}
            </div>
            <button style={{ ...styles.bigBtn, marginTop: 14 }} onClick={nextHand}>
              次の局へ
            </button>
          </div>
        </div>
      )}

      {showRules && <RulesPanel onClose={() => setShowRules(false)} />}

      {splash && (
        <div key={splash.key} style={styles.splashOverlay}>
          <div style={styles.splashText}>{splash.text}</div>
        </div>
      )}
    </div>
  );
}

function chunkTiles(arr, size) {
  const out = [];
  for (let i = 0; i < arr.length; i += size) out.push(arr.slice(i, i + size));
  return out;
}

const DICE_PIPS = {
  1: [[1, 1]],
  2: [[0, 0], [2, 2]],
  3: [[0, 0], [1, 1], [2, 2]],
  4: [[0, 0], [0, 2], [2, 0], [2, 2]],
  5: [[0, 0], [0, 2], [1, 1], [2, 0], [2, 2]],
  6: [[0, 0], [0, 2], [1, 0], [1, 2], [2, 0], [2, 2]],
};
function TeamMarker({ state, size = "sm" }) {
  const isHomerun = state === "homerun";
  const dim = size === "md" ? { w: 58, h: 34, fs: 12 } : { w: 42, h: 24, fs: 8.5 };
  return (
    <div
      title={isHomerun ? "ホームラン(祝儀×2)" : "満塁(祝儀×1)"}
      style={{
        width: dim.w, height: dim.h, borderRadius: 4, flexShrink: 0,
        background: "linear-gradient(160deg,#1c2e24,#0b1410)",
        border: "1px solid #3a5c47",
        display: "flex", alignItems: "center", justifyContent: "center",
        boxShadow: "inset 0 0 0 1px #00000060, 0 1px 3px #0008",
        overflow: "hidden",
      }}
    >
      <span
        style={{
          fontSize: dim.fs, fontWeight: 900, letterSpacing: 0.5,
          color: isHomerun ? "#f2df6e" : "#e14a3f",
          textShadow: "1px 1px 0 #00000090",
          fontFamily: "'Hiragino Mincho ProN', serif",
          transform: "skewX(-8deg) scaleY(1.08)",
          whiteSpace: "nowrap",
        }}
      >
        {isHomerun ? "ホームラン" : "満塁"}
      </span>
    </div>
  );
}

function scoreToSticks(score) {
  if (score === 30000) return { s10000: 1, s5000: 3, s1000: 5, remainder: 0 };
  let remaining = Math.max(0, score);
  const s10000 = Math.floor(remaining / 10000);
  remaining %= 10000;
  const s5000 = Math.floor(remaining / 5000);
  remaining %= 5000;
  const s1000 = Math.floor(remaining / 1000);
  remaining %= 1000;
  return { s10000, s5000, s1000, remainder: remaining };
}
function ScoreSticks({ score, size = "sm" }) {
  const { s10000, s5000, s1000, remainder } = scoreToSticks(score);
  const h = size === "md" ? 10 : 7;
  const stickStyle = (color, w) => ({
    width: w, height: h, borderRadius: 1, background: color, border: "1px solid #00000040", flexShrink: 0,
  });
  return (
    <div style={{ display: "flex", alignItems: "center", gap: 3, flexWrap: "wrap" }}>
      {s10000 > 0 && (
        <span style={{ display: "flex", alignItems: "center", gap: 1 }}>
          <span style={stickStyle("#e3b968", h * 3.4)} />
          <span style={{ fontSize: 9, opacity: 0.8 }}>×{s10000}</span>
        </span>
      )}
      {s5000 > 0 && (
        <span style={{ display: "flex", alignItems: "center", gap: 1 }}>
          <span style={stickStyle("#f4ead9", h * 3.4)} />
          <span style={{ fontSize: 9, opacity: 0.8 }}>×{s5000}</span>
        </span>
      )}
      {s1000 > 0 && (
        <span style={{ display: "flex", alignItems: "center", gap: 1 }}>
          <span style={stickStyle("#8fc9e8", h * 3.4)} />
          <span style={{ fontSize: 9, opacity: 0.8 }}>×{s1000}</span>
        </span>
      )}
      {remainder > 0 && <span style={{ fontSize: 9, opacity: 0.6 }}>+{remainder}</span>}
    </div>
  );
}

function DiceIcon({ value, size = 16 }) {
  const cell = size / 3;
  const dot = cell * 0.42;
  return (
    <div style={{ position: "relative", width: size, height: size, background: "#f4ead9", borderRadius: size * 0.2, boxShadow: "0 1px 3px #0007" }}>
      {(DICE_PIPS[value] || []).map(([r, c], i) => (
        <div
          key={i}
          style={{
            position: "absolute", width: dot, height: dot, borderRadius: "50%", background: "#c0272d",
            left: c * cell + (cell - dot) / 2, top: r * cell + (cell - dot) / 2,
          }}
        />
      ))}
    </div>
  );
}

function RiverBlock({ player, who, wind, align, riichiIndex, isCurrent, compact, sideRotate = 0 }) {
  const rows = chunkTiles(player.discards, 7);
  let idxCounter = -1;
  const vertical = sideRotate !== 0;
  return (
    <div
      style={{
        ...styles.riverBlock,
        alignItems: align === "right" ? "flex-end" : "flex-start",
        overflowX: vertical ? "auto" : "hidden",
        overflowY: vertical ? "hidden" : "auto",
      }}
    >
      <div
        style={{
          ...styles.riverHeader,
          flexDirection: align === "right" ? "row-reverse" : "row",
        }}
      >
        <span style={styles.windTag}>{WIND_NAMES[wind]}</span>
        <TeamMarker state={player.marker} />
        <span style={{ fontWeight: 700 }}>{player.name}</span>
        {player.riichi && <span title="リーチ">🔴</span>}
        {isCurrent && <span title="手番">⌛</span>}
        <span style={{ opacity: 0.8, marginLeft: vertical ? 0 : align === "right" ? 0 : "auto", marginRight: vertical ? 0 : align === "right" ? "auto" : 0 }}>🎫{player.chips}</span>
      </div>
      {player.melds.length > 0 && (
        <div style={{ display: "flex", gap: 4, flexWrap: "wrap", marginBottom: 2, flexDirection: vertical ? "column" : align === "right" ? "row-reverse" : "row" }}>
          {player.melds.map((m, i) => (
            <MeldGroup key={i} meld={m} who={who} size="sm" />
          ))}
        </div>
      )}
      <div
        style={{
          ...styles.pondTiles,
          flexDirection: vertical ? "row" : "column",
          alignItems: vertical ? "flex-start" : align === "right" ? "flex-end" : "flex-start",
        }}
      >
        {rows.map((row, r) => (
          <div
            key={r}
            style={{
              ...styles.pondTileRow,
              flexDirection: vertical ? "column" : align === "right" ? "row-reverse" : "row",
            }}
          >
            {row.map((t, j) => {
              idxCounter++;
              const isRiichiTile = idxCounter === riichiIndex;
              const deg = vertical ? (isRiichiTile ? sideRotate + 90 : sideRotate) : isRiichiTile ? 90 : 0;
              return (
                <MahjongTile
                  key={j}
                  tile={t}
                  size="sm"
                  rotateDeg={deg}
                />
              );
            })}
          </div>
        ))}
      </div>
    </div>
  );
}

function DiscardTiles({ discards, riichiIndex, mode }) {
  const cols = chunkTiles(discards, 7);
  let idx = -1;
  if (mode === "horizontal") {
    return (
      <div style={{ display: "flex", flexDirection: "column", gap: 1 }}>
        {cols.map((row, r) => (
          <div key={r} style={{ display: "flex", gap: 1 }}>
            {row.map((t, j) => {
              idx++;
              return <MahjongTile key={j} tile={t} size="sm" rotateDeg={idx === riichiIndex ? 90 : 0} />;
            })}
          </div>
        ))}
      </div>
    );
  }
  return (
    <div style={{ display: "flex", flexDirection: mode === "vertical-left" ? "row-reverse" : "row", gap: 1, alignItems: "flex-start" }}>
      {cols.map((col, i) => (
        <div key={i} style={{ display: "flex", flexDirection: "column", gap: 1 }}>
          {col.map((t, j) => {
            idx++;
            return <MahjongTile key={j} tile={t} size="sm" rotateDeg={idx === riichiIndex ? 90 : 0} />;
          })}
        </div>
      ))}
    </div>
  );
}

function PlayerInfoRow({ player, who, wind, isCurrent }) {
  return (
    <div style={{ ...styles.playerInfoRow, justifyContent: "space-between" }}>
      <span style={{ display: "flex", alignItems: "center", gap: 4, flexWrap: "wrap" }}>
        <span style={styles.windTag}>{WIND_NAMES[wind]}</span>
        <span style={{ fontWeight: 700 }}>{player.name}</span>
        {player.riichi && <span title="リーチ">🔴</span>}
        {isCurrent && <span title="手番">⌛</span>}
        <span style={{ opacity: 0.8 }}>🎫{player.chips}</span>
      </span>
      <span style={{ display: "flex", alignItems: "center", gap: 6, flexWrap: "wrap", justifyContent: "flex-end" }}>
        {player.melds.length > 0 && (
          <span style={{ display: "flex", gap: 4, flexWrap: "wrap" }}>
            {player.melds.map((m, i) => (
              <MeldGroup key={i} meld={m} who={who} size="sm" />
            ))}
          </span>
        )}
        <TeamMarker state={player.marker} />
      </span>
    </div>
  );
}

function PlayerRiverRow({ player, who, wind, isCurrent }) {
  return (
    <div style={styles.playerRiverRow}>
      <div style={styles.playerInfoRow}>
        <span style={styles.windTag}>{WIND_NAMES[wind]}</span>
        <TeamMarker state={player.marker} />
        <span style={{ fontWeight: 700 }}>{player.name}</span>
        <span style={{ opacity: 0.85 }}>{player.score}点</span>
        {player.riichi && <span title="リーチ">🔴</span>}
        {isCurrent && <span title="手番">⌛</span>}
        <span style={{ opacity: 0.8 }}>🎫{player.chips}</span>
        {player.melds.length > 0 && (
          <span style={{ display: "flex", gap: 4, flexWrap: "wrap", marginLeft: "auto" }}>
            {player.melds.map((m, i) => (
              <MeldGroup key={i} meld={m} who={who} size="sm" />
            ))}
          </span>
        )}
      </div>
      <DiscardTiles discards={player.discards} riichiIndex={player.riichiDiscardIndex} mode="horizontal" />
    </div>
  );
}

function TablePond({ players, dealerIdx, round, dice, current }) {
  return (
    <div style={styles.tableSurface}>
      <div style={styles.sideRiverCol}>
        <RiverBlock player={players[2]} who={2} wind={seatWindOf(2, dealerIdx)} align="left" riichiIndex={players[2].riichiDiscardIndex} isCurrent={current === 2} sideRotate={90} />
      </div>
      <div style={styles.centerColumn}>
        <div style={styles.centerWallPanel}>東{round}局</div>
        <RiverBlock player={players[0]} who={0} wind={seatWindOf(0, dealerIdx)} align="left" riichiIndex={players[0].riichiDiscardIndex} isCurrent={current === 0} />
      </div>
      <div style={styles.sideRiverCol}>
        <RiverBlock player={players[1]} who={1} wind={seatWindOf(1, dealerIdx)} align="right" riichiIndex={players[1].riichiDiscardIndex} isCurrent={current === 1} sideRotate={-90} />
      </div>
    </div>
  );
}

function RulesPanel({ onClose }) {
  return (
    <div style={styles.modalOverlay} onClick={onClose}>
      <div style={styles.rulesCard} onClick={(e) => e.stopPropagation()}>
        <h3 style={{ marginTop: 0 }}>ルール確認・実装上の解釈</h3>
        <ul style={{ fontSize: 13, lineHeight: 1.7, paddingLeft: 18 }}>
          <li>萬子(1m〜9m)は全て廃止。牌は筒子・索子・字牌・花牌のみで構成。7pは8枚・7sは8枚(元4枚+差替4枚)で採用。手牌で7は最大4枚まで使用可。</li>
          <li>簡略化のため<b>チーは実装していません</b>(ポン・カン・ロン・ツモのみ)。</li>
          <li>暗槓・加槓・大明槓はいずれも任意選択制。可能なタイミングで「カンする／カンしない」を選べます。リーチ後は、ロン・ツモ・カン以外の場面では自動でツモ切りされます。</li>
          <li>誤操作防止のため、打牌は1回タップで選択→もう一度同じ牌をタップして確定という2段階になっています。</li>
          <li>和了時、まず裏ドラを1枚めくり、和了者の手牌にヒットした分は翻換算＆祝儀チップ対象。</li>
          <li>続けてチューリップ:<b>リーチ和了時のみ</b>有効。王牌の続きから1枚めくり、その牌の両隣(数牌は前後、字牌は東南西北・白發中の輪)に該当する牌を全員の手牌から数え、ヒット数=獲得チップ。(ダマ・ツモでもリーチ状態なら対象)</li>
          <li>【確変】和了に7pまたは7sを3枚以上使用→王牌の上下2枚を同時にめくる「上下段チューリップ」となり、めくった2枚それぞれについて隣接牌のヒットを判定。ヒットが続く限り連続してめくり続ける。</li>
          <li>【16R】7p・7sを両方3枚以上使用→確変継続＋最終チップ合計を2倍。</li>
          <li>【突確】1回のチューリップで6枚以上ヒットすると内部レベルが+1(現状は記録のみ)。</li>
          <li>七士無双:通常の国士無双の1萬子・9萬子の代わりに7ピンズ・7ソウズが入る特殊形。1p・9p・1s・9s・東南西北白發中・7p・7s の13種を各1枚以上＋そのうち1種を対子にして計14枚で成立(役満20枚、ロン・ツモ共通)。</li>
          <li>白ポッチ:白の4枚のうち1枚(中央に小さな赤い点の牌)。面前リーチ中に<b>白ポッチ自体をツモった</b>場合のみ、手牌が待っている牌を選んでツモ和了できます(待ちが複数ある場合は選択ポップアップが出ます)。他家が白ポッチを捨てた場合にロンすることはできません(通常の白としてポン等は可能)。すでに手牌に持っているだけの場合や、リーチ以外の場面では、ただの白として扱われます。</li>
          <li>花牌は1枚につき祝儀+3枚。花による突確なし。</li>
          <li>満塁ホームランスーパービンゴ(焼き鳥代わりのマーカー):全員「満塁」状態でスタート。①満塁中に和了すると祝儀はそのまま(×1)で受け取り、以後「ホームラン」状態に反転。②ホームラン状態での和了は祝儀が×2。③ホームラン状態の人が放銃(ロンされる)と満塁に反転。④ホームラン状態の人は、他家がツモ和了した際の支払い対象になると満塁に反転。⑤自分に関係のない他家同士のロン(点数のやり取りが自分を通らない場合)ではマーカーは変化しません。持ち点は1万点棒1本・5千点棒3本・千点棒5本の内訳で表示しています。</li>
          <li>東風戦・30000点持ち30000点返し・0点でトビ、役満は一律20枚(ロン・ツモ同額)。</li>
          <li>点数計算:1〜3飜は固定点数表を使用(親 1飜ロン2000/ツモ1000オール、2飜ロン4000/ツモ2000オール、3飜ロン6000/ツモ3000オール。子 1飜ロン1000/ツモ1000オール、2飜ロン2000/ツモ1000オール、3飜ロン4000/ツモ子1000・親3000)。4飜以上は満貫〜数え役満の点数表を使用:子は4〜5飜8000／6〜7飜12000／8〜10飜16000／11〜12飜24000／13飜以上32000(親はこの1.5倍)。ツモの支払いも、子の和了なら親3:子1の比率で綺麗な数字に振り分けています。</li>
          <li>オーラス親続行は本実装では常に連荘とする簡略仕様です。</li>
        </ul>
        <button style={styles.actBtn} onClick={onClose}>閉じる</button>
      </div>
    </div>
  );
}

const DIGITAL_BG =
  "linear-gradient(rgba(79,214,255,0.045) 1px, transparent 1px) 0 0/28px 28px," +
  "linear-gradient(90deg, rgba(79,214,255,0.045) 1px, transparent 1px) 0 0/28px 28px," +
  "radial-gradient(circle at 20% 0%, #16233a 0%, transparent 55%)," +
  "radial-gradient(circle at 85% 100%, #23163a 0%, transparent 55%)," +
  "#070a12";

const styles = {
  titleWrap: {
    minHeight: "100vh", display: "flex", alignItems: "center", justifyContent: "center",
    background: DIGITAL_BG, fontFamily: "'Hiragino Sans', sans-serif", color: "#eaf3ff",
  },
  titleCard: {
    background: "rgba(15,22,38,0.72)", backdropFilter: "blur(10px)", border: "1px solid rgba(79,214,255,0.35)", borderRadius: 20, padding: "36px 28px",
    textAlign: "center", maxWidth: 380, boxShadow: "0 0 40px #4fd6ff22, 0 20px 60px #000a",
  },
  titleFlower: { fontSize: 40 },
  titleH1: { margin: "6px 0 2px", fontSize: 26, letterSpacing: 2, textShadow: "0 0 18px #4fd6ff55" },
  titleSub: { color: "#e3b968", fontSize: 13, marginBottom: 14, letterSpacing: 1 },
  titleDesc: { fontSize: 12.5, opacity: 0.85, lineHeight: 1.7, marginBottom: 22 },
  bigBtn: {
    background: "linear-gradient(180deg,#5fe3ff,#2a8fd6)", color: "#04121c", border: "none",
    padding: "12px 28px", borderRadius: 999, fontSize: 15, fontWeight: 700, cursor: "pointer", boxShadow: "0 0 18px #4fd6ff77, 0 6px 16px #0006",
  },
  linkBtn: { display: "block", margin: "14px auto 0", background: "none", border: "none", color: "#7fd8ff", fontSize: 12, cursor: "pointer", textDecoration: "underline" },
  rankRow: { display: "flex", justifyContent: "space-between", gap: 10, padding: "8px 4px", borderBottom: "1px solid #ffffff1a", fontSize: 14 },
  rankNum: { color: "#e3b968", width: 40 },
  rankName: { flex: 1, textAlign: "left" },
  rankScore: { width: 80 },
  rankChip: { width: 70 },

  table: {
    height: "100dvh", minHeight: "100vh", width: "100vw", background: DIGITAL_BG,
    color: "#eaf3ff", fontFamily: "'Hiragino Sans', sans-serif", display: "flex", flexDirection: "column",
    overflow: "hidden", boxSizing: "border-box",
  },
  topBar: { display: "flex", alignItems: "center", gap: 8, padding: "4px 8px", fontSize: 11, flexShrink: 0, flexWrap: "wrap" },
  roundBadge: { background: "rgba(79,214,255,0.1)", border: "1px solid rgba(79,214,255,0.3)", padding: "2px 8px", borderRadius: 8, flexShrink: 0 },
  doraBox: { display: "flex", alignItems: "center", gap: 3, background: "rgba(79,214,255,0.08)", border: "1px solid rgba(79,214,255,0.25)", padding: "2px 6px", borderRadius: 8, flexShrink: 0 },
  doraLabel: { fontSize: 9, opacity: 0.7, marginRight: 2 },
  smallLink: { background: "rgba(79,214,255,0.08)", border: "1px solid #4fd6ff66", color: "#7fd8ff", borderRadius: 8, fontSize: 10, padding: "3px 7px", flexShrink: 0 },

  turnBanner: { flex: 1, textAlign: "center", fontSize: 11, overflow: "hidden", textOverflow: "ellipsis", whiteSpace: "nowrap" },
  turnBannerYou: { color: "#ffd98a", fontWeight: 700 },
  turnBannerCpu: { color: "#8fc9e8", opacity: 0.85 },

  windTag: {
    display: "inline-block", fontSize: 10, fontWeight: 800, color: "#20242c", background: "#e3b968",
    borderRadius: 4, padding: "1px 5px", marginRight: 3,
  },

  mainArea: { flex: "1 1 auto", minHeight: 0, display: "flex", padding: "0 8px" },
  tableSurface: {
    width: "100%", height: "100%", boxSizing: "border-box", padding: "4px 8px",
    background: "rgba(10,15,26,0.4)", border: "1px solid rgba(79,214,255,0.15)",
    borderRadius: 10, display: "flex", flexDirection: "row", gap: 6, minHeight: 0, overflow: "hidden",
  },
  sideRiverCol: { width: 118, flexShrink: 0, display: "flex", flexDirection: "column", minHeight: 0 },
  centerColumn: { flex: 1, minWidth: 0, display: "flex", flexDirection: "column", gap: 4, minHeight: 0 },
  riverBlock: {
    display: "flex", flexDirection: "column", flex: 1, minWidth: 0, minHeight: 0, overflowY: "auto", overflowX: "hidden",
    padding: "3px 4px", boxSizing: "border-box",
  },
  centerWallPanelRow: { display: "flex", justifyContent: "center", flexShrink: 0, marginBottom: 2 },
  riverStack: { flex: 1, minHeight: 0, display: "flex", flexDirection: "column", gap: 4, overflowY: "auto" },
  playerRiverRow: {
    display: "flex", flexDirection: "column", gap: 2, flexShrink: 0,
    padding: "3px 4px", background: "rgba(255,255,255,0.025)", border: "1px solid rgba(79,214,255,0.12)", borderRadius: 8,
  },
  riverHeader: { display: "flex", alignItems: "center", gap: 4, fontSize: 10, marginBottom: 2, flexWrap: "wrap" },
  playerInfoRow: {
    display: "flex", alignItems: "center", gap: 4, fontSize: 11, flexWrap: "wrap",
  },
  centerWallPanel: {
    display: "flex", alignItems: "center", justifyContent: "center", fontSize: 12, fontWeight: 800, color: "#7fd8ff",
    background: "linear-gradient(160deg,#1b2330,#0c1119)", border: "1px solid rgba(79,214,255,0.35)", borderRadius: 8,
    padding: "4px 14px", letterSpacing: 1, boxShadow: "inset 0 0 8px #00000080, 0 2px 6px #0006", minWidth: 56, textAlign: "center",
    alignSelf: "center", flexShrink: 0,
  },
  pondTiles: { display: "flex", flexDirection: "column", gap: 1, flex: 1 },
  pondTileRow: { display: "flex", gap: 1, flexWrap: "nowrap" },

  logStrip: {
    flexShrink: 0, padding: "0 10px", fontSize: 10, opacity: 0.7, height: 14, overflow: "hidden",
    whiteSpace: "nowrap", textOverflow: "ellipsis",
  },

  myArea: {
    flexShrink: 0, display: "flex", gap: 8, padding: "2px 8px 0", background: "rgba(10,15,26,0.5)",
    boxSizing: "border-box",
  },
  myInfoCol: { display: "flex", flexDirection: "column", gap: 1, width: 84, flexShrink: 0, justifyContent: "center" },
  handCol: { flex: 1, minWidth: 0, display: "flex", flexDirection: "column", justifyContent: "center" },
  meldRowCompact: { display: "flex", gap: 4, flexWrap: "wrap", marginTop: 2 },
  meldGroup: { display: "flex", alignItems: "center", gap: 1, background: "rgba(255,255,255,0.06)", borderRadius: 5, padding: "2px 3px" },
  handLabel: { fontSize: 10, opacity: 0.7, marginBottom: 2 },
  handRow: { display: "flex", flexWrap: "nowrap", gap: 3, marginBottom: 2, minHeight: 44, alignItems: "flex-end", overflowX: "auto", paddingBottom: 2 },
  drawnGap: { marginLeft: 8 },
  actionRow: { display: "flex", gap: 8, alignItems: "center", minHeight: 16, paddingBottom: 2 },
  actBtn: {
    background: "linear-gradient(180deg,#5fe3ff,#2a8fd6)", color: "#04121c", border: "none",
    padding: "6px 16px", borderRadius: 10, fontSize: 13, fontWeight: 700, cursor: "pointer", boxShadow: "0 0 12px #4fd6ff55",
  },
  skipBtn: { background: "rgba(255,255,255,0.08)", color: "#eaf3ff", border: "1px solid rgba(255,255,255,0.18)", padding: "6px 16px", borderRadius: 10, fontSize: 13, cursor: "pointer" },

  modalOverlay: { position: "fixed", inset: 0, background: "#02040aa8", backdropFilter: "blur(2px)", display: "flex", alignItems: "center", justifyContent: "center", zIndex: 50, padding: 16 },
  splashOverlay: {
    position: "fixed", inset: 0, display: "flex", alignItems: "center", justifyContent: "center",
    pointerEvents: "none", zIndex: 200,
  },
  splashText: {
    fontSize: 48, fontWeight: 900, color: "#ff8a3d", WebkitTextStroke: "3px #3a1400",
    textShadow: "0 0 24px #ff6a1e99, 0 4px 0 #7a2c05, 0 6px 14px #000a",
    transform: "rotate(-8deg)", letterSpacing: 2, fontFamily: "'Hiragino Sans', sans-serif",
  },
  modalCard: { background: "rgba(13,20,34,0.92)", border: "1px solid rgba(79,214,255,0.3)", borderRadius: 14, padding: 18, textAlign: "center", color: "#eaf3ff", boxShadow: "0 0 30px #4fd6ff22", maxHeight: "88vh", overflowY: "auto" },
  modalCardWide: { background: "rgba(13,20,34,0.92)", border: "1px solid rgba(79,214,255,0.3)", borderRadius: 14, padding: 18, textAlign: "center", color: "#eaf3ff", maxWidth: 420, width: "100%", maxHeight: "88vh", overflowY: "auto", boxShadow: "0 0 30px #4fd6ff22" },
  scoreChip: { fontSize: 10, background: "rgba(79,214,255,0.1)", border: "1px solid rgba(79,214,255,0.25)", borderRadius: 6, padding: "3px 6px" },
  yakuTag: {
    fontSize: 12, fontWeight: 700, background: "rgba(255,217,138,0.12)", border: "1px solid rgba(255,217,138,0.5)",
    color: "#ffd98a", borderRadius: 999, padding: "4px 10px",
  },
  rulesCard: { background: "rgba(13,20,34,0.94)", border: "1px solid rgba(79,214,255,0.3)", borderRadius: 14, padding: 20, color: "#eaf3ff", maxWidth: 420, maxHeight: "80vh", overflowY: "auto" },
};
