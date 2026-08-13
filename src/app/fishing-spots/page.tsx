import { prisma } from "@/lib/prisma";

export const dynamic = "force-dynamic";

export default async function FishingSpotsPage() {
  const spots = await prisma.fishingSpot.findMany({
    where: { isActive: true },
    orderBy: { id: "asc" },
    include: { prefecture: true, city: true },
  });

  return (
    <div className="space-y-4">
      <h1 className="text-lg font-bold">釣り場マスタ</h1>
      <p className="text-sm text-slate-500">
        釣り場情報はまだ登録されていません。釣果情報の収集・登録が進むにつれて追加されます。
      </p>
      {spots.length > 0 && (
        <ul className="space-y-2">
          {spots.map((s) => (
            <li key={s.id} className="rounded-lg border border-slate-200 bg-white p-3 text-sm">
              <p className="font-medium">{s.name}</p>
              <p className="text-xs text-slate-400">
                {s.prefecture.name}
                {s.city ? ` ${s.city.name}` : ""}
              </p>
            </li>
          ))}
        </ul>
      )}
    </div>
  );
}
