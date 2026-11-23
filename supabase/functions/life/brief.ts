import type { Place } from "./tour.ts";

/** 앱에 보내는 장소 모양. 좌표는 한국 안일 때만(소수 6자리, 가볼 곳 지도용), 주소는 있을 때만. */
export const brief = (places: (Place & { url?: string })[]) =>
  places.map(({ id, name, type, meta, url, lat, lng }) => ({
    id,
    name,
    type,
    meta,
    ...(url ? { url } : {}),
    ...(inKorea(lat, lng) ? { lat: round6(lat!), lng: round6(lng!) } : {}),
  }));

const round6 = (v: number) => Math.round(v * 1e6) / 1e6;
const inKorea = (lat: number | null, lng: number | null) =>
  lat != null && lng != null && lat > 32 && lat < 39.5 && lng > 124 && lng < 132.5;
