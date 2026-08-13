import robotsParser from "robots-parser";

/**
 * クローラーの身元を偽らないよう、実在のUAとして識別できる文字列を使う (指示書41項)。
 */
export const ROBOTS_CHECK_USER_AGENT = "KinkiFishingNewsAIBot/0.1";

type Robot = ReturnType<typeof robotsParser>;

export type RobotsFetchResult =
  | { status: "fetched"; robots: Robot }
  /** robots.txt自体が存在しない(404)場合。一般的な解釈に従い「制限なし」として扱う。 */
  | { status: "not_found" }
  | { status: "error"; error: string };

export async function fetchRobotsTxt(origin: string): Promise<RobotsFetchResult> {
  let robotsUrl: string;
  try {
    robotsUrl = new URL("/robots.txt", origin).toString();
  } catch {
    return { status: "error", error: `無効なオリジンです: ${origin}` };
  }

  let res: Response;
  try {
    res = await fetch(robotsUrl, {
      headers: { "User-Agent": ROBOTS_CHECK_USER_AGENT },
      signal: AbortSignal.timeout(10_000),
    });
  } catch (error) {
    return { status: "error", error: error instanceof Error ? error.message : String(error) };
  }

  if (res.status === 404) {
    return { status: "not_found" };
  }
  if (!res.ok) {
    return { status: "error", error: `robots.txt取得失敗: HTTP ${res.status}` };
  }

  const body = await res.text();
  return { status: "fetched", robots: robotsParser(robotsUrl, body) };
}

/**
 * robots.txtの判定結果。undefined(判定不能)は安全側に倒して禁止扱いとする。
 */
export function isAllowedByRobots(robots: Robot, targetUrl: string): boolean {
  return robots.isAllowed(targetUrl, ROBOTS_CHECK_USER_AGENT) === true;
}
