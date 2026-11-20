// 이 앱 사용자(픽클 교환 토큰 또는 게스트)만 부를 수 있게 한다. 공공데이터 호출량을 지키려는 것.
//
// - ES256/RS256 토큰: 프로젝트 JWKS로 직접 확인(픽클 교환 토큰은 가져온 서명 키로 서명됨)
// - HS256 토큰(옛 JWT secret 프로젝트의 게스트): Auth 서버에 물어본다

import { createRemoteJWKSet, decodeProtectedHeader, jwtVerify } from "npm:jose@5.9.6";

let jwks: ReturnType<typeof createRemoteJWKSet> | null = null;

function supabaseUrl(): string {
  return (Deno.env.get("SUPABASE_URL") ?? "").replace(/\/+$/, "");
}

export async function isAppUser(req: Request): Promise<boolean> {
  const header = req.headers.get("authorization") ?? "";
  const token = header.toLowerCase().startsWith("bearer ") ? header.slice(7).trim() : "";
  if (!token || token.split(".").length !== 3) return false;
  let alg = "";
  try {
    alg = String(decodeProtectedHeader(token).alg ?? "");
  } catch {
    return false;
  }
  const base = supabaseUrl();
  if (alg === "HS256") {
    const apikey = req.headers.get("apikey") ?? Deno.env.get("SUPABASE_ANON_KEY") ?? "";
    const res = await fetch(`${base}/auth/v1/user`, { headers: { apikey, Authorization: `Bearer ${token}` } });
    await res.body?.cancel();
    return res.ok;
  }
  try {
    jwks ??= createRemoteJWKSet(new URL(`${base}/auth/v1/.well-known/jwks.json`));
    const { payload } = await jwtVerify(token, jwks, { audience: "authenticated" });
    return payload.role === "authenticated";
  } catch {
    return false;
  }
}
