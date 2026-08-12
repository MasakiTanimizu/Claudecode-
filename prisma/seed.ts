/**
 * マスタデータ投入スクリプト (指示書 Step 3)
 *
 * ここで投入するのは「マスタ(参照)データ」であり、釣果実績(fishing_reports)は含めない。
 * 釣果情報は指示書58項の原則により、実データの収集・登録によってのみ作成する。
 *
 * sources (情報源) はユーザーから提供された参照URLを登録する。ただし本開発環境からは
 * 外部サイトのrobots.txt・利用規約を確認できない(ネットワーク制限)ため、
 * 全件 fetchAllowed=false (要確認) として登録する。実際のクロール実装前に、
 * 到達可能な環境でrobots.txt・利用規約を確認し、fetchAllowed/fetchMethodを更新すること
 * (指示書41項)。
 */
import { PrismaClient } from "@prisma/client";

const prisma = new PrismaClient();

async function seedPrefectures() {
  const prefectures = [
    { name: "兵庫県", nameKana: "ひょうごけん", isActive: true },
    { name: "大阪府", nameKana: "おおさかふ", isActive: true },
    { name: "和歌山県", nameKana: "わかやまけん", isActive: true },
    // 将来拡張対象 (指示書2項) — 現時点は非公開
    { name: "京都府", nameKana: "きょうとふ", isActive: false },
    { name: "奈良県", nameKana: "ならけん", isActive: false },
    { name: "滋賀県", nameKana: "しがけん", isActive: false },
    { name: "三重県", nameKana: "みえけん", isActive: false },
  ];

  for (const p of prefectures) {
    await prisma.prefecture.upsert({
      where: { name: p.name },
      update: { nameKana: p.nameKana, isActive: p.isActive },
      create: p,
    });
  }
}

async function seedFishSpecies() {
  const species: { name: string; category: string }[] = [
    { name: "アジ", category: "回遊魚" },
    { name: "サバ", category: "回遊魚" },
    { name: "イワシ", category: "回遊魚" },
    { name: "ブリ", category: "青物" },
    { name: "ハマチ", category: "青物" },
    { name: "メジロ", category: "青物" },
    { name: "シーバス", category: "ルアー対象魚" },
    { name: "タチウオ", category: "太刀魚" },
    { name: "メバル", category: "根魚" },
    { name: "カサゴ", category: "根魚" },
    { name: "ガシラ", category: "根魚" },
    { name: "アオリイカ", category: "イカ類" },
    { name: "コウイカ", category: "イカ類" },
    { name: "チヌ", category: "クロダイ" },
    { name: "グレ", category: "メジナ" },
    { name: "マダイ", category: "タイ科" },
    { name: "キス", category: "砂地魚" },
    { name: "カレイ", category: "底物" },
    { name: "ヒラメ", category: "底物" },
    { name: "マゴチ", category: "底物" },
  ];

  for (const s of species) {
    await prisma.fishSpecies.upsert({
      where: { name: s.name },
      update: { category: s.category },
      create: { ...s, isActive: true },
    });
  }
}

async function seedFishingMethods() {
  const methods = [
    "サビキ",
    "アジング",
    "メバリング",
    "エギング",
    "ショアジギング",
    "ライトショアジギング",
    "スーパーライトショアジギング",
    "ジギング",
    "タイラバ",
    "ティップラン",
    "泳がせ",
    "穴釣り",
    "投げ釣り",
    "フカセ",
    "カゴ釣り",
    "落とし込み",
    "ルアー",
    "エサ釣り",
    "その他",
  ];

  for (const name of methods) {
    await prisma.fishingMethod.upsert({
      where: { name },
      update: {},
      create: { name },
    });
  }
}

const UNVERIFIED_NOTE =
  "robots.txt/利用規約 未確認 (本開発環境は外部ネットワークへのアクセスが遮断されているため)。" +
  "到達可能な環境で確認のうえ fetchAllowed を更新すること。";

async function seedSources() {
  const sources: {
    name: string;
    url: string;
    sourceType: string;
    trustScore: number;
  }[] = [
    {
      name: "Yahoo!天気・災害",
      url: "https://weather.yahoo.co.jp/weather/",
      sourceType: "気象ポータル",
      trustScore: 85,
    },
    {
      name: "大阪の天気 - Yahoo!天気・災害",
      url: "https://weather.yahoo.co.jp/weather/jp/27/6200.html",
      sourceType: "気象ポータル",
      trustScore: 85,
    },
    {
      name: "フィッシングマックス 関西の釣果",
      url: "https://fishingmax.co.jp/",
      sourceType: "釣具店公式",
      trustScore: 95,
    },
    {
      name: "釣果記事 | フィッシングマックス",
      url: "https://fishingmax.co.jp/fishingpost",
      sourceType: "釣具店公式",
      trustScore: 95,
    },
    {
      name: "フィッシングマックス 店舗情報（南津守店）",
      url: "https://fishingmax.co.jp/shoplist/tsumori",
      sourceType: "釣具店公式",
      trustScore: 95,
    },
    {
      name: "エギCOM（エギ王）近畿の釣果情報",
      url: "https://www.yamaria.com/community/catch/egiou/regions/5",
      sourceType: "メーカー公式",
      trustScore: 95,
    },
    {
      name: "釣果情報サイト カンパリ（関西エギング）",
      url: "https://fishing.ne.jp/fishingpost/area/kansai?howto=howto-eging",
      sourceType: "釣りメディア",
      trustScore: 80,
    },
    {
      name: "つり具の上州屋",
      url: "https://www.johshuya.co.jp/",
      sourceType: "釣具店公式",
      trustScore: 95,
    },
    {
      name: "釣具のキャスティング",
      url: "https://castingnet.jp/",
      sourceType: "釣具店公式",
      trustScore: 95,
    },
    {
      name: "キャスティングオンラインストア",
      url: "https://store.castingnet.jp/shop/default.aspx",
      sourceType: "釣具店公式",
      trustScore: 95,
    },
  ];

  for (const s of sources) {
    await prisma.source.upsert({
      where: { url: s.url },
      update: {
        name: s.name,
        sourceType: s.sourceType,
        trustScore: s.trustScore,
      },
      create: {
        ...s,
        fetchMethod: "UNVERIFIED",
        fetchAllowed: false,
        notes: UNVERIFIED_NOTE,
      },
    });
  }
}

async function main() {
  await seedPrefectures();
  await seedFishSpecies();
  await seedFishingMethods();
  await seedSources();
  // eslint-disable-next-line no-console
  console.log("マスタデータの投入が完了しました。");
}

main()
  .catch((e) => {
    console.error(e);
    process.exit(1);
  })
  .finally(async () => {
    await prisma.$disconnect();
  });
