// deno test -A supabase/functions/life/kakao_test.ts
import { deepStrictEqual as assertEquals, ok as assert } from "node:assert";
import { brief } from "./brief.ts";
import { inRegion, kakaoMeta, kakaoType, popularSections, regionWord, searchKakao, toKakaoPlace } from "./kakao.ts";

const doc = (o: Record<string, string>) => ({
  id: "1", place_name: "", category_name: "", category_group_code: "", address_name: "", road_address_name: "", place_url: "", x: "128.9", y: "37.8",
  ...o,
});

Deno.test("카카오 분류 → 장소 종류", () => {
  assertEquals(kakaoType(doc({ category_group_code: "CE7", category_name: "음식점 > 카페" })), "cafe");
  assertEquals(kakaoType(doc({ category_group_code: "FD6", category_name: "음식점 > 한식 > 해물,생선 > 회" })), "seafood");
  assertEquals(kakaoType(doc({ category_group_code: "FD6", category_name: "음식점 > 한식 > 순두부" })), "food");
  assertEquals(kakaoType(doc({ category_group_code: "AT4", category_name: "여행 > 관광,명소 > 해수욕장,해변" })), "beach");
  assertEquals(kakaoType(doc({ category_group_code: "AT4", category_name: "여행 > 관광,명소 > 문화유적 > 사적지", place_name: "오죽헌" })), "heritage");
  assertEquals(kakaoType(doc({ category_group_code: "AT4", category_name: "여행 > 관광,명소 > 전통시장", place_name: "주문진수산시장" })), "seafood");
  assertEquals(kakaoType(doc({ category_group_code: "CT1", category_name: "문화,예술 > 문화시설 > 박물관" })), "culture");
  assertEquals(kakaoType(doc({ category_group_code: "AT4", category_name: "여행 > 관광,명소 > 테마파크" })), "leisure");
});

Deno.test("짧은 설명과 장소 변환", () => {
  const d = doc({ id: "123", place_name: "초당순두부", category_group_code: "FD6", category_name: "음식점 > 한식 > 순두부", road_address_name: "강원특별자치도 강릉시 초당순두부길 77", place_url: "http://place.map.kakao.com/123" });
  assertEquals(kakaoMeta(d, "food"), "순두부 · 초당순두부길");
  assertEquals(toKakaoPlace(d), { id: "kakao:123", name: "초당순두부", type: "food", meta: "순두부 · 초당순두부길", lat: 37.8, lng: 128.9, url: "http://place.map.kakao.com/123" });
});

Deno.test("그 시·군·구 안인지, 검색 앞에 붙일 지역 이름", () => {
  assert(inRegion("강원특별자치도 강릉시 창해로 514", "32", "강릉시"));
  assert(inRegion("강원 강릉시 창해로 514", "32", "강릉시"));
  assert(!inRegion("강원특별자치도 속초시 해오름로 1", "32", "강릉시"));
  assert(inRegion("경기 수원시 팔달구 정조로 825", "31", "수원시"));
  assert(inRegion("충북 청주시 상당구 1", "33", "청주시"));
  assert(!inRegion("충남 천안시 1", "33", "천안시"));
  assert(inRegion("인천 미추홀구 1", "23", "남구"));
  assert(inRegion("대구 군위군 군위읍 1", "37", "군위군"));
  assert(inRegion("세종특별자치시 한누리대로 1", "29", "세종시"));
  assertEquals(regionWord("32", "강릉시"), "강릉시");
  assertEquals(regionWord("11", "중구"), "서울 중구");
  assertEquals(regionWord("23", "남구"), "인천 미추홀구");
});

function stubKakao(handler: (url: URL) => unknown) {
  Deno.env.set("KAKAO_REST_API_KEY", "test-key");
  const calls: URL[] = [];
  const real = globalThis.fetch;
  globalThis.fetch = (async (input: string | URL | Request, init?: RequestInit) => {
    const url = new URL(typeof input === "string" ? input : input instanceof URL ? input : input.url);
    calls.push(url);
    assertEquals(new Headers(init?.headers).get("authorization"), "KakaoAK test-key");
    return Response.json(handler(url));
  }) as typeof fetch;
  return { calls, restore: () => (globalThis.fetch = real) };
}

Deno.test("인기 장소: 칸마다 정확도순에서 그 지역만 5곳", async () => {
  const s = stubKakao((url) => {
    const code = url.searchParams.get("category_group_code");
    const docs = Array.from({ length: 8 }, (_, i) => doc({
      id: `${code}${i}`, place_name: `${code} ${i}`, category_group_code: code ?? "",
      road_address_name: i === 0 ? "강원특별자치도 속초시 1" : "강원특별자치도 강릉시 경포로 1",
    }));
    return { documents: docs, meta: { is_end: true } };
  });
  try {
    const sections = await popularSections("32", "강릉시");
    assertEquals(sections.map((x) => x.key), ["sights", "food", "cafe", "culture"]);
    assertEquals(sections[1].places.map((p) => p.id), ["kakao:FD61", "kakao:FD62", "kakao:FD63", "kakao:FD64", "kakao:FD65"]);
    assertEquals(s.calls[0].searchParams.get("query"), "강릉시 가볼만한곳");
    assertEquals(s.calls[0].searchParams.get("sort"), "accuracy");
  } finally {
    s.restore();
  }
});

Deno.test("검색: 지역 안에 없으면 전국에서 찾고 outside 표시", async () => {
  const s = stubKakao((url) => {
    const q = url.searchParams.get("query") ?? "";
    if (q.startsWith("강릉시")) return { documents: [doc({ id: "9", place_name: "서울 어딘가", road_address_name: "서울 중구 1" })], meta: { is_end: true } };
    return { documents: [doc({ id: "9", place_name: "서울 어딘가", road_address_name: "서울 중구 1" })], meta: { is_end: true } };
  });
  try {
    const r = await searchKakao("32", "강릉시", "남산타워");
    assertEquals(r.outside, true);
    assertEquals(r.places[0].id, "kakao:9");
    assertEquals(s.calls.map((u) => u.searchParams.get("query")), ["강릉시 남산타워", "남산타워"]);
  } finally {
    s.restore();
  }
});

Deno.test("앱에 보내는 장소: 한국 안 좌표만 소수 6자리로, 주소는 있을 때만", () => {
  const out = brief([
    { id: "kakao:1", name: "경포대", type: "heritage", meta: "", lat: 37.79512345678, lng: 128.89612345678, url: "http://place.map.kakao.com/1" },
    { id: "tour:2", name: "좌표 없음", type: "food", meta: "", lat: null, lng: null },
    { id: "tour:3", name: "바다 한가운데", type: "food", meta: "", lat: 0, lng: 0 },
  ]);
  assertEquals(out[0], { id: "kakao:1", name: "경포대", type: "heritage", meta: "", url: "http://place.map.kakao.com/1", lat: 37.795123, lng: 128.896123 });
  assertEquals(out[1], { id: "tour:2", name: "좌표 없음", type: "food", meta: "" });
  assertEquals(out[2], { id: "tour:3", name: "바다 한가운데", type: "food", meta: "" });
});
