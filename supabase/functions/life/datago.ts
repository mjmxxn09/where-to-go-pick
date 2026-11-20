// 공공데이터포털(apis.data.go.kr) 호출. 인증키는 함수 비밀값 DATA_GO_KR_SERVICE_KEY(Decoding 값)에서 읽고,
// URLSearchParams가 한 번만 인코딩한다(Encoding 값을 넣으면 두 번 인코딩돼 "등록되지 않은 키"가 된다).

export class UpstreamError extends Error {
  constructor(readonly code: string, message: string) {
    super(message);
  }
}

const TIMEOUT_MS = 8000;

export function serviceKey(): string {
  const key = (Deno.env.get("DATA_GO_KR_SERVICE_KEY") ?? "").trim();
  if (!key) throw new UpstreamError("SERVICE_KEY_MISSING", "DATA_GO_KR_SERVICE_KEY 비밀값이 없어요.");
  return key;
}

/** 오류는 JSON을 요청해도 XML로 올 때가 많다. 그 안의 코드·메시지를 꺼낸다. */
export function xmlError(text: string): UpstreamError | null {
  if (!text.trimStart().startsWith("<")) return null;
  const pick = (tag: string) => text.match(new RegExp(`<${tag}>([^<]*)</${tag}>`))?.[1]?.trim();
  const code = pick("returnAuthMsg") ?? pick("resultMsg") ?? pick("errMsg") ?? "UPSTREAM_XML";
  const reason = pick("returnReasonCode") ?? pick("resultCode") ?? "";
  return new UpstreamError(code, `공공데이터 오류 ${code}${reason ? ` (${reason})` : ""}`);
}

export async function getJson(base: string, params: Record<string, string | number>): Promise<any> {
  const query = new URLSearchParams({ serviceKey: serviceKey() });
  for (const [k, v] of Object.entries(params)) query.set(k, String(v));
  let res: Response;
  try {
    res = await fetch(`${base}?${query}`, { signal: AbortSignal.timeout(TIMEOUT_MS) });
  } catch (e) {
    throw new UpstreamError("UPSTREAM_UNREACHABLE", `공공데이터 서버에 닿지 않았어요: ${e instanceof Error ? e.message : e}`);
  }
  const text = await res.text();
  const xml = xmlError(text);
  if (xml) throw xml;
  if (!res.ok) throw new UpstreamError(`HTTP_${res.status}`, `공공데이터 서버 응답 ${res.status}`);
  try {
    return JSON.parse(text);
  } catch {
    throw new UpstreamError("UPSTREAM_BAD_JSON", "공공데이터 응답을 읽지 못했어요.");
  }
}

/** response.body.items.item 을 배열로. 결과가 없으면 items가 빈 문자열("")로 오기도 한다. */
export function itemsOf(json: any, okCodes: string[]): any[] {
  const header = json?.response?.header;
  const code = String(header?.resultCode ?? "");
  if (!okCodes.includes(code)) {
    throw new UpstreamError(header?.resultMsg ?? `RESULT_${code}`, `공공데이터 결과 코드 ${code} ${header?.resultMsg ?? ""}`.trim());
  }
  const items = json?.response?.body?.items;
  const item = items && typeof items === "object" ? items.item : undefined;
  if (Array.isArray(item)) return item;
  return item ? [item] : [];
}

/** 아주 작은 메모리 캐시(함수 인스턴스가 살아 있는 동안). 실패한 요청은 담지 않는다. */
export class TtlCache<T> {
  #map = new Map<string, { at: number; value: Promise<T> }>();
  constructor(readonly ttlMs: number, readonly max = 500) {}

  get(key: string, load: () => Promise<T>): Promise<T> {
    const now = Date.now();
    const hit = this.#map.get(key);
    if (hit && now - hit.at < this.ttlMs) return hit.value;
    const value = load();
    this.#map.set(key, { at: now, value });
    value.catch(() => this.#map.delete(key));
    if (this.#map.size > this.max) this.#map.delete(this.#map.keys().next().value!);
    return value;
  }
}
