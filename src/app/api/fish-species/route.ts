import { NextResponse } from "next/server";
import { prisma } from "@/lib/prisma";

export async function GET(request: Request) {
  const { searchParams } = new URL(request.url);
  const query = searchParams.get("q")?.trim();

  const species = await prisma.fishSpecies.findMany({
    where: {
      isActive: true,
      ...(query ? { name: { contains: query } } : {}),
    },
    orderBy: { id: "asc" },
  });

  return NextResponse.json({ data: species });
}
