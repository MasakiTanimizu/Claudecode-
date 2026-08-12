import Link from "next/link";
import { prisma } from "@/lib/prisma";

export const dynamic = "force-dynamic";

export default async function FishingReportsPage({
  searchParams,
}: {
  searchParams: Promise<{ fishSpeciesId?: string; prefectureId?: string }>;
}) {
  const params = await searchParams;
  const fishSpeciesId = params.fishSpeciesId ? Number(params.fishSpeciesId) : undefined;
  const prefectureId = params.prefectureId ? Number(params.prefectureId) : undefined;

  const [reports, species, prefectures] = await Promise.all([
    prisma.fishingReport.findMany({
      where: {
        ...(fishSpeciesId ? { fishSpeciesId } : {}),
        ...(prefectureId ? { prefectureId } : {}),
      },
      include: { fishSpecies: true, prefecture: true, fishingSpot: true, fishingMethod: true },
      orderBy: [{ fishingDate: "desc" }, { createdAt: "desc" }],
      take: 50,
    }),
    prisma.fishSpecies.findMany({ where: { isActive: true }, orderBy: { id: "asc" } }),
    prisma.prefecture.findMany({ where: { isActive: true }, orderBy: { id: "asc" } }),
  ]);

  return (
    <div className="space-y-6">
      <div className="flex items-center justify-between">
        <h1 className="text-lg font-bold">釣果情報</h1>
        <Link
          href="/fishing-reports/new"
          className="rounded-md bg-ocean-600 px-3 py-1.5 text-sm text-white hover:bg-ocean-700"
        >
          釣果を登録
        </Link>
      </div>

      <form className="flex flex-wrap gap-2 text-sm" method="get">
        <select
          name="prefectureId"
          defaultValue={params.prefectureId ?? ""}
          className="rounded-md border border-slate-300 px-2 py-1"
        >
          <option value="">すべての都道府県</option>
          {prefectures.map((p) => (
            <option key={p.id} value={p.id}>
              {p.name}
            </option>
          ))}
        </select>
        <select
          name="fishSpeciesId"
          defaultValue={params.fishSpeciesId ?? ""}
          className="rounded-md border border-slate-300 px-2 py-1"
        >
          <option value="">すべての魚種</option>
          {species.map((s) => (
            <option key={s.id} value={s.id}>
              {s.name}
            </option>
          ))}
        </select>
        <button type="submit" className="rounded-md border border-slate-300 px-3 py-1 hover:bg-slate-100">
          絞り込む
        </button>
      </form>

      {reports.length === 0 ? (
        <p className="text-sm text-slate-500">該当する釣果情報がありません。</p>
      ) : (
        <ul className="space-y-3">
          {reports.map((r) => (
            <li key={r.id} className="rounded-lg border border-slate-200 bg-white p-4">
              <div className="flex items-center justify-between">
                <span className="font-semibold">{r.fishSpecies.name}</span>
                <span className="text-xs text-slate-400">
                  信頼度 {Number(r.confidenceScore)}
                </span>
              </div>
              <p className="mt-1 text-sm text-slate-600">
                {r.prefecture.name}
                {r.fishingSpot ? ` / ${r.fishingSpot.name}` : ""}
                {r.fishingMethod ? ` / ${r.fishingMethod.name}` : ""}
              </p>
              <p className="mt-1 text-sm text-slate-500">
                {r.catchCount != null ? `釣果数: ${r.catchCount}匹 ` : ""}
                {r.minSize != null || r.maxSize != null
                  ? `サイズ: ${r.minSize ?? "?"}〜${r.maxSize ?? "?"}${r.sizeUnit ?? "cm"}`
                  : ""}
                {r.sizeEstimationMethod === "IMAGE_AI" ? "（AI画像推定）" : ""}
              </p>
              <p className="mt-2 whitespace-pre-wrap text-sm text-slate-700">{r.originalText}</p>
              <a
                href={r.sourceUrl}
                target="_blank"
                rel="noreferrer noopener"
                className="mt-2 inline-block text-xs text-ocean-600 hover:underline"
              >
                情報源を見る
              </a>
            </li>
          ))}
        </ul>
      )}
    </div>
  );
}
