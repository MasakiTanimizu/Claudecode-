import { NextResponse } from "next/server";
import { prisma } from "@/lib/prisma";

export async function GET(
  _request: Request,
  { params }: { params: Promise<{ id: string }> },
) {
  const { id } = await params;
  const reportId = Number(id);
  if (!Number.isInteger(reportId)) {
    return NextResponse.json({ error: "不正なIDです" }, { status: 400 });
  }

  const report = await prisma.fishingReport.findUnique({
    where: { id: reportId },
    include: {
      prefecture: true,
      city: true,
      fishingSpot: true,
      fishSpecies: true,
      fishingMethod: true,
      bait: true,
      lure: true,
      rod: true,
      reel: true,
      source: true,
      images: true,
      aiAnalyses: true,
    },
  });

  if (!report) {
    return NextResponse.json({ error: "釣果情報が見つかりません" }, { status: 404 });
  }

  return NextResponse.json({ data: report });
}
