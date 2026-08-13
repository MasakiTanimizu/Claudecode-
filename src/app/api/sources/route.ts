import { NextResponse } from "next/server";
import { prisma } from "@/lib/prisma";

export async function GET() {
  const sources = await prisma.source.findMany({
    orderBy: { trustScore: "desc" },
  });

  return NextResponse.json({ data: sources });
}
