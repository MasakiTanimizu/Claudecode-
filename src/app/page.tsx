import { prisma } from "@/lib/prisma";

// 釣果情報は随時更新されるため、ビルド時の静的生成ではなく常に最新データを取得する
export const dynamic = "force-dynamic";

export default async function HomePage() {
  const [reportCount, speciesCount, latestReports] = await Promise.all([
    prisma.fishingReport.count(),
    prisma.fishSpecies.count({ where: { isActive: true } }),
    prisma.fishingReport.findMany({
      take: 5,
      orderBy: [{ fishingDate: "desc" }, { createdAt: "desc" }],
      include: { fishSpecies: true, prefecture: true, fishingSpot: true },
    }),
  ]);

  return (
    <div className="space-y-8">
      <section className="rounded-xl bg-ocean-700 p-6 text-white">
        <h1 className="text-xl font-bold">今日の近畿釣果</h1>
        <p className="mt-2 text-sm text-ocean-50">
          兵庫・大阪・和歌山の釣果情報を蓄積し、AIが分析する釣りコンシェルジュを目指しています。
        </p>
      </section>

      <section className="grid grid-cols-2 gap-4">
        <div className="rounded-lg border border-slate-200 bg-white p-4">
          <p className="text-xs text-slate-500">登録された釣果情報</p>
          <p className="mt-1 text-2xl font-bold text-ocean-700">{reportCount}件</p>
        </div>
        <div className="rounded-lg border border-slate-200 bg-white p-4">
          <p className="text-xs text-slate-500">対象魚種</p>
          <p className="mt-1 text-2xl font-bold text-ocean-700">{speciesCount}種</p>
        </div>
      </section>

      <section className="rounded-lg border border-slate-200 bg-white p-4">
        <h2 className="font-semibold">おすすめ魚 / 釣果期待度 / おすすめポイント</h2>
        <p className="mt-2 text-sm text-slate-500">
          AIによる釣果期待度ランキングと日次ニュースは、十分な釣果データと天候・潮汐データが蓄積された後
          (Phase2〜3) に提供予定です。現時点では架空の予測を表示しません。
        </p>
      </section>

      <section>
        <h2 className="mb-2 font-semibold">最新の釣果情報</h2>
        {latestReports.length === 0 ? (
          <p className="text-sm text-slate-500">
            まだ釣果情報が登録されていません。「釣果を登録」から最初の情報を登録できます。
          </p>
        ) : (
          <ul className="space-y-2">
            {latestReports.map((r) => (
              <li key={r.id} className="rounded-lg border border-slate-200 bg-white p-3 text-sm">
                <span className="font-medium">{r.fishSpecies.name}</span>
                {" — "}
                {r.prefecture.name}
                {r.fishingSpot ? ` / ${r.fishingSpot.name}` : ""}
                {r.catchCount != null ? ` / ${r.catchCount}匹` : ""}
              </li>
            ))}
          </ul>
        )}
      </section>
    </div>
  );
}
