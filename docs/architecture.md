# 아키텍처와 픽클 API 연동

## 구성

```text
[어디갈지 Pick! 앱 (Flutter)]
   ├─ 픽클 Backend /v1 ─ 로그인, 내 프로필, 관심사, 내 픽클 친구(읽기)
   └─ 생활 서버 (신규, 아직 없음)
        ├─ 기상청 단기예보 프록시 + 캐시 (위경도 → 격자 변환은 서버)
        ├─ TourAPI 프록시 + 캐시, 픽클 투표 결과와 합친 추천
        └─ 여행·체크인·경로 저장 (사용자 확인: 앱 토큰으로 픽클 GET /v1/me 호출)
```

- 앱은 공공 API를 직접 부르지 않는다. 키를 앱에 넣으면 추출되기 때문이다.
- 픽클 토큰은 서버가 직접 해석할 수 없는 opaque 토큰이므로, 생활 서버는 픽클 `/v1/me` 호출로 사용자를 확인한다(결과 짧게 캐시).
- 앱 코드는 `PickleRepository`, `LifeRepository` 인터페이스만 본다. 주소가 없으면 예시 구현이 쓰인다.

## 픽클 API (VoteLock `docs/api/openapi.yaml` 기준)

| 용도 | 호출 | 비고 |
|---|---|---|
| 로그인 | `POST /v1/auth/login` | `email, password, devicePlatform, appVersion, deviceId?, replaceExistingSession` |
| 토큰 갱신 | `POST /v1/auth/refresh` | **single-flight 필수**. 회전된 refresh를 다시 보내면 서버가 모든 세션을 폐기 |
| 내 프로필 | `GET /v1/me` | `subjectId, nickname, avatarUrl` |
| 관심사 카탈로그 | `GET /v1/interests` | 인증 불필요 |
| 내 관심사 | `GET /v1/me/interests` | `categoryKeys[]` |
| 내 픽클 친구 | `GET /v1/me/companion/village` | `enabled=false`면 없음. `species`: DUCK·OTTER·RABBIT·FOX·OWL·DROPLET, 모르는 값은 DUCK |
| (2차) 투표 만들기 | `POST /v1/polls` | 여행 카드 → "이 여행으로 투표 만들기" |

오류 본문은 `{code, message, requestId, reason?}`. 모르는 `reason`은 무시한다.

## 세션 충돌 — 픽클 팀과 먼저 정해야 함

픽클은 **회원당 활성 모바일 세션을 하나만** 허용한다. 이 앱이 같은 계정으로 로그인하면 `409 SESSION_REPLACEMENT_REQUIRED`가 오고, `replaceExistingSession=true`로 다시 보내면 **사용자의 픽클 앱이 로그아웃된다.**

현재 코드는 409를 `SessionConflictException`으로 올리고 자동 교체하지 않는다. 출시 전 Backend 쪽 결정이 필요하다:

1. 이 앱을 별도 클라이언트(세션 종류)로 인정해 픽클 앱과 동시 로그인 허용
2. 픽클 앱에서 이 앱으로 넘기는 연결 토큰(앱 간 SSO)
3. 별도 파트너 API(키·범위) — VoteLock RFC-0023은 Draft, 미구현

어느 쪽이든 VoteLock 저장소의 RFC/DEC 절차를 거쳐야 한다(픽클 Backend·PM 담당 확인).

## 채널 구분

픽클 서버는 요청 채널(앱/웹)에 따라 포인트·투표 생성 권한을 다르게 준다. 이 앱이 투표 참여·생성·포인트를 쓰려면 서버가 이 앱을 어떤 채널로 볼지 정해야 한다. 1차는 **읽기 위주**라 영향이 작다.

## 위치 정보

- 체크인: 장소에서 버튼을 누를 때만 한 번 위치 확인
- 걸은 길: 사용자가 켰을 때만 기록, 끄면 즉시 중단. 백그라운드 상시 추적 없음
- 정밀 좌표 저장 최소화, 보관 기간 명시. 위치기반서비스사업 신고 전에는 출시하지 않는다([출시 전 체크리스트](launch-checklist.md))
