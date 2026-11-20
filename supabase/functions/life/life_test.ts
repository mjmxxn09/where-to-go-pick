// deno test -A supabase/functions/life/life_test.ts
import { deepStrictEqual as assertEquals, ok as assert } from "node:assert";
import { itemsOf, xmlError } from "./datago.ts";
import { kst, latestBase, summarize, toGrid } from "./kma.ts";
import { areaHint, centerOf, classify, imageFirst, loadLdongs, loadPlaces, matchCity, provinceShort, searchPlaces, toPlace } from "./tour.ts";

Deno.test("격자 변환: 기상청 예시 좌표", () => {
  assertEquals(toGrid(37.5665, 126.978), { nx: 60, ny: 127 }); // 서울
  assertEquals(toGrid(35.1796, 129.0756), { nx: 98, ny: 76 }); // 부산
  assertEquals(toGrid(33.4996, 126.5312), { nx: 53, ny: 38 }); // 제주
});

Deno.test("발표 시각: 10분 뒤부터, 새벽 2시 전은 전날 23시", () => {
  const at = (iso: string) => new Date(iso);
  assertEquals(latestBase(at("2026-11-20T14:20:00+09:00")), { baseDate: "20261120", baseTime: "1400" });
  assertEquals(latestBase(at("2026-11-20T14:05:00+09:00")), { baseDate: "20261120", baseTime: "1100" });
  assertEquals(latestBase(at("2026-11-20T01:00:00+09:00")), { baseDate: "20261119", baseTime: "2300" });
  assertEquals(latestBase(at("2026-11-20T23:30:00+09:00")), { baseDate: "20261120", baseTime: "2300" });
  assertEquals(kst(at("2026-11-20T23:30:00+09:00")).hour, 23);
});

function fcst(date: string, hour: number, cat: string, value: string | number) {
  return { fcstDate: date, fcstTime: `${String(hour).padStart(2, "0")}00`, category: cat, fcstValue: String(value) };
}

Deno.test("하루 요약: 지금 이후 시간, 비 소식 팁, TMN·TMX 우선", () => {
  const d = "20261120";
  const items = [
    ...[15, 16, 17, 18, 19, 20, 21, 22, 23].flatMap((h) => [
      fcst(d, h, "TMP", 20 - (h - 15)),
      fcst(d, h, "SKY", h < 18 ? 1 : 4),
      fcst(d, h, "PTY", h === 21 ? 1 : 0),
    ]),
    fcst(d, 15, "TMX", 21.0),
    fcst("20261121", 6, "TMP", 2),
  ];
  const w = summarize(items, d, 14)!;
  assertEquals(w.temperature, 20);
  assertEquals(w.sky, "sunny");
  assertEquals(w.max, 21);
  assertEquals(w.min, 12);
  assertEquals(w.hourly.map((h) => h.hour), [18, 21]);
  assertEquals(w.hourly[1].sky, "rainy");
  assertEquals(w.tip, "비 소식이 있어요. 우산 챙기기!");
  assertEquals(summarize(items, "20261125", null), null);
});

Deno.test("공공데이터 오류: XML 본문과 결과 코드", () => {
  const e = xmlError(
    "<OpenAPI_ServiceResponse><cmmMsgHeader><errMsg>SERVICE ERROR</errMsg><returnAuthMsg>SERVICE_KEY_IS_NOT_REGISTERED_ERROR</returnAuthMsg><returnReasonCode>30</returnReasonCode></cmmMsgHeader></OpenAPI_ServiceResponse>",
  )!;
  assertEquals(e.code, "SERVICE_KEY_IS_NOT_REGISTERED_ERROR");
  assertEquals(xmlError('{"a":1}'), null);
  assertEquals(itemsOf({ response: { header: { resultCode: "0000" }, body: { items: "" } } }, ["0000"]), []);
  assertEquals(itemsOf({ response: { header: { resultCode: "0000" }, body: { items: { item: { a: 1 } } } } }, ["0000"]), [{ a: 1 }]);
});

const LDONGS = [
  { regnCd: "51", regnNm: "강원특별자치도", signguCd: "150", signguNm: "강릉시" },
  { regnCd: "51", regnNm: "강원특별자치도", signguCd: "820", signguNm: "고성군" },
  { regnCd: "48", regnNm: "경상남도", signguCd: "820", signguNm: "고성군" },
  { regnCd: "41", regnNm: "경기도", signguCd: "111", signguNm: "수원시 장안구" },
  { regnCd: "41", regnNm: "경기도", signguCd: "113", signguNm: "수원시 권선구" },
  { regnCd: "28", regnNm: "인천광역시", signguCd: "177", signguNm: "미추홀구" },
  { regnCd: "27", regnNm: "대구광역시", signguCd: "720", signguNm: "군위군" },
  { regnCd: "36", regnNm: "세종특별자치시", signguCd: "110", signguNm: "세종특별자치시" },
];

Deno.test("시·군·구 찾기: 도 안에서, 합친 시, 바뀐 이름, 도가 바뀐 곳, 세종", () => {
  assertEquals(provinceShort("전라북도"), "전북");
  assertEquals(matchCity(LDONGS, "32", "강릉시").map((l) => l.signguCd), ["150"]);
  assertEquals(matchCity(LDONGS, "38", "고성군").map((l) => l.regnCd), ["48"]);
  assertEquals(matchCity(LDONGS, "31", "수원시").map((l) => l.signguCd), ["111", "113"]);
  assertEquals(matchCity(LDONGS, "23", "남구").map((l) => l.signguCd), ["177"]);
  assertEquals(matchCity(LDONGS, "37", "군위군").map((l) => l.regnCd), ["27"]);
  assertEquals(matchCity(LDONGS, "29", "세종시").map((l) => l.signguCd), ["110"]);
  assertEquals(matchCity(LDONGS, "32", "없는군"), []);
});

Deno.test("장소 종류와 짧은 설명", () => {
  assertEquals(classify({ title: "경포해수욕장", contenttypeid: "12" }), "beach");
  assertEquals(classify({ title: "강릉 오죽헌", contenttypeid: "12", lclsSystm1: "HS" }), "heritage");
  assertEquals(classify({ title: "불국사", contenttypeid: "12" }), "heritage");
  assertEquals(classify({ title: "주문진수산시장", contenttypeid: "12" }), "seafood");
  assertEquals(classify({ title: "강릉중앙시장", contenttypeid: "12" }), "market");
  assertEquals(classify({ title: "소금강", contenttypeid: "12", cat1: "A01" }), "nature");
  assertEquals(classify({ title: "테라로사 커피공장", contenttypeid: "39" }), "cafe");
  assertEquals(classify({ title: "초당순두부", contenttypeid: "39" }), "food");
  assertEquals(classify({ title: "참소리박물관", contenttypeid: "14" }), "culture");
  assertEquals(areaHint("강원특별자치도 강릉시 창해로 514"), "창해로");
  assertEquals(areaHint("서울특별시 종로구 사직로 161"), "사직로");
  const p = toPlace({ contentid: "123", title: "경포해수욕장", contenttypeid: "12", addr1: "강원특별자치도 강릉시 창해로 514", mapx: "128.9", mapy: "37.8" })!;
  assertEquals(p, { id: "tour:123", name: "경포해수욕장", type: "beach", meta: "해변 · 창해로", lat: 37.8, lng: 128.9 });
  assertEquals(centerOf([p, { ...p, lat: 37.6, lng: 128.7 }, { ...p, lat: null, lng: null }]), { lat: 37.8, lng: 128.9 });
});

Deno.test("법정동 목록 → 장소 목록(공공데이터 호출을 흉내)", async () => {
  Deno.env.set("DATA_GO_KR_SERVICE_KEY", "abc+/=");
  const calls: URL[] = [];
  const realFetch = globalThis.fetch;
  globalThis.fetch = (async (input: string | URL | Request) => {
    const url = new URL(typeof input === "string" ? input : input instanceof URL ? input : input.url);
    calls.push(url);
    const ok = (items: unknown) => new Response(JSON.stringify({ response: { header: { resultCode: "0000" }, body: { items } } }));
    if (url.pathname.endsWith("/ldongCode2")) {
      return ok({ item: LDONGS.map((l) => ({ lDongRegnCd: l.regnCd, lDongRegnNm: l.regnNm, lDongSignguCd: l.signguCd, lDongSignguNm: l.signguNm })) });
    }
    const type = url.searchParams.get("contentTypeId");
    if (type === "12") return ok({ item: [{ contentid: "1", title: "경포해수욕장", contenttypeid: "12", addr1: "강원특별자치도 강릉시 창해로 514", mapx: "128.9", mapy: "37.8" }] });
    if (type === "39") return ok({ item: { contentid: "2", title: "테라로사 커피공장", contenttypeid: "39", addr1: "강원특별자치도 강릉시 구정면 현천길 25" } });
    return ok("");
  }) as typeof fetch;
  try {
    const codes = matchCity(await loadLdongs(), "32", "강릉시");
    const places = await loadPlaces(codes);
    assertEquals(places.map((p) => [p.name, p.type]), [["경포해수욕장", "beach"], ["테라로사 커피공장", "cafe"]]);
    const list = calls.find((u) => u.pathname.endsWith("/areaBasedList2"))!;
    assertEquals(list.searchParams.get("serviceKey"), "abc+/=", "키는 한 번만 인코딩된다");
    assert(list.search.includes("serviceKey=abc%2B%2F%3D"));
    assertEquals(list.searchParams.get("lDongRegnCd"), "51");
    assertEquals(list.searchParams.get("lDongSignguCd"), "150");
    const before = calls.length;
    await loadPlaces(codes);
    assertEquals(calls.length, before, "두 번째는 캐시");
  } finally {
    globalThis.fetch = realFetch;
  }
});

Deno.test("사진 있는 곳을 앞으로, 검색은 시·군·구에 없으면 도 전체", async () => {
  assertEquals(imageFirst([{ t: 1 }, { t: 2, firstimage: "x" }, { t: 3 }]).map((i) => i.t), [2, 1, 3]);
  Deno.env.set("DATA_GO_KR_SERVICE_KEY", "k");
  const calls: URL[] = [];
  const realFetch = globalThis.fetch;
  globalThis.fetch = (async (input: string | URL | Request) => {
    const url = new URL(typeof input === "string" ? input : input instanceof URL ? input : input.url);
    calls.push(url);
    const items = url.searchParams.get("lDongSignguCd")
      ? ""
      : { item: [{ contentid: "9", title: "강원 어딘가 카페", contenttypeid: "39", addr1: "강원특별자치도 속초시 해오름로 1" }] };
    return new Response(JSON.stringify({ response: { header: { resultCode: "0000" }, body: { items } } }));
  }) as typeof fetch;
  try {
    const found = await searchPlaces([LDONGS[0]], "카페");
    assertEquals(found.map((p) => [p.name, p.type]), [["강원 어딘가 카페", "cafe"]]);
    assertEquals(calls.map((u) => u.pathname.split("/").pop()), ["searchKeyword2", "searchKeyword2"]);
    assertEquals(calls[0].searchParams.get("keyword"), "카페");
    assertEquals(calls[0].searchParams.get("lDongSignguCd"), "150");
    assertEquals(calls[1].searchParams.get("lDongSignguCd"), null);
  } finally {
    globalThis.fetch = realFetch;
  }
});
