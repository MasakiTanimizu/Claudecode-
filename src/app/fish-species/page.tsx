import { prisma } from "@/lib/prisma";

export const dynamic = "force-dynamic";

export default async function FishSpeciesPage() {
  const species = await prisma.fishSpecies.findMany({
    where: { isActive: true },
    orderBy: { id: "asc" },
    include: { _count: { select: { fishingReports: true } } },
  });

  return (
    <div className="space-y-4">
      <h1 className="text-lg font-bold">魚種マスタ</h1>
      <p className="text-sm text-slate-500">
        対象地域で釣れる可能性のある魚種を管理しています。新しい魚種は管理画面(Phase2以降)から追加できます。
      </p>
      <ul className="grid grid-cols-2 gap-2 sm:grid-cols-3">
        {species.map((s) => (
          <li key={s.id} className="rounded-lg border border-slate-200 bg-white p-3 text-sm">
            <p className="font-medium">{s.name}</p>
            <p className="text-xs text-slate-400">{s.category}</p>
            <p className="mt-1 text-xs text-slate-500">釣果情報 {s._count.fishingReports}件</p>
          </li>
        ))}
      </ul>
    </div>
  );
}
