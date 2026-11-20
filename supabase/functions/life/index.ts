// 여행지 정보: 명소·맛집(한국관광공사 TourAPI)과 날씨(기상청 단기예보).
//
// POST { action: "places" | "weather" | "search", provinceCode: "32", cityName: "강릉시", date?: "2026-11-20", query?: "커피" }
//   provinceCode는 앱 지도(통계청)의 도 코드(시·군·구 id 앞 두 자리).
// 응답: { places: [...] } 또는 { weather: {...} }
//
// 비밀값: DATA_GO_KR_SERVICE_KEY (공공데이터포털 일반 인증키, Decoding 값)

import { isAppUser } from "./auth.ts";
import { UpstreamError } from "./datago.ts";
import { kst, loadForecast, summarize, toGrid } from "./kma.ts";
import { type Ldong, loadCenter, loadLdongs, loadPlaces, matchCity, searchPlaces } from "./tour.ts";

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
  if (!codes.length) throw new UpstreamError("CITY_NOT_FOUND", `${cityName}의 지역 코드를 찾지 못했어요.`);
  return codes;
}

const brief = (places: { id: string; name: string; type: string; meta: string }[]) =>
  places.map(({ id, name, type, meta }) => ({ id, name, type, meta }));

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
  if (!/^\d{2}$/.test(provinceCode) || !cityName || cityName.length > 40) {
    return fail(400, "BAD_REQUEST", "provinceCode(두 자리)와 cityName이 필요해요.");
  }

  if (!["places", "weather", "search"].includes(action)) {
    return fail(400, "BAD_REQUEST", "action은 places, weather, search 중 하나예요.");
  }

  try {
    const codes = await codesFor(provinceCode, cityName);
    if (action === "search") {
      const query = String(body?.query ?? "").trim();
      if (!query || query.length > 40) return fail(400, "BAD_REQUEST", "query(1~40자)가 필요해요.");
      return json(200, { places: brief(await searchPlaces(codes, query)) });
    }
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
