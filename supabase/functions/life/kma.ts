// 기상청 단기예보 조회서비스(VilageFcstInfoService_2.0): 위경도 → 격자, 발표 시각, 하루 요약(3시간 간격),
// 지금 날씨(초단기실황 getUltraSrtNcst — 같은 서비스라 키 그대로).

import { getJson, itemsOf, TtlCache } from "./datago.ts";

const BASE = "https://apis.data.go.kr/1360000/VilageFcstInfoService_2.0/getVilageFcst";
const NOW_BASE = "https://apis.data.go.kr/1360000/VilageFcstInfoService_2.0/getUltraSrtNcst";

/** 기상청 격자 변환(람베르트 정각원추, 기상청 제공 공식). */
export function toGrid(lat: number, lng: number): { nx: number; ny: number } {
  const RE = 6371.00877, GRID = 5.0, SLAT1 = 30.0, SLAT2 = 60.0, OLON = 126.0, OLAT = 38.0, XO = 43, YO = 136;
  const DEGRAD = Math.PI / 180.0;
  const re = RE / GRID;
  const slat1 = SLAT1 * DEGRAD, slat2 = SLAT2 * DEGRAD, olon = OLON * DEGRAD, olat = OLAT * DEGRAD;
  let sn = Math.tan(Math.PI * 0.25 + slat2 * 0.5) / Math.tan(Math.PI * 0.25 + slat1 * 0.5);
  sn = Math.log(Math.cos(slat1) / Math.cos(slat2)) / Math.log(sn);
  let sf = Math.tan(Math.PI * 0.25 + slat1 * 0.5);
  sf = (Math.pow(sf, sn) * Math.cos(slat1)) / sn;
  let ro = Math.tan(Math.PI * 0.25 + olat * 0.5);
  ro = (re * sf) / Math.pow(ro, sn);
  let ra = Math.tan(Math.PI * 0.25 + lat * DEGRAD * 0.5);
  ra = (re * sf) / Math.pow(ra, sn);
  let theta = lng * DEGRAD - olon;
  if (theta > Math.PI) theta -= 2.0 * Math.PI;
  if (theta < -Math.PI) theta += 2.0 * Math.PI;
  theta *= sn;
  return { nx: Math.floor(ra * Math.sin(theta) + XO + 0.5), ny: Math.floor(ro - ra * Math.cos(theta) + YO + 0.5) };
}

/** 한국 시간 기준 날짜·시·분. */
export function kst(now: Date): { ymd: string; hour: number; minute: number } {
  const t = new Date(now.getTime() + 9 * 60 * 60 * 1000);
  const ymd = `${t.getUTCFullYear()}${String(t.getUTCMonth() + 1).padStart(2, "0")}${String(t.getUTCDate()).padStart(2, "0")}`;
  return { ymd, hour: t.getUTCHours(), minute: t.getUTCMinutes() };
}

/** 가장 최근 발표(02·05·08·11·14·17·20·23시, 발표 후 10분부터 조회 가능). */
export function latestBase(now: Date): { baseDate: string; baseTime: string } {
  const { ymd, hour, minute } = kst(now);
  const minutes = hour * 60 + minute;
  const hours = [23, 20, 17, 14, 11, 8, 5, 2];
  for (const h of hours) {
    if (minutes >= h * 60 + 10) return { baseDate: ymd, baseTime: `${String(h).padStart(2, "0")}00` };
  }
  const y = kst(new Date(now.getTime() - 24 * 60 * 60 * 1000)).ymd;
  return { baseDate: y, baseTime: "2300" };
}

export type Sky = "sunny" | "cloudy" | "rainy" | "snowy";
/** 3시간 간격 한 칸. pop은 강수확률(%). */
export type Hourly = { hour: number; temperature: number; sky: Sky; pop?: number };

/** 지금 날씨(초단기실황). hour는 관측 시각(정시). */
export type NowWeather = { hour: number; temperature: number; sky: Sky; humidity?: number; wind?: number; rain?: number };

export type DayWeather = {
  sky: Sky;
  temperature: number;
  min: number;
  max: number;
  hourly: Hourly[];
  tip: string | null;
  now?: NowWeather;
};

type Slot = { tmp?: number; sky?: string; pty?: string; pop?: number };

function skyOf(slot: Slot): Sky {
  switch (slot.pty) {
    case "1": case "2": case "4": case "5": case "6": return "rainy";
    case "3": case "7": return "snowy";
  }
  return slot.sky === "1" ? "sunny" : "cloudy";
}

/**
 * 예보 항목들을 [ymd] 하루로 요약한다.
 * - 시간별(3시간 간격): 오늘이면 [nowHour] 다음부터 그날 끝까지, 다른 날이면 0·3·6…21시.
 * - TMN·TMX(최저·최고)가 없으면(늦은 발표) 그날 TMP의 최소·최대로 대신한다.
 */
export function summarize(items: any[], ymd: string, nowHour: number | null): DayWeather | null {
  const slots = new Map<number, Slot>();
  let tmn: number | undefined;
  let tmx: number | undefined;
  for (const it of items) {
    if (String(it.fcstDate) !== ymd) continue;
    const hour = Math.floor(Number(it.fcstTime) / 100);
    const value = String(it.fcstValue);
    const slot = slots.get(hour) ?? {};
    switch (it.category) {
      case "TMP": slot.tmp = Number(value); break;
      case "SKY": slot.sky = value; break;
      case "PTY": slot.pty = value; break;
      case "POP": slot.pop = Number(value); break;
      case "TMN": tmn = Number(value); break;
      case "TMX": tmx = Number(value); break;
    }
    slots.set(hour, slot);
  }
  const hours = [...slots.keys()].filter((h) => slots.get(h)!.tmp != null).sort((a, b) => a - b);
  if (!hours.length) return null;

  const temps = hours.map((h) => slots.get(h)!.tmp!);
  const min = Math.round(tmn ?? Math.min(...temps));
  const max = Math.round(tmx ?? Math.max(...temps));
  const from = nowHour ?? 9;
  const current = hours.find((h) => h >= from) ?? hours[hours.length - 1];
  const nowSlot = slots.get(current)!;
  const hourly = hours
    .filter((h) => (nowHour == null ? h % 3 === 0 : h > current && (h - current) % 3 === 0))
    .map((h) => {
      const s = slots.get(h)!;
      return { hour: h, temperature: Math.round(s.tmp!), sky: skyOf(s), ...(s.pop != null && !Number.isNaN(s.pop) ? { pop: s.pop } : {}) };
    });
  const later = hours.filter((h) => h >= current).map((h) => skyOf(slots.get(h)!));

  let tip: string | null = null;
  if (later.includes("snowy")) tip = "눈 소식이 있어요. 미끄럼 조심!";
  else if (later.includes("rainy")) tip = "비 소식이 있어요. 우산 챙기기!";
  else if (min <= 0) tip = "영하로 내려가요. 따뜻하게 입기!";
  else if (max >= 30) tip = "더워요. 물 자주 마시기!";
  else if (max - min >= 10) tip = "일교차가 커요. 겉옷 챙기기!";

  return { sky: skyOf(nowSlot), temperature: Math.round(nowSlot.tmp!), min, max, hourly, tip };
}

/** 초단기실황 발표 시각: 정시 자료가 40분쯤 올라온다 → 45분 전이면 한 시간 전 자료. */
export function nowBase(now: Date): { baseDate: string; baseTime: string; hour: number } {
  const at = kst(now);
  const t = at.minute < 45 ? new Date(now.getTime() - 60 * 60 * 1000) : now;
  const k = kst(t);
  return { baseDate: k.ymd, baseTime: `${String(k.hour).padStart(2, "0")}00`, hour: k.hour };
}

/**
 * 초단기실황 항목 → 지금 날씨. 하늘(맑음·흐림)은 실황에 없어서 [forecastSky](그 시각 예보)로, 비·눈이면 실황 우선.
 * 기온(T1H)이 없으면 null.
 */
export function nowFrom(items: any[], hour: number, forecastSky: Sky): NowWeather | null {
  const v: Record<string, number> = {};
  for (const it of items) {
    const n = Number(it.obsrValue);
    if (typeof it.category === "string" && !Number.isNaN(n)) v[it.category] = n;
  }
  if (v.T1H == null) return null;
  const pty = v.PTY;
  const sky: Sky = pty === 3 || pty === 7 ? "snowy" : pty != null && pty > 0 ? "rainy" : forecastSky === "rainy" || forecastSky === "snowy" ? "cloudy" : forecastSky;
  return {
    hour,
    temperature: Math.round(v.T1H),
    sky,
    ...(v.REH != null ? { humidity: Math.round(v.REH) } : {}),
    ...(v.WSD != null ? { wind: Math.round(v.WSD * 10) / 10 } : {}),
    ...(v.RN1 != null && v.RN1 > 0 ? { rain: v.RN1 } : {}),
  };
}

const nowCache = new TtlCache<any[]>(10 * 60 * 1000);

export function loadNow(nx: number, ny: number, now: Date): Promise<{ items: any[]; hour: number }> {
  const { baseDate, baseTime, hour } = nowBase(now);
  return nowCache
    .get(`${nx},${ny},${baseDate}${baseTime}`, async () => {
      const json = await getJson(NOW_BASE, {
        pageNo: 1,
        numOfRows: 20,
        dataType: "JSON",
        base_date: baseDate,
        base_time: baseTime,
        nx,
        ny,
      });
      return itemsOf(json, ["00"]);
    })
    .then((items) => ({ items, hour }));
}

const forecastCache = new TtlCache<any[]>(30 * 60 * 1000);

export function loadForecast(nx: number, ny: number, now: Date): Promise<any[]> {
  const { baseDate, baseTime } = latestBase(now);
  return forecastCache.get(`${nx},${ny},${baseDate}${baseTime}`, async () => {
    const json = await getJson(BASE, {
      pageNo: 1,
      numOfRows: 1000,
      dataType: "JSON",
      base_date: baseDate,
      base_time: baseTime,
      nx,
      ny,
    });
    return itemsOf(json, ["00"]);
  });
}
