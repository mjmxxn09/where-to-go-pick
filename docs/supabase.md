# 여행 기록 서버 (Supabase)

여행·체크인·여행 카드 꾸미기를 Supabase에 저장한다. 픽클 DB는 쓰지 않는다(회사 서버·출시 일정·위치 기록 책임 분리).
로그인은 픽클 계정 그대로이고, Supabase에는 회원 정보가 따로 생기지 않는다.

```text
앱 ──픽클 로그인──▶ 픽클 Backend (/v1/auth/login)
 │
 ├─▶ Edge Function pickle-exchange ── 픽클 GET /v1/me 로 확인 → Supabase 토큰(1시간, sub = "pickle:<subjectId>")
 │
 ├─▶ Supabase Data API (trips · check_ins · card_decorations, RLS: 내 sub 행만)
 │
 └─▶ Edge Function life ── 한국관광공사 TourAPI(명소·맛집) · 기상청 단기예보(날씨). 공공데이터 키는 함수 비밀값에만
```

- 앱은 **폰에 먼저 저장**하고 서버에 올린다. 서버에 못 올려도 기록은 폰에 남고, 다음에 앱을 열거나 로그인할 때 다시 올린다.
- 앱을 열면 서버 기록을 받아 폰에 없는 여행·카드 꾸미기를 채운다(같은 것은 폰 쪽이 우선).
- 앱이 다시 앞으로 올 때마다 다시 맞춘다. 지운 여행·체크인은 서버에서도 지우고, 못 지웠으면 "지운 목록"을 폰에 남겨 합칠 때 되살아나지 않게 한 뒤 다음에 다시 지운다.
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
| `supabase/functions/life/` | 여행지 정보: 법정동 코드 찾기(`tour.ts`), 카카오 인기·검색(`kakao.ts`), 격자 변환·예보 요약(`kma.ts`), 호출자 확인(`auth.ts`) |
| `lib/core/life/supabase_life_repository.dart` | 앱 쪽: 지도 id → 도 코드·시 이름으로 `life` 호출, 장소는 앱 켜진 동안·날씨는 한 시간 캐시 |

## 여행지 정보 (Edge Function `life`)

- `POST {action: "popular" | "search" | "weather" | "places", provinceCode: "32", cityName: "강릉시", date?, query?, page?}` — 이 앱 사용자 토큰만 받는다(공공데이터·카카오 호출량 보호).
  `cityName`을 비우면 **도·광역시 전체**(대전 전체, 강원 전체): 인기·검색은 그 도 주소인 곳, 관광공사는 시·군·구 코드 없이 도 코드만, 날씨는 그 도 관광지 좌표의 가운데.
- **인기 장소(`popular`)** — 여행 중 화면 위쪽. 명소(`가볼만한곳` AT4)·맛집(FD6)·카페(CE7)·문화(`박물관 미술관` CT1) 칸마다 그 시·군·구 주소인 곳만 카카오 정확도순 5곳(6시간 캐시).
  카카오 키(`KAKAO_REST_API_KEY`)가 없으면 아래 TourAPI 장소 목록에서 칸마다 앞 5곳(`source: "tour"`).
- **검색(`search`, `page` 1~3)** — 카카오 키워드 검색 15곳씩, 최대 45곳. 그 지역 이름을 붙여 찾고, 그 지역 주소가 하나도 없으면 전국 결과(`outside: true`). 결과마다 카카오맵 장소 페이지 `url`(앱은 `place.map.kakao.com`만 연다).
- 장소마다 `lat`·`lng`(한국 안 좌표만, 소수 6자리) — 앱의 가볼 곳 지도용.
  카카오 키가 없으면 TourAPI `searchKeyword2`(아래).
- 카카오 키 준비: [developers.kakao.com](https://developers.kakao.com) 앱 → 앱 키의 **REST API 키**, 제품 설정 → 카카오맵 **사용 설정 ON**. `supabase/functions/.env`에 `KAKAO_REST_API_KEY=...` 한 줄 → `npx supabase secrets set --env-file supabase/functions/.env`. 하루 10만 번까지 무료.
- 장소(`places`, 예전 앱 호환): 법정동 시·군·구 목록(`ldongCode2`, 하루 캐시)에서 도시를 찾고, 관광지 40·음식점 30·문화시설 10·레포츠 10·쇼핑 10곳(`areaBasedList2`, 사진 있는 곳 먼저, 숙박 제외, 6시간 캐시).
- TourAPI 검색: `searchKeyword2`로 그 시·군·구에서, 없으면 도 전체에서 30곳(1시간 캐시). 숙박도 포함.
  앱 지도는 조금 옛 행정구역이라 이름이 다르면 맞춰 준다(인천 남구 → 미추홀구, 군위군은 대구에서 찾기, 합친 시는 구 두 개까지).
- 장소 종류: 음식점은 이름으로 카페·해산물·맛집, 관광지는 이름(해수욕장·시장·…사·궁…)과 분류 코드로 해변·시장·문화유산·자연·놀거리.
- 날씨: 그 도시 장소 좌표의 가운데 → 기상청 격자 → 최신 단기예보(30분 캐시). 그날 최저·최고, 한 줄 팁, 3시간 간격 전부
  (오늘이면 지금 다음부터 그날 끝까지, 다른 날이면 0·3…21시, 칸마다 강수확률 `pop`).
  오늘이면 `now`도 — 초단기실황(`getUltraSrtNcst`, 같은 서비스라 같은 키, 정시 자료가 40분쯤 올라와 45분 전이면 한 시간 전 자료, 10분 캐시)의
  기온·습도·바람·1시간 강수량. 하늘(맑음·흐림)은 실황에 없어 그 시각 예보로, 비·눈은 실황 우선. 실황을 못 받아도 예보는 그대로 보낸다.
- 테스트: `deno test -A supabase/functions/life/` (`life_test.ts`, `kakao_test.ts`)

## 테이블

| 테이블 | 기본 키 | 내용 |
|---|---|---|
| `trips` | user_id, id | 도시 코드·이름, 시작일, 가볼 곳(`planned` JSON, 담은 순서), 마친 시각(`ended_at`, 진행 중이면 null), 정한 기간(`planned_days`, 1~30일, 정하지 않으면 null) |
| `check_ins` | user_id, trip_id, id(장소) | 장소 이름·종류, 체크인 시각 (여행 삭제 시 같이 삭제) |
| `card_decorations` | user_id, page_key | 스티커 JSON, 옮긴 장소 막대 JSON |

`user_id`는 토큰의 sub 문자열이다(`auth.uid()`는 uuid 전용이라 쓰지 않는다). anon(로그인 안 한 요청)에는 권한이 없다.
체크인은 장소 이름과 시각만 저장한다. 폰 위치(GPS)는 쓰지도 올리지도 않는다. 가볼 곳(`planned`)에는 장소 자체의 좌표(카카오·관광공사 공개 좌표)가 들어간다.

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
   PICKLE_ENV=dev                                                            # 상용 서버로 바꿀 때 prod
   PICKLE_EXCHANGE_SIGNING_JWK='{"kty":"EC","kid":"...","d":"...", ...}'   # 4번에서 나온 JSON 객체 한 줄을 작은따옴표로 감싸서
   ```
   ```bash
   npx supabase secrets set --env-file supabase/functions/.env
   npx supabase functions deploy pickle-exchange
   ```
   픽클 서버가 사내망에서만 열려 있으면 Supabase가 `/v1/me`에 닿지 못한다(502 `PICKLE_UNAVAILABLE`). 외부에서 닿는 주소가 필요하다.
   - 이 함수는 픽클 서버 **하나**만 믿는다. 앱을 개발 서버로 돌리면 함수도 개발 서버, 상용이면 상용.
     둘을 동시에 쓰려면 Supabase 프로젝트를 둘로 나눈다(개발용·상용용).
   - `PICKLE_ENV=dev`면 sub가 `pickle-dev:<번호>`라서 개발 서버 회원 기록이 상용 회원 기록과 섞이지 않는다.
6. **여행지 정보 함수**: 공공데이터포털에서 `한국관광공사_국문 관광정보 서비스_GW`, `기상청_단기예보 조회서비스` 활용신청 후,
   `supabase/functions/.env`에 `DATA_GO_KR_SERVICE_KEY=일반 인증키(Decoding)`를 넣고
   ```bash
   npx supabase secrets set --env-file supabase/functions/.env
   npx supabase functions deploy life
   ```
   `SERVICE_KEY_IS_NOT_REGISTERED_ERROR`가 나오면 승인 직후일 수 있다(1시간쯤 뒤 다시).
7. **앱 설정**: 주소와 publishable 키는 `AppConfig`에 기본값으로 들어 있어 `flutter run`만 하면 연결된다(2026-11-23).
   다른 프로젝트를 쓸 때만 `env/dev.json`으로 덮어쓰고, 서버 없이 보려면 `--dart-define=SAMPLE_MODE=true`.
   ```json
   "SUPABASE_URL": "https://vwgtsqjpemvyhmjvlgoe.supabase.co",
   "SUPABASE_PUBLISHABLE_KEY": "sb_publishable_..."
   ```

## 키 취급

| 값 | 어디에 | 공개돼도 되나 |
|---|---|---|
| Project URL, publishable 키 | `AppConfig` 기본값(앱 코드) | 된다(앱에 들어가는 값). 권한은 RLS가 막는다 |
| DB 비밀번호 | 비밀번호 관리자, `supabase link` 때만 | 안 된다 |
| secret 키(`sb_secret_…`, service_role) | 쓰지 않는다 | 안 된다 — RLS를 무시한다 |
| 서명 개인키(JWK) | `supabase/functions/.env` → `supabase secrets set` | 안 된다 — 아무 사용자 토큰이나 만들 수 있다 |
| 공공데이터포털 인증키 | `supabase/functions/.env` → `supabase secrets set` | 안 된다 — 남이 쓰면 하루 호출량이 바닥난다 |

## 출시 전

- 무료 플랜은 7일 동안 요청이 없으면 일시정지된다. 출시 땐 Pro로 올리고 백업을 켠다.
- 게스트(익명) 로그인을 계속 둘지 정한다. 두려면 캡차, 아니면 끄고 `allowGuest`가 개발 때만 켜지는지 확인.
- 픽클 회원 탈퇴 시 이 기록도 지우는 절차(픽클 쪽 탈퇴 알림 또는 주기적 확인).
