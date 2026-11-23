// 픽클 토큰 → Supabase 토큰 교환.
//
// 1. 앱이 픽클 access token을 보낸다: POST { "pickleAccessToken": "..." }
// 2. 픽클 GET /v1/me 로 누구인지 확인한다(픽클 토큰은 우리가 직접 해석할 수 없다).
// 3. 그 사람 전용 Supabase 토큰(1시간)을 ES256으로 서명해 돌려준다. sub = "pickle:<subjectId>"
//    (PICKLE_ENV가 prod가 아니면 "pickle-<env>:<subjectId>" — 개발 서버와 상용 서버의 같은 번호 회원이 섞이지 않게)
//
// 비밀값(supabase secrets set):
//   PICKLE_API_BASE_URL          예: https://api.example.com  (끝의 / 없이)
//   PICKLE_ENV                   dev | prod (없으면 prod). PICKLE_API_BASE_URL이 어느 서버인지 — 바꿀 때 함께 바꾼다
//   PICKLE_EXCHANGE_SIGNING_JWK  `supabase gen signing-key --algorithm ES256`으로 만든 개인키 JWK(JSON 한 줄)
//                                대시보드 JWT Keys에 가져오기(import) → Rotate로 사용 중으로 바꿔야 DB가 믿는다.
// SUPABASE_URL은 Supabase가 자동으로 넣어 준다.

import { importJWK, SignJWT } from "npm:jose@5.9.6";

const TOKEN_TTL_SECONDS = 60 * 60;
const PICKLE_TIMEOUT_MS = 5000;

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

function json(status: number, body: unknown): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}

function fail(status: number, code: string, message: string): Response {
  return json(status, { code, message });
}

type SigningKey = { key: CryptoKey | Uint8Array; kid: string };
let signingKey: Promise<SigningKey> | null = null;

function loadSigningKey(): Promise<SigningKey> {
  if (!signingKey) {
    signingKey = (async () => {
      const raw = Deno.env.get("PICKLE_EXCHANGE_SIGNING_JWK");
      if (!raw) throw new Error("PICKLE_EXCHANGE_SIGNING_JWK is not set");
      const jwk = JSON.parse(raw);
      if (!jwk.kid || !jwk.d) throw new Error("signing JWK needs kid and private part d");
      // CLI가 만든 JWK에는 key_ops ["sign","verify"]가 있는데, 개인키를 verify 용도로는 가져올 수 없어 뺀다.
      const { key_ops: _keyOps, use: _use, ...privateJwk } = jwk;
      return { key: await importJWK(privateJwk, "ES256"), kid: String(jwk.kid) };
    })();
    signingKey.catch(() => {
      signingKey = null; // 설정을 고친 뒤 다시 읽을 수 있게
    });
  }
  return signingKey;
}

type PickleMe = { subjectId: string };

/** 개발·상용 픽클 서버는 회원 번호가 겹칠 수 있어서, 상용이 아니면 sub 앞에 환경 이름을 붙인다. */
function subjectPrefix(): string {
  const env = (Deno.env.get("PICKLE_ENV") ?? "prod").trim().toLowerCase();
  if (env === "" || env === "prod") return "pickle";
  if (!/^[a-z0-9]{1,10}$/.test(env)) throw new Error("PICKLE_ENV must be short letters/digits");
  return `pickle-${env}`;
}

/** 픽클에 물어본다. 토큰이 틀렸으면 null, 픽클에 닿지 않으면 예외. */
async function whoIs(pickleToken: string): Promise<PickleMe | null> {
  const base = (Deno.env.get("PICKLE_API_BASE_URL") ?? "").replace(/\/+$/, "");
  if (!base) throw new Error("PICKLE_API_BASE_URL is not set");
  const res = await fetch(`${base}/v1/me`, {
    headers: { Accept: "application/json", Authorization: `Bearer ${pickleToken}` },
    signal: AbortSignal.timeout(PICKLE_TIMEOUT_MS),
  });
  if (res.status === 401 || res.status === 403) return null;
  if (!res.ok) throw new Error(`pickle /v1/me answered ${res.status}`);
  const me = await res.json();
  const id = typeof me?.subjectId === "string" ? me.subjectId.trim() : "";
  if (!id || id.length > 100) throw new Error("pickle /v1/me has no usable subjectId");
  return { subjectId: id };
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });
  if (req.method !== "POST") return fail(405, "METHOD_NOT_ALLOWED", "POST만 받아요.");

  let pickleToken = "";
  try {
    const body = await req.json();
    pickleToken = typeof body?.pickleAccessToken === "string" ? body.pickleAccessToken.trim() : "";
  } catch {
    // 아래에서 400
  }
  if (!pickleToken || pickleToken.length > 4096) {
    return fail(400, "BAD_REQUEST", "pickleAccessToken이 필요해요.");
  }

  let me: PickleMe | null;
  try {
    me = await whoIs(pickleToken);
  } catch (e) {
    console.error("pickle check failed", e instanceof Error ? e.message : e);
    return fail(502, "PICKLE_UNAVAILABLE", "픽클 서버에 닿지 않았어요. 잠시 뒤 다시 해 주세요.");
  }
  if (!me) return fail(401, "PICKLE_UNAUTHENTICATED", "픽클 로그인이 만료됐어요.");

  try {
    const { key, kid } = await loadSigningKey();
    const now = Math.floor(Date.now() / 1000);
    const expiresAt = now + TOKEN_TTL_SECONDS;
    const userId = `${subjectPrefix()}:${me.subjectId}`;
    const supabaseUrl = (Deno.env.get("SUPABASE_URL") ?? "").replace(/\/+$/, "");
    const token = await new SignJWT({
      role: "authenticated",
      is_anonymous: false,
      app_metadata: { provider: "pickle" },
    })
      .setProtectedHeader({ alg: "ES256", kid, typ: "JWT" })
      .setSubject(userId)
      .setAudience("authenticated")
      .setIssuer(`${supabaseUrl}/auth/v1`)
      .setIssuedAt(now)
      .setExpirationTime(expiresAt)
      .sign(key);
    return json(200, { access_token: token, expires_at: expiresAt, user_id: userId });
  } catch (e) {
    console.error("signing failed", e instanceof Error ? e.message : e);
    return fail(500, "EXCHANGE_MISCONFIGURED", "서버 설정을 확인해 주세요.");
  }
});
