// 여행지 정보: 인기 장소·검색(카카오맵, 없으면 한국관광공사 TourAPI)과 날씨(기상청 단기예보).
//
// POST { action, provinceCode: "32", cityName: "강릉시", ... }   provinceCode는 앱 지도(통계청)의 도 코드.
//   popular                → { source, sections: [{ key, label, places: [5곳] }] }   명소·맛집·카페·문화
//   search  { query, page? } → { source, places, hasMore, outside }                 outside: 이 지역에 없어 전국에서 찾음
//   weather { date? }      → { weather }
//   places                 → { places }   (예전 앱용: 한국관광공사 목록)
//
// 비밀값: DATA_GO_KR_SERVICE_KEY (공공데이터포털 일반 인증키, Decoding 값), KAKAO_REST_API_KEY (카카오 REST API 키)

import { isAppUser } from "./auth.ts";
import { brief } from "./brief.ts";
import { UpstreamError } from "./datago.ts";
import { kst, loadForecast, summarize, toGrid } from "./kma.ts";
import { hasKakao, popularSections, searchKakao } from "./kakao.ts";
import { type Ldong, loadCenter, loadLdongs, loadPlaces, matchCity, type Place, searchPlaces } from "./tour.ts";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

function json(status: number, body: unknown): Response {
  return new Response(JSON.stringify(body), { status, headers: { ...corsHeaders, "Content-Type": "application/json" } });
}

const fail = (status: number, code: string, message: string) => json(status, { code, message });

async function codesFor(provinceCode: string, cityName: string): Promise<Ldong[]> {
  const codes = matchCity(await loadLdongs(), provinceCode, cityName);
  if (!codes.length) throw new UpstreamError("CITY_NOT_FOUND", `${cityName || provinceCode}의 지역 코드를 찾지 못했어요.`);
  return codes;
}

/** 카카오 키가 없을 때: 한국관광공사 목록을 같은 칸으로 나눠 앞에서 5곳씩(사진 있는 곳이 앞). */
function sectionsFromTour(places: Place[], per = 5) {
  const pick = (types: string[]) => places.filter((p) => types.includes(p.type)).slice(0, per);
  return [
    { key: "sights", label: "명소", places: pick(["nature", "beach", "heritage", "leisure", "other"]) },
    { key: "food", label: "맛집", places: pick(["food", "seafood", "market"]) },
    { key: "cafe", label: "카페", places: pick(["cafe"]) },
    { key: "culture", label: "문화", places: pick(["culture"]) },
  ].map((s) => ({ ...s, places: brief(s.places) }));
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });
  if (req.method !== "POST") return fail(405, "METHOD_NOT_ALLOWED", "POST만 받아요.");
  if (!(await isAppUser(req))) return fail(401, "UNAUTHENTICATED", "앱에서 로그인한 사용자만 쓸 수 있어요.");

  let body: any;
  try {
    body = await req.json();
  } catch {
    return fail(400, "BAD_REQUEST", "JSON 본문이 필요해요.");
  }
  const action = String(body?.action ?? "");
  const provinceCode = String(body?.provinceCode ?? "");
  const cityName = String(body?.cityName ?? "").trim();
  // cityName이 비면 도·광역시 전체.
  if (!/^\d{2}$/.test(provinceCode) || cityName.length > 40) {
    return fail(400, "BAD_REQUEST", "provinceCode(두 자리)가 필요해요(cityName은 비우면 도 전체).");
  }

  if (!["places", "weather", "search", "popular"].includes(action)) {
    return fail(400, "BAD_REQUEST", "action은 popular, search, weather, places 중 하나예요.");
  }

  try {
    if (action === "popular" && hasKakao()) {
      const sections = await popularSections(provinceCode, cityName);
      return json(200, { source: "kakao", sections: sections.map((s) => ({ ...s, places: brief(s.places) })) });
    }
    if (action === "search") {
      const query = String(body?.query ?? "").trim();
      if (!query || query.length > 40) return fail(400, "BAD_REQUEST", "query(1~40자)가 필요해요.");
      const page = Math.min(3, Math.max(1, Number(body?.page) || 1));
      if (hasKakao()) {
        const r = await searchKakao(provinceCode, cityName, query, page);
        return json(200, { source: "kakao", places: brief(r.places), hasMore: r.hasMore, outside: r.outside });
      }
      const codes = await codesFor(provinceCode, cityName);
      return json(200, { source: "tour", places: brief(await searchPlaces(codes, query)), hasMore: false, outside: false });
    }
    const codes = await codesFor(provinceCode, cityName);
    if (action === "popular") return json(200, { source: "tour", sections: sectionsFromTour(await loadPlaces(codes)) });
    if (action === "places") return json(200, { places: brief(await loadPlaces(codes)) });
    if (action === "weather") {
      const center = await loadCenter(codes);
      if (!center) throw new UpstreamError("NO_COORDINATES", "날씨를 볼 위치를 찾지 못했어요.");
      const now = new Date();
      const today = kst(now).ymd;
      const ymd = typeof body.date === "string" && /^\d{4}-\d{2}-\d{2}$/.test(body.date) ? body.date.replaceAll("-", "") : today;
      const { nx, ny } = toGrid(center.lat, center.lng);
      const weather = summarize(await loadForecast(nx, ny, now), ymd, ymd === today ? kst(now).hour : null);
      if (!weather) throw new UpstreamError("NO_FORECAST", "그날 예보가 아직 없어요.");
      return json(200, { weather });
    }
    return fail(400, "BAD_REQUEST", "알 수 없는 action이에요.");
  } catch (e) {
    if (e instanceof UpstreamError) {
      console.error("upstream", e.code, e.message);
      return fail(502, e.code, e.message);
    }
    console.error("life failed", e instanceof Error ? e.stack : e);
    return fail(500, "INTERNAL", "잠시 뒤 다시 해 주세요.");
  }
});
