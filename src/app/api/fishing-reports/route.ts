import { NextResponse } from "next/server";
import { ZodError } from "zod";
import { prisma } from "@/lib/prisma";
import { createFishingReportSchema } from "@/lib/validation";

export async function GET(request: Request) {
  const { searchParams } = new URL(request.url);
  const fishSpeciesId = searchParams.get("fishSpeciesId");
  const fishingSpotId = searchParams.get("fishingSpotId");
  const prefectureId = searchParams.get("prefectureId");
  const limitParam = Number(searchParams.get("limit") ?? "20");
  const limit = Number.isFinite(limitParam) ? Math.min(Math.max(limitParam, 1), 100) : 20;

  const reports = await prisma.fishingReport.findMany({
    where: {
      ...(fishSpeciesId ? { fishSpeciesId: Number(fishSpeciesId) } : {}),
      ...(fishingSpotId ? { fishingSpotId: Number(fishingSpotId) } : {}),
      ...(prefectureId ? { prefectureId: Number(prefectureId) } : {}),
    },
    include: {
      prefecture: true,
      city: true,
      fishingSpot: true,
      fishSpecies: true,
      fishingMethod: true,
      source: true,
    },
    orderBy: [{ fishingDate: "desc" }, { createdAt: "desc" }],
    take: limit,
  });

  return NextResponse.json({ data: reports });
}

export async function POST(request: Request) {
  let body: unknown;
  try {
    body = await request.json();
  } catch {
    return NextResponse.json({ error: "リクエストボディがJSONではありません" }, { status: 400 });
  }

  let input;
  try {
    input = createFishingReportSchema.parse(body);
  } catch (error) {
    if (error instanceof ZodError) {
      return NextResponse.json({ error: "入力値が不正です", details: error.flatten() }, { status: 400 });
    }
    throw error;
  }

  const prefecture = await prisma.prefecture.findUnique({ where: { id: input.prefectureId } });
  if (!prefecture) {
    return NextResponse.json({ error: "指定された都道府県が存在しません" }, { status: 400 });
  }

  const fishSpecies = await prisma.fishSpecies.findUnique({ where: { id: input.fishSpeciesId } });
  if (!fishSpecies) {
    return NextResponse.json({ error: "指定された魚種が存在しません" }, { status: 400 });
  }

  const source = input.sourceId
    ? await prisma.source.findUnique({ where: { id: input.sourceId } })
    : null;

  // サイズが記載されている場合は「実測値(TEXT)」として保存する。
  // 画像AIによる推定はPhase2 (Agent3 画像解析エージェント) で別途上書きする。
  const hasSize = input.minSize !== undefined || input.maxSize !== undefined || input.averageSize !== undefined;

  // confidence_scoreは情報源の信頼度(指示書6項)を初期値とする。情報源未登録の場合は中立値。
  const confidenceScore = source?.trustScore ?? 50;

  const report = await prisma.fishingReport.create({
    data: {
      sourceId: input.sourceId,
      sourceUrl: input.sourceUrl,
      originalText: input.originalText,
      fishingDate: input.fishingDate ? new Date(input.fishingDate) : undefined,
      publishedAt: input.publishedAt ? new Date(input.publishedAt) : undefined,
      prefectureId: input.prefectureId,
      cityId: input.cityId,
      fishingSpotId: input.fishingSpotId,
      fishSpeciesId: input.fishSpeciesId,
      catchCount: input.catchCount,
      minSize: input.minSize,
      maxSize: input.maxSize,
      averageSize: input.averageSize,
      sizeUnit: input.sizeUnit,
      sizeEstimationMethod: hasSize ? "TEXT" : "UNKNOWN",
      fishingMethodId: input.fishingMethodId,
      baitRaw: input.baitRaw,
      lureRaw: input.lureRaw,
      tackleRawText: input.tackleRawText,
      timeOfDay: input.timeOfDay,
      confidenceScore,
    },
    include: {
      prefecture: true,
      fishSpecies: true,
      fishingSpot: true,
      fishingMethod: true,
    },
  });

  return NextResponse.json({ data: report }, { status: 201 });
}
