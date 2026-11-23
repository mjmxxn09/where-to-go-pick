// 한국관광공사 국문 관광정보 서비스(KorService2): 시·군·구 → 법정동 코드 → 명소·맛집.

import { getJson, itemsOf, TtlCache, UpstreamError } from "./datago.ts";

const BASE = "https://apis.data.go.kr/B551011/KorService2";
const COMMON = { MobileOS: "ETC", MobileApp: "WhereToGoPick", _type: "json" };
const OK = ["0000", "00"];

// ------------------------------------------------------------------ 지역 코드

/** 앱 지도(통계청) 도 코드 → 짧은 이름. */
export const SGIS_PROVINCE: Record<string, string> = {
  "11": "서울", "21": "부산", "22": "대구", "23": "인천", "24": "광주", "25": "대전", "26": "울산", "29": "세종",
  "31": "경기", "32": "강원", "33": "충북", "34": "충남", "35": "전북", "36": "전남", "37": "경북", "38": "경남", "39": "제주",
};

const FULL_TO_SHORT: Record<string, string> = {
  서울특별시: "서울", 부산광역시: "부산", 대구광역시: "대구", 인천광역시: "인천", 광주광역시: "광주",
  대전광역시: "대전", 울산광역시: "울산", 세종특별자치시: "세종", 경기도: "경기",
  강원특별자치도: "강원", 강원도: "강원", 충청북도: "충북", 충청남도: "충남",
  전북특별자치도: "전북", 전라북도: "전북", 전라남도: "전남", 경상북도: "경북", 경상남도: "경남",
  제주특별자치도: "제주", 제주도: "제주",
};

export function provinceShort(name: string): string {
  const n = name.replace(/\s/g, "");
  return FULL_TO_SHORT[n] ?? n.slice(0, 2);
}

/** 앱 지도(조금 옛 행정구역)와 지금 이름이 다른 곳. "도:시군구" → 지금 이름 */
export const CITY_ALIASES: Record<string, string> = { "인천:남구": "미추홀구" };

export type Ldong = { regnCd: string; regnNm: string; signguCd: string; signguNm: string };

/** 법정동 시·군·구 목록. 한 번 받아 하루 동안 쓴다. */
const ldongCache = new TtlCache<Ldong[]>(24 * 60 * 60 * 1000, 2);

export function loadLdongs(): Promise<Ldong[]> {
  return ldongCache.get("all", async () => {
    // 1) 전체 목록 한 번에(lDongListYn=Y)
    const json = await getJson(`${BASE}/ldongCode2`, { ...COMMON, lDongListYn: "Y", numOfRows: 1000, pageNo: 1 });
    const rows = itemsOf(json, OK)
      .map((r) => ({
        regnCd: String(r.lDongRegnCd ?? ""),
        regnNm: String(r.lDongRegnNm ?? ""),
        signguCd: String(r.lDongSignguCd ?? ""),
        signguNm: String(r.lDongSignguNm ?? ""),
      }))
      .filter((r) => r.regnCd && r.signguCd && r.signguNm);
    if (rows.length > 0) return dedupe(rows);

    // 2) 안 되면 도 목록 → 도마다 시·군·구 목록
    const provinces = itemsOf(await getJson(`${BASE}/ldongCode2`, { ...COMMON, numOfRows: 100, pageNo: 1 }), OK);
    const out: Ldong[] = [];
    for (const p of provinces) {
      const regnCd = String(p.code ?? "");
      if (!regnCd) continue;
      const cities = itemsOf(
        await getJson(`${BASE}/ldongCode2`, { ...COMMON, lDongRegnCd: regnCd, numOfRows: 200, pageNo: 1 }),
        OK,
      );
      for (const c of cities) {
        if (c.code && c.name) out.push({ regnCd, regnNm: String(p.name ?? ""), signguCd: String(c.code), signguNm: String(c.name) });
      }
    }
    if (out.length === 0) throw new UpstreamError("LDONG_EMPTY", "법정동 코드 목록이 비어 있어요.");
    return out;
  });
}

function dedupe(rows: Ldong[]): Ldong[] {
  const seen = new Set<string>();
  return rows.filter((r) => {
    const k = `${r.regnCd}:${r.signguCd}`;
    if (seen.has(k)) return false;
    seen.add(k);
    return true;
  });
}

/**
 * 앱의 시·군·구를 법정동 코드로. 여러 개일 수 있다(앱에서 합친 시: 수원시 → 장안구·권선구…).
 * 도 안에서 이름이 같거나 "이름 + 구"로 시작하는 곳, 없으면 전국에서 같은 이름(군위군처럼 도가 바뀐 곳).
 * [cityName]이 비면 도·광역시 전체: 시·군·구 코드가 빈 항목 하나(`signguCd: ""`).
 */
export function matchCity(ldongs: Ldong[], provinceCode: string, cityName: string): Ldong[] {
  const short = SGIS_PROVINCE[provinceCode] ?? "";
  const norm = (s: string) => s.replace(/\s/g, "");
  const inProvince = ldongs.filter((l) => provinceShort(l.regnNm) === short);
  if (!norm(cityName)) {
    const first = inProvince[0];
    return first ? [{ regnCd: first.regnCd, regnNm: first.regnNm, signguCd: "", signguNm: "" }] : [];
  }
  const alias = CITY_ALIASES[`${short}:${cityName}`];
  const target = norm(alias ?? cityName);

  const exact = inProvince.filter((l) => norm(l.signguNm) === target);
  if (exact.length) return exact;
  const parts = inProvince.filter((l) => norm(l.signguNm).startsWith(target));
  if (parts.length) return parts;
  // 세종은 시·군·구 구분이 없다
  if (short === "세종" && inProvince.length) return inProvince.slice(0, 1);
  const elsewhere = ldongs.filter((l) => norm(l.signguNm) === target);
  if (elsewhere.length === 1) return elsewhere;
  return [];
}

// ------------------------------------------------------------------ 장소

export type PlaceType =
  | "beach" | "cafe" | "heritage" | "market" | "food" | "seafood" | "nature" | "lodging" | "leisure" | "culture" | "other";

export type Place = { id: string; name: string; type: PlaceType; meta: string; lat: number | null; lng: number | null };

const LABEL: Record<PlaceType, string> = {
  beach: "해변", cafe: "카페", heritage: "문화유산", market: "시장", food: "맛집", seafood: "해산물",
  nature: "자연", lodging: "숙소", leisure: "놀거리", culture: "문화시설", other: "명소",
};

const has = (title: string, words: string[]) => words.some((w) => title.includes(w));

/** TourAPI 항목 → 앱 장소 종류. 콘텐츠 타입, 분류 코드(신·구), 이름 순으로 본다. */
export function classify(item: any): PlaceType {
  const title = String(item.title ?? "");
  const typeId = String(item.contenttypeid ?? item.contentTypeId ?? "");
  const lcls1 = String(item.lclsSystm1 ?? "");
  const cat1 = String(item.cat1 ?? "");
  const cat2 = String(item.cat2 ?? "");

  if (typeId === "39") {
    if (has(title, ["카페", "커피", "베이커리", "제과", "빵", "디저트", "찻집", "다방"])) return "cafe";
    if (has(title, ["횟집", "회센터", "수산", "해물", "물회", "대게", "조개", "생선"])) return "seafood";
    return "food";
  }
  if (typeId === "14") return "culture";
  if (typeId === "28") return "leisure";
  if (typeId === "32") return "lodging";
  if (typeId === "38") return has(title, ["시장"]) ? "market" : "other";

  if (has(title, ["수산시장", "어시장"])) return "seafood";
  if (has(title, ["시장"])) return "market";
  if (has(title, ["해수욕장", "해변", "해안", "비치"])) return "beach";
  if (lcls1 === "HS" || cat2 === "A0201" || has(title, ["궁", "향교", "서원", "유적", "왕릉", "고분", "산성", "읍성", "고택", "생가"]) || /사$/.test(title.replace(/\(.*\)$/, "").trim())) {
    return "heritage";
  }
  if (lcls1 === "NA" || cat1 === "A01") return "nature";
  if (lcls1 === "EX" || lcls1 === "LS" || cat1 === "A03") return "leisure";
  if (lcls1 === "VE" || cat2 === "A0206") return "culture";
  return "other";
}

/** "강원특별자치도 강릉시 창해로 514" → "창해로". 시·군·구 다음 한 토막. */
export function areaHint(addr: string): string {
  const tokens = addr.trim().split(/\s+/);
  for (let i = 0; i < tokens.length; i++) {
    if (/(시|군|구)$/.test(tokens[i]) && i + 1 < tokens.length && !/(시|군|구)$/.test(tokens[i + 1])) {
      return tokens[i + 1].replace(/[()]/g, "");
    }
  }
  return "";
}

export function toPlace(item: any): Place | null {
  const contentId = String(item.contentid ?? "");
  const title = String(item.title ?? "").trim();
  if (!contentId || !title) return null;
  const type = classify(item);
  const hint = areaHint(String(item.addr1 ?? ""));
  const lat = Number(item.mapy);
  const lng = Number(item.mapx);
  return {
    id: `tour:${contentId}`,
    name: title,
    type,
    meta: hint ? `${LABEL[type]} · ${hint}` : LABEL[type],
    lat: Number.isFinite(lat) && lat > 30 && lat < 40 ? lat : null,
    lng: Number.isFinite(lng) && lng > 120 && lng < 135 ? lng : null,
  };
}

/** 콘텐츠 타입별로 몇 개씩: 관광지 · 음식점 · 문화시설 · 레포츠 · 쇼핑(시장) */
const KINDS: { typeId: string; rows: number }[] = [
  { typeId: "12", rows: 40 },
  { typeId: "39", rows: 30 },
  { typeId: "14", rows: 10 },
  { typeId: "28", rows: 10 },
  { typeId: "38", rows: 10 },
];

/** 대표 이미지가 있는 곳(대개 잘 알려진 곳)을 앞으로. 순서는 그대로 유지. */
export function imageFirst(items: any[]): any[] {
  return [...items.filter((i) => i.firstimage), ...items.filter((i) => !i.firstimage)];
}

function toPlaces(items: any[], { skipLodging }: { skipLodging: boolean }): Place[] {
  const seen = new Set<string>();
  const out: Place[] = [];
  for (const item of items) {
    const p = toPlace(item);
    if (!p || (skipLodging && p.type === "lodging") || seen.has(p.name)) continue;
    seen.add(p.name);
    out.push(p);
  }
  return out;
}

const placeCache = new TtlCache<Place[]>(6 * 60 * 60 * 1000);

/** 시·군·구 코드 칸. 도 전체(빈 코드)면 빼서 도 전체를 묻는다. */
const signgu = (c: Ldong): Record<string, string> => (c.signguCd ? { lDongSignguCd: c.signguCd } : {});

export function loadPlaces(codes: Ldong[]): Promise<Place[]> {
  const use = codes.slice(0, 2); // 합친 시는 앞의 두 구만(호출 수 절약)
  const key = use.map((c) => `${c.regnCd}-${c.signguCd}`).join(",");
  return placeCache.get(key, async () => {
    const lists = await Promise.all(
      use.flatMap((c) =>
        KINDS.map(async ({ typeId, rows }) => {
          const json = await getJson(`${BASE}/areaBasedList2`, {
            ...COMMON,
            numOfRows: Math.ceil(rows / use.length),
            pageNo: 1,
            arrange: "C", // 최근 수정순(사진 없는 곳도). 사진 있는 곳은 아래에서 앞으로
            contentTypeId: typeId,
            lDongRegnCd: c.regnCd,
            ...signgu(c),
          });
          return imageFirst(itemsOf(json, OK));
        })
      ),
    );
    return toPlaces(lists.flat(), { skipLodging: true });
  });
}

const searchCache = new TtlCache<Place[]>(60 * 60 * 1000);

/** 이름으로 찾기. 그 시·군·구 안에서 먼저, 없으면 도 전체에서. */
export function searchPlaces(codes: Ldong[], query: string): Promise<Place[]> {
  const first = codes[0];
  return searchCache.get(`${first.regnCd}-${first.signguCd}:${query}`, async () => {
    const find = async (signguCd?: string) => {
      const json = await getJson(`${BASE}/searchKeyword2`, {
        ...COMMON,
        numOfRows: 30,
        pageNo: 1,
        arrange: "C",
        keyword: query,
        lDongRegnCd: first.regnCd,
        ...(signguCd ? { lDongSignguCd: signguCd } : {}),
      });
      return toPlaces(imageFirst(itemsOf(json, OK)), { skipLodging: false });
    };
    const inCity = (await Promise.all(codes.slice(0, 2).map((c) => find(c.signguCd)))).flat();
    return inCity.length ? inCity : find();
  });
}

const centerCache = new TtlCache<{ lat: number; lng: number } | null>(24 * 60 * 60 * 1000);

/**
 * 날씨용 도시 가운데 좌표. 장소 목록이 이미 캐시에 있으면 그걸 쓰고, 아니면 관광지 20곳만 한 번 물어본다
 * (여행지 고르기 화면의 도시 카드마다 날씨를 부르므로, 장소 다섯 종류를 다 받지 않게).
 */
export function loadCenter(codes: Ldong[]): Promise<{ lat: number; lng: number } | null> {
  const c = codes[0];
  return centerCache.get(`${c.regnCd}-${c.signguCd}`, async () => {
    const json = await getJson(`${BASE}/areaBasedList2`, {
      ...COMMON,
      numOfRows: 20,
      pageNo: 1,
      arrange: "C",
      contentTypeId: "12",
      lDongRegnCd: c.regnCd,
      ...signgu(c),
    });
    return centerOf(toPlaces(itemsOf(json, OK), { skipLodging: true }));
  });
}

/** 장소 좌표의 가운데(중앙값). 날씨 격자를 고를 때 쓴다. */
export function centerOf(places: Place[]): { lat: number; lng: number } | null {
  const lats = places.map((p) => p.lat).filter((v): v is number => v != null).sort((a, b) => a - b);
  const lngs = places.map((p) => p.lng).filter((v): v is number => v != null).sort((a, b) => a - b);
  if (!lats.length || !lngs.length) return null;
  const mid = (xs: number[]) => xs[Math.floor(xs.length / 2)];
  return { lat: mid(lats), lng: mid(lngs) };
}
