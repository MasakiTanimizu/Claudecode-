"use client";

import { useEffect, useState, type FormEvent } from "react";
import { useRouter } from "next/navigation";

type Prefecture = { id: number; name: string };
type FishSpecies = { id: number; name: string };
type FishingMethod = { id: number; name: string };

export default function NewFishingReportPage() {
  const router = useRouter();
  const [prefectures, setPrefectures] = useState<Prefecture[]>([]);
  const [species, setSpecies] = useState<FishSpecies[]>([]);
  const [methods, setMethods] = useState<FishingMethod[]>([]);
  const [error, setError] = useState<string | null>(null);
  const [submitting, setSubmitting] = useState(false);

  useEffect(() => {
    Promise.all([
      fetch("/api/prefectures").then((r) => r.json()),
      fetch("/api/fish-species").then((r) => r.json()),
      fetch("/api/fishing-methods").then((r) => r.json()),
    ]).then(([p, s, m]) => {
      setPrefectures(p.data);
      setSpecies(s.data);
      setMethods(m.data);
    });
  }, []);

  async function handleSubmit(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    setError(null);
    setSubmitting(true);

    const form = new FormData(event.currentTarget);
    const toNumberOrUndefined = (v: FormDataEntryValue | null) =>
      v && String(v).trim() !== "" ? Number(v) : undefined;

    const payload = {
      sourceUrl: String(form.get("sourceUrl") ?? ""),
      originalText: String(form.get("originalText") ?? ""),
      prefectureId: toNumberOrUndefined(form.get("prefectureId")),
      fishSpeciesId: toNumberOrUndefined(form.get("fishSpeciesId")),
      fishingMethodId: toNumberOrUndefined(form.get("fishingMethodId")),
      catchCount: toNumberOrUndefined(form.get("catchCount")),
      minSize: toNumberOrUndefined(form.get("minSize")),
      maxSize: toNumberOrUndefined(form.get("maxSize")),
      sizeUnit: form.get("minSize") || form.get("maxSize") ? "cm" : undefined,
      baitRaw: String(form.get("baitRaw") ?? "") || undefined,
      lureRaw: String(form.get("lureRaw") ?? "") || undefined,
      timeOfDay: String(form.get("timeOfDay") ?? "") || undefined,
    };

    const res = await fetch("/api/fishing-reports", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify(payload),
    });

    setSubmitting(false);

    if (!res.ok) {
      const body = await res.json().catch(() => ({}));
      setError(body.error ?? "登録に失敗しました");
      return;
    }

    router.push("/fishing-reports");
    router.refresh();
  }

  return (
    <div className="space-y-4">
      <h1 className="text-lg font-bold">釣果情報を登録</h1>
      <p className="text-sm text-slate-500">
        原文と情報源URLは必須です。AIによる推測値は含めず、実際に確認できた情報のみを入力してください。
      </p>

      {error && (
        <p className="rounded-md bg-red-50 p-2 text-sm text-red-600">{error}</p>
      )}

      <form onSubmit={handleSubmit} className="space-y-3 text-sm">
        <div>
          <label className="block font-medium">情報源URL *</label>
          <input
            name="sourceUrl"
            type="url"
            required
            placeholder="https://example.com/report"
            className="mt-1 w-full rounded-md border border-slate-300 px-2 py-1.5"
          />
        </div>

        <div>
          <label className="block font-medium">原文 *</label>
          <textarea
            name="originalText"
            required
            rows={4}
            placeholder="例: 夕方、明石で1gジグヘッドと2インチワームを使ってアジを15匹。最大24cm。"
            className="mt-1 w-full rounded-md border border-slate-300 px-2 py-1.5"
          />
        </div>

        <div className="grid grid-cols-2 gap-3">
          <div>
            <label className="block font-medium">都道府県 *</label>
            <select name="prefectureId" required className="mt-1 w-full rounded-md border border-slate-300 px-2 py-1.5">
              <option value="">選択してください</option>
              {prefectures.map((p) => (
                <option key={p.id} value={p.id}>
                  {p.name}
                </option>
              ))}
            </select>
          </div>
          <div>
            <label className="block font-medium">魚種 *</label>
            <select name="fishSpeciesId" required className="mt-1 w-full rounded-md border border-slate-300 px-2 py-1.5">
              <option value="">選択してください</option>
              {species.map((s) => (
                <option key={s.id} value={s.id}>
                  {s.name}
                </option>
              ))}
            </select>
          </div>
        </div>

        <div className="grid grid-cols-3 gap-3">
          <div>
            <label className="block font-medium">釣法</label>
            <select name="fishingMethodId" className="mt-1 w-full rounded-md border border-slate-300 px-2 py-1.5">
              <option value="">不明</option>
              {methods.map((m) => (
                <option key={m.id} value={m.id}>
                  {m.name}
                </option>
              ))}
            </select>
          </div>
          <div>
            <label className="block font-medium">釣果数</label>
            <input name="catchCount" type="number" min={0} className="mt-1 w-full rounded-md border border-slate-300 px-2 py-1.5" />
          </div>
          <div>
            <label className="block font-medium">時間帯</label>
            <input name="timeOfDay" placeholder="例: 夕方" className="mt-1 w-full rounded-md border border-slate-300 px-2 py-1.5" />
          </div>
        </div>

        <div className="grid grid-cols-2 gap-3">
          <div>
            <label className="block font-medium">最小サイズ(cm)</label>
            <input name="minSize" type="number" step="0.1" min={0} className="mt-1 w-full rounded-md border border-slate-300 px-2 py-1.5" />
          </div>
          <div>
            <label className="block font-medium">最大サイズ(cm)</label>
            <input name="maxSize" type="number" step="0.1" min={0} className="mt-1 w-full rounded-md border border-slate-300 px-2 py-1.5" />
          </div>
        </div>

        <div className="grid grid-cols-2 gap-3">
          <div>
            <label className="block font-medium">餌</label>
            <input name="baitRaw" className="mt-1 w-full rounded-md border border-slate-300 px-2 py-1.5" />
          </div>
          <div>
            <label className="block font-medium">ルアー/ジグヘッド等</label>
            <input name="lureRaw" className="mt-1 w-full rounded-md border border-slate-300 px-2 py-1.5" />
          </div>
        </div>

        <button
          type="submit"
          disabled={submitting}
          className="w-full rounded-md bg-ocean-600 py-2 font-medium text-white hover:bg-ocean-700 disabled:opacity-50"
        >
          {submitting ? "登録中..." : "登録する"}
        </button>
      </form>
    </div>
  );
}
