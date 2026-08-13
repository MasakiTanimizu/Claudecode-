import { NextResponse } from "next/server";
import { prisma } from "@/lib/prisma";

export async function GET(request: Request) {
  const { searchParams } = new URL(request.url);
  const prefectureId = searchParams.get("prefectureId");

  const spots = await prisma.fishingSpot.findMany({
    where: {
      isActive: true,
      ...(prefectureId ? { prefectureId: Number(prefectureId) } : {}),
    },
    include: { prefecture: true, city: true },
    orderBy: { id: "asc" },
  });

  return NextResponse.json({ data: spots });
}
