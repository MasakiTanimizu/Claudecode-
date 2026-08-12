/**
 * マスタデータ投入スクリプト (指示書 Step 3)
 *
 * ここで投入するのは「マスタ(参照)データ」であり、釣果実績(fishing_reports)は含めない。
 * 釣果情報は指示書58項の原則により、実データの収集・登録によってのみ作成する。
 *
 * sources (情報源) は、ユーザーから提供される参照URLをもとに登録する方針のため、
 * このシードでは投入しない (docs/DEVELOPMENT_LOG.md 参照)。
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

async function main() {
  await seedPrefectures();
  await seedFishSpecies();
  await seedFishingMethods();
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
