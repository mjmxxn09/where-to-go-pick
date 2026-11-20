# 여행 기록 서버 (Supabase)

여행·체크인·여행 카드 꾸미기를 Supabase에 저장한다. 픽클 DB는 쓰지 않는다(회사 서버·출시 일정·위치 기록 책임 분리).
로그인은 픽클 계정 그대로이고, Supabase에는 회원 정보가 따로 생기지 않는다.

```text
앱 ──픽클 로그인──▶ 픽클 Backend (/v1/auth/login)
 │
 ├─▶ Edge Function pickle-exchange ── 픽클 GET /v1/me 로 확인 → Supabase 토큰(1시간, sub = "pickle:<subjectId>")
 │
 └─▶ Supabase Data API (trips · check_ins · card_decorations, RLS: 내 sub 행만)
```

- 앱은 **폰에 먼저 저장**하고 서버에 올린다. 서버에 못 올려도 기록은 폰에 남고, 다음에 앱을 열거나 로그인할 때 다시 올린다.
- 앱을 열면 서버 기록을 받아 폰에 없는 여행·카드 꾸미기를 채운다(같은 것은 폰 쪽이 우선).
- 픽클 서버 없이 개발할 때(`PICKLE_API_BASE_URL` 비움)는 **게스트(익명 로그인)** 로 올린다. 게스트 기록은 그 기기 전용이고 나중에 픽클 계정과 합쳐지지 않는다.
- `SUPABASE_URL`·`SUPABASE_PUBLISHABLE_KEY`가 없으면 서버 없이 폰에만 저장한다.
- Supabase가 연결되면 예시 여행(강릉)·예시 방문 지역 없이 빈 지도로 시작한다. 예시는 서버가 하나도 없을 때만 보인다.

## 코드

| 위치 | 내용 |
|---|---|
| `supabase/migrations/20261120060000_travel_records.sql` | 테이블 3개, RLS("내 것만"), 권한 |
| `supabase/functions/pickle-exchange/index.ts` | 픽클 토큰 → Supabase 토큰 교환 |
| `supabase/config.toml` | 프로젝트 이름, 위 함수의 게이트웨이 JWT 검사 끄기 |
| `lib/core/cloud/cloud_session.dart` | 토큰 마련(픽클 교환 / 게스트), 동시에 불러도 한 번만 요청 |
| `lib/core/cloud/supabase_rest.dart` | Data API 읽기·upsert, 401이면 토큰 새로 받아 한 번 재시도 |
| `lib/features/trip/trip_store.dart` | 폰 저장(`trips.v1`), 기록 합치기 |
| `lib/features/trip/trip_cloud.dart` | 여행·체크인 ↔ 서버 행 |
| `lib/features/trip_card/card_cloud.dart` | 카드 꾸미기 ↔ 서버 행(바뀐 쪽만, 손을 멈추고 2초 뒤 올림) |

## 테이블

| 테이블 | 기본 키 | 내용 |
|---|---|---|
| `trips` | user_id, id | 도시 코드·이름, 시작일 |
| `check_ins` | user_id, trip_id, id(장소) | 장소 이름·종류, 체크인 시각 (여행 삭제 시 같이 삭제) |
| `card_decorations` | user_id, page_key | 스티커 JSON, 옮긴 장소 막대 JSON |

`user_id`는 토큰의 sub 문자열이다(`auth.uid()`는 uuid 전용이라 쓰지 않는다). anon(로그인 안 한 요청)에는 권한이 없다.
위치는 장소 이름과 시각만 저장한다. 걸은 길(GPS 좌표)은 아직 올리지 않는다 — 올리기 전에 출시 체크리스트의 위치정보 항목부터.

## 처음 설정 (한 번만)

프로젝트: `where-to-go-pick`, 리전 Seoul, project ref `vwgtsqjpemvyhmjvlgoe`.

1. **CLI 준비**(PC, 저장소 폴더에서)
   ```bash
   npx supabase login
   npx supabase link --project-ref vwgtsqjpemvyhmjvlgoe   # DB 비밀번호를 물어본다
   ```
2. **테이블 만들기**
   ```bash
   npx supabase db push --remote
   ```
   `--remote`가 없으면 CLI가 내 PC의 로컬 Supabase(Docker)로 보내려다 `127.0.0.1:54322` 연결 오류가 난다.
   대시보드 Table Editor에 `trips`, `check_ins`, `card_decorations`가 보이면 된다.
3. **게스트 로그인 켜기(개발용)**: 대시보드 Authentication → Sign In / Providers → **Allow anonymous sign-ins** 켜기.
4. **토큰 서명 키**(픽클 로그인으로 올릴 때 필요. 게스트만 쓸 땐 나중에 해도 된다)
   ```bash
   npx supabase gen signing-key --algorithm ES256
   ```
   - 나온 JSON(개인키)을 비밀번호 관리자 등 안전한 곳에 보관한다. **저장소·채팅에 올리지 않는다.**
   - 대시보드 Project Settings → JWT Keys → 대기 키 만들기에서 **가져오기(import)** 로 붙여 넣고, **Rotate keys** 로 사용 중으로 바꾼다.
     그래야 이 키로 서명한 토큰을 DB가 믿는다. 이전 키로 받은 토큰은 만료될 때까지 계속 쓸 수 있다.
5. **함수 비밀값과 배포**: `supabase/functions/.env` 파일을 만든다(`.gitignore`에 걸려 커밋되지 않는다).
   ```dotenv
   PICKLE_API_BASE_URL=https://픽클-개발-서버-주소
   PICKLE_EXCHANGE_SIGNING_JWK='{"kty":"EC","kid":"...","d":"...", ...}'   # 4번에서 나온 JSON 객체 한 줄을 작은따옴표로 감싸서
   ```
   ```bash
   npx supabase secrets set --env-file supabase/functions/.env
   npx supabase functions deploy pickle-exchange
   ```
   픽클 서버가 사내망에서만 열려 있으면 Supabase가 `/v1/me`에 닿지 못한다(502 `PICKLE_UNAVAILABLE`). 외부에서 닿는 주소가 필요하다.
6. **앱 설정**: `env/dev.json`(커밋되지 않음)에 두 줄 추가 후 `--dart-define-from-file=env/dev.json`으로 실행.
   ```json
   "SUPABASE_URL": "https://vwgtsqjpemvyhmjvlgoe.supabase.co",
   "SUPABASE_PUBLISHABLE_KEY": "sb_publishable_..."
   ```

## 키 취급

| 값 | 어디에 | 공개돼도 되나 |
|---|---|---|
| Project URL, publishable 키 | `env/dev.json` → 앱 | 된다(앱에 들어가는 값). 권한은 RLS가 막는다 |
| DB 비밀번호 | 비밀번호 관리자, `supabase link` 때만 | 안 된다 |
| secret 키(`sb_secret_…`, service_role) | 쓰지 않는다 | 안 된다 — RLS를 무시한다 |
| 서명 개인키(JWK) | `supabase/functions/.env` → `supabase secrets set` | 안 된다 — 아무 사용자 토큰이나 만들 수 있다 |

## 출시 전

- 무료 플랜은 7일 동안 요청이 없으면 일시정지된다. 출시 땐 Pro로 올리고 백업을 켠다.
- 게스트(익명) 로그인을 계속 둘지 정한다. 두려면 캡차, 아니면 끄고 `allowGuest`가 개발 때만 켜지는지 확인.
- 픽클 회원 탈퇴 시 이 기록도 지우는 절차(픽클 쪽 탈퇴 알림 또는 주기적 확인).
