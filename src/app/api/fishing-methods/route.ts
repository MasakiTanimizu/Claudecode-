import { NextResponse } from "next/server";
import { prisma } from "@/lib/prisma";

export async function GET() {
  const methods = await prisma.fishingMethod.findMany({
    orderBy: { id: "asc" },
  });

  return NextResponse.json({ data: methods });
}
