import { NextResponse } from "next/server";
import { prisma } from "@/lib/prisma";

export async function GET(request: Request) {
  const { searchParams } = new URL(request.url);
  const includeInactive = searchParams.get("includeInactive") === "true";

  const prefectures = await prisma.prefecture.findMany({
    where: includeInactive ? undefined : { isActive: true },
    orderBy: { id: "asc" },
  });

  return NextResponse.json({ data: prefectures });
}
