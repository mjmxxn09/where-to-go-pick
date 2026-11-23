// 카카오 로컬 API(카카오맵 장소 검색): 지역별·종류별 인기 장소, 이름 검색.
//
// 비밀값 KAKAO_REST_API_KEY(카카오 디벨로퍼스 앱의 REST API 키, 카카오맵 사용 설정 ON).
// 키가 없으면 hasKakao()가 false — index.ts가 한국관광공사 데이터로 대신한다.
//
// "인기"는 카카오맵 검색의 정확도순(검색·이용이 많은 곳이 위로 오는 순서)을 그대로 쓴다.
// 결과는 그 시·군·구 주소인 곳만 남긴다.

import { TtlCache, UpstreamError } from "./datago.ts";
import type { Place, PlaceType } from "./tour.ts";
import { CITY_ALIASES, provinceShort, SGIS_PROVINCE } from "./tour.ts";

const KEYWORD_URL = "https://dapi.kakao.com/v2/local/search/keyword.json";
const TIMEOUT_MS = 6000;

export function hasKakao(): boolean {
  return !!(Deno.env.get("KAKAO_REST_API_KEY") ?? "").trim();
}

export type KakaoDoc = {
  id: string;
  place_name: string;
  category_name: string;
  category_group_code: string;
  address_name: string;
  road_address_name: string;
  place_url: string;
  x: string;
  y: string;
};

type KakaoPage = { docs: KakaoDoc[]; isEnd: boolean };

async function keyword(params: Record<string, string | number>): Promise<KakaoPage> {
  const key = (Deno.env.get("KAKAO_REST_API_KEY") ?? "").trim();
  if (!key) throw new UpstreamError("KAKAO_KEY_MISSING", "KAKAO_REST_API_KEY 비밀값이 없어요.");
  const query = new URLSearchParams();
  for (const [k, v] of Object.entries(params)) query.set(k, String(v));
  let res: Response;
  try {
    res = await fetch(`${KEYWORD_URL}?${query}`, {
      headers: { Authorization: `KakaoAK ${key}` },
      signal: AbortSignal.timeout(TIMEOUT_MS),
    });
  } catch (e) {
    throw new UpstreamError("KAKAO_UNREACHABLE", `카카오 서버에 닿지 않았어요: ${e instanceof Error ? e.message : e}`);
  }
  const text = await res.text();
  if (!res.ok) {
    // 401/403: 키가 틀렸거나 카카오맵 사용 설정이 꺼져 있다. 429: 하루 호출량 초과.
    let detail = "";
    try {
      const j = JSON.parse(text);
      detail = j?.errorType ?? j?.message ?? j?.msg ?? "";
    } catch {
      detail = text.slice(0, 120);
    }
    throw new UpstreamError(`KAKAO_${res.status}`, `카카오 장소 검색 응답 ${res.status} ${detail}`.trim());
  }
  const json = JSON.parse(text);
  return { docs: Array.isArray(json?.documents) ? json.documents : [], isEnd: json?.meta?.is_end !== false };
}

/** 카카오 분류 → 앱 장소 종류. */
export function kakaoType(doc: Pick<KakaoDoc, "category_group_code" | "category_name" | "place_name">): PlaceType {
  const cat = doc.category_name ?? "";
  const name = doc.place_name ?? "";
  const has = (...ws: string[]) => ws.some((w) => cat.includes(w) || name.includes(w));
  switch (doc.category_group_code) {
    case "CE7":
      return "cafe";
    case "FD6":
      if (has("카페", "디저트", "베이커리", "제과")) return "cafe";
      if (has("해산물", "회", "횟집", "수산", "조개", "게,대게", "생선")) return "seafood";
      return "food";
    case "AD5":
      return "lodging";
    case "CT1":
      return "culture";
  }
  if (has("시장")) return has("수산", "어시장") ? "seafood" : "market";
  if (has("해수욕장", "해변", "해안")) return "beach";
  if (has("사찰", "성당", "교회", "문화유적", "고궁", "궁", "유적지", "향교", "서원", "한옥마을", "릉")) return "heritage";
  if (has("박물관", "미술관", "전시관", "기념관", "문화시설")) return "culture";
  if (has("테마파크", "놀이", "레저", "체험", "아쿠아리움", "동물원", "케이블카", "전망대", "스키", "골프", "온천")) return "leisure";
  if (has("산", "계곡", "폭포", "호수", "섬", "숲", "공원", "자연", "수목원", "식물원", "자연휴양림", "명소")) return "nature";
  return "other";
}

const LABEL: Record<PlaceType, string> = {
  beach: "해변", cafe: "카페", heritage: "문화유산", market: "시장", food: "맛집", seafood: "해산물",
  nature: "자연", lodging: "숙소", leisure: "놀거리", culture: "문화시설", other: "명소",
};

/** "음식점 > 한식 > 순두부" → "순두부", 없으면 종류 이름. 길 이름(도로명 주소의 시·군·구 다음)을 붙인다. */
export function kakaoMeta(doc: KakaoDoc, type: PlaceType): string {
  const parts = (doc.category_name ?? "").split(">").map((s) => s.trim()).filter(Boolean);
  const kind = parts.length >= 2 ? parts[parts.length - 1] : LABEL[type];
  const addr = (doc.road_address_name || doc.address_name || "").split(/\s+/);
  let hint = "";
  for (let i = 0; i < addr.length - 1; i++) {
    if (/(시|군|구)$/.test(addr[i]) && !/(시|군|구)$/.test(addr[i + 1])) {
      hint = addr[i + 1];
      break;
    }
  }
  return hint ? `${kind} · ${hint}` : kind;
}

export type KakaoPlace = Place & { url: string };

export function toKakaoPlace(doc: KakaoDoc): KakaoPlace | null {
  if (!doc?.id || !doc.place_name) return null;
  const type = kakaoType(doc);
  const lat = Number(doc.y);
  const lng = Number(doc.x);
  return {
    id: `kakao:${doc.id}`,
    name: doc.place_name,
    type,
    meta: kakaoMeta(doc, type),
    lat: Number.isFinite(lat) ? lat : null,
    lng: Number.isFinite(lng) ? lng : null,
    url: doc.place_url ?? "",
  };
}

/** 앱 지도의 도 코드·시 이름이 카카오 주소("강원특별자치도 강릉시 …", "경북 경주시 …")와 같은 곳인지. */
export function inRegion(address: string, provinceCode: string, cityName: string): boolean {
  const short = SGIS_PROVINCE[provinceCode];
  if (!short || !address) return false;
  const tokens = address.trim().split(/\s+/);
  const city = (CITY_ALIASES[`${short}:${cityName}`] ?? cityName).replace(/\s/g, "");
  // 군위군은 대구로 옮겨 갔다: 도와 상관없이 시·군 이름으로만 본다.
  if (short === "경북" && city === "군위군") return tokens[1] === "군위군";
  if (provinceShort(tokens[0] ?? "") !== short) return false;
  if (short === "세종") return true;
  return (tokens[1] ?? "").replace(/\s/g, "") === city || tokens.slice(1, 3).join("").startsWith(city);
}

/** 지역 이름: 검색어 앞에 붙인다("강릉시 맛집"). 시·군 끝 글자는 떼면 카카오가 더 잘 알아듣는 경우가 많다. */
export function regionWord(provinceCode: string, cityName: string): string {
  const short = SGIS_PROVINCE[provinceCode] ?? "";
  const city = CITY_ALIASES[`${short}:${cityName}`] ?? cityName;
  if (short === "세종") return "세종";
  // 서울 중구·부산 중구처럼 같은 이름의 구가 여러 도에 있으면 도 이름을 앞에.
  return /구$/.test(city) ? `${short} ${city}` : city;
}

/** 인기 장소 칸: 앱 칩 이름 · 카카오 검색어 · 분류 코드 */
export const SECTIONS: { key: string; label: string; query: string; code: string }[] = [
  { key: "sights", label: "명소", query: "가볼만한곳", code: "AT4" },
  { key: "food", label: "맛집", query: "맛집", code: "FD6" },
  { key: "cafe", label: "카페", query: "카페", code: "CE7" },
  { key: "culture", label: "문화", query: "박물관 미술관", code: "CT1" },
];

export type Section = { key: string; label: string; places: KakaoPlace[] };

const popularCache = new TtlCache<Section[]>(6 * 60 * 60 * 1000);

/** 칸마다 정확도순 15곳을 받아, 그 시·군·구 안에서 [perSection]곳. */
export function popularSections(provinceCode: string, cityName: string, perSection = 5): Promise<Section[]> {
  return popularCache.get(`${provinceCode}:${cityName}:${perSection}`, async () => {
    const region = regionWord(provinceCode, cityName);
    return Promise.all(SECTIONS.map(async (s) => {
      const page = await keyword({ query: `${region} ${s.query}`, category_group_code: s.code, size: 15, page: 1, sort: "accuracy" });
      const places = page.docs
        .filter((d) => inRegion(d.road_address_name || d.address_name, provinceCode, cityName))
        .map(toKakaoPlace)
        .filter((p): p is KakaoPlace => p != null);
      return { key: s.key, label: s.label, places: dedupe(places).slice(0, perSection) };
    }));
  });
}

const searchCache = new TtlCache<{ places: KakaoPlace[]; hasMore: boolean; outside: boolean }>(30 * 60 * 1000);

/**
 * 이름 검색. 검색어에 지역 이름을 붙여 그 시·군·구 안 결과를 먼저, 없으면 검색어 그대로(지역 밖 표시).
 * [page]는 1부터, 한 쪽 15곳. 카카오는 한 검색어에 45곳(3쪽)까지만 준다.
 */
export function searchKakao(provinceCode: string, cityName: string, query: string, page = 1) {
  return searchCache.get(`${provinceCode}:${cityName}:${query}:${page}`, async () => {
    const region = regionWord(provinceCode, cityName);
    const q = query.includes(cityName.replace(/(시|군|구)$/, "")) ? query : `${region} ${query}`;
    const local = await keyword({ query: q, size: 15, page, sort: "accuracy" });
    const inside = local.docs.filter((d) => inRegion(d.road_address_name || d.address_name, provinceCode, cityName));
    if (inside.length || page > 1) {
      return { places: dedupe(inside.map(toKakaoPlace).filter((p): p is KakaoPlace => p != null)), hasMore: !local.isEnd && page < 3, outside: false };
    }
    const any = await keyword({ query, size: 15, page: 1, sort: "accuracy" });
    return { places: dedupe(any.docs.map(toKakaoPlace).filter((p): p is KakaoPlace => p != null)), hasMore: false, outside: true };
  });
}

function dedupe(places: KakaoPlace[]): KakaoPlace[] {
  const seen = new Set<string>();
  return places.filter((p) => (seen.has(p.id) ? false : (seen.add(p.id), true)));
}
