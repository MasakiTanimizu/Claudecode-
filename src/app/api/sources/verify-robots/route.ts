import { NextResponse } from "next/server";
import { prisma } from "@/lib/prisma";
import { fetchRobotsTxt, isAllowedByRobots, type RobotsFetchResult } from "@/lib/robots";

/**
 * 登録済みsourcesを巡回し、robots.txtに基づいてfetch_allowedを更新するエンドポイント。
 *
 * 注意: これはrobots.txtの技術的な確認のみを行う。著作権・利用規約(指示書41項)の
 * 人手確認は別途必要であり、このエンドポイントはそれを代替しない。
 *
 * 管理画面(指示書33項)が未実装のため、暫定的にADMIN_API_SECRETヘッダー認証で保護する。
 * 環境変数が未設定の場合は安全側に倒して常に無効化する。
 */
export async function POST(request: Request) {
  const secret = process.env.ADMIN_API_SECRET;
  if (!secret) {
    return NextResponse.json(
      { error: "ADMIN_API_SECRETが未設定のため、このエンドポイントは無効化されています" },
      { status: 503 },
    );
  }
  if (request.headers.get("x-admin-secret") !== secret) {
    return NextResponse.json({ error: "認証に失敗しました" }, { status: 401 });
  }

  const sources = await prisma.source.findMany({ where: { isActive: true } });

  const robotsCache = new Map<string, Promise<RobotsFetchResult>>();
  const getRobots = (origin: string) => {
    let cached = robotsCache.get(origin);
    if (!cached) {
      cached = fetchRobotsTxt(origin);
      robotsCache.set(origin, cached);
    }
    return cached;
  };

  const results: {
    id: number;
    name: string;
    url: string;
    fetchAllowed: boolean | null;
    detail: string;
  }[] = [];

  for (const source of sources) {
    const checkedAt = new Date();
    let origin: string;
    try {
      origin = new URL(source.url).origin;
    } catch {
      results.push({
        id: source.id,
        name: source.name,
        url: source.url,
        fetchAllowed: null,
        detail: "不正なURLのため確認できませんでした",
      });
      continue;
    }

    const robotsResult = await getRobots(origin);

    let fetchAllowed: boolean;
    let fetchMethod: string;
    let lastError: string | null = null;
    let notes: string;

    if (robotsResult.status === "fetched") {
      fetchAllowed = isAllowedByRobots(robotsResult.robots, source.url);
      fetchMethod = fetchAllowed ? "SCRAPING_ROBOTS_ALLOWED" : "SCRAPING_ROBOTS_DISALLOWED";
      notes =
        `robots.txtでは${fetchAllowed ? "許可" : "禁止"}されています` +
        `(確認日時: ${checkedAt.toISOString()})。robots.txtのみの技術的判定であり、` +
        `著作権・利用規約の人手確認(指示書41項)は別途必要です。`;
    } else if (robotsResult.status === "not_found") {
      fetchAllowed = true;
      fetchMethod = "SCRAPING_ROBOTS_NOT_FOUND";
      notes =
        `robots.txtが存在しないため制限なしと解釈しました(確認日時: ${checkedAt.toISOString()})。` +
        `著作権・利用規約の人手確認(指示書41項)は別途必要です。`;
    } else {
      // 取得エラー時は安全側に倒し、既存のfetchAllowedを変更しない
      fetchAllowed = source.fetchAllowed;
      fetchMethod = "UNVERIFIED";
      lastError = robotsResult.error;
      notes = `robots.txt取得に失敗したため、確認状況は更新されませんでした: ${robotsResult.error}`;
    }

    await prisma.source.update({
      where: { id: source.id },
      data: {
        fetchAllowed,
        fetchMethod,
        lastFetchedAt: checkedAt,
        lastError,
        notes,
      },
    });

    results.push({
      id: source.id,
      name: source.name,
      url: source.url,
      fetchAllowed,
      detail: notes,
    });
  }

  return NextResponse.json({ data: results });
}
