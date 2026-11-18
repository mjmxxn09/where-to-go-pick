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
| 투표 만들기 | `POST /v1/polls` | 여행지 후보 "친구한테 물어보기", 여행 카드 "투표로 공유" (아래 "픽클 투표") |

오류 본문은 `{code, message, requestId, reason?}`. 모르는 `reason`은 무시한다.

## 세션 충돌 — 픽클 팀과 먼저 정해야 함

픽클은 **회원당 활성 모바일 세션을 하나만** 허용한다. 이 앱이 같은 계정으로 로그인하면 `409 SESSION_REPLACEMENT_REQUIRED`가 오고, `replaceExistingSession=true`로 다시 보내면 **사용자의 픽클 앱이 로그아웃된다.**

현재 코드는 409를 `SessionConflictException`으로 올리고 자동 교체하지 않는다. 출시 전 Backend 쪽 결정이 필요하다:

1. 이 앱을 별도 클라이언트(세션 종류)로 인정해 픽클 앱과 동시 로그인 허용
2. 픽클 앱에서 이 앱으로 넘기는 연결 토큰(앱 간 SSO)
3. 별도 파트너 API(키·범위) — VoteLock RFC-0023은 Draft, 미구현

어느 쪽이든 VoteLock 저장소의 RFC/DEC 절차를 거쳐야 한다(픽클 Backend·PM 담당 확인).

## 화면 스타일(2026-11-17 정리)

디자인 캔버스 시안 A "포근한 카드" + 시안 B 하단 메뉴. 코드: `lib/core/theme/app_theme.dart`, `app_surfaces.dart`.

- 바탕: 연보라 세로 그라데이션 + 오른쪽 위 분홍 번짐(`AppBackground`)
- 카드: 흰색·반경 24·보랏빛 그림자(`AppCard`, `AppDecorations.card`)
- 제목: 블랙한산스 남색(`titleStyle()`), 본문은 기본 글꼴
- 버튼·칩·알약 탭: 둥근 알약 모양(테마), 주 버튼은 보라 + 보랏빛 그림자
- 하단 메뉴: 흰 바탕 + 위쪽 얇은 선, 지금 탭은 보라 글자 + 아래 작은 점(`AppBottomBar`)

## 시작 화면(스플래시·로그인)

코드: `lib/features/splash/`, 진입은 `lib/app/app.dart`의 `StartGate`.

- 실행할 때마다 픽클 친구 6명(픽클이·보리·모아·토리·일디·리듬이) 중 한 명이 로그인 창 위로 얼굴을 내민다.
  바로 전에 보여 준 친구는 빼고 고른다(`shared_preferences` 키 `splash.last`).
- 이미 로그인돼 있으면 스플래시만 1.2초 보여 주고 홈으로. 아니면 버튼 두 개:
  - **픽클 계정으로 시작하기** → 이메일·비밀번호 시트 → `POST /v1/auth/login`. 409면 "여기서 로그인하면 그쪽은 로그아웃돼요" 확인 후에만 교체.
  - **카카오로 시작하기** → 아직 준비 중 안내(아래).
- 서버 없이(예시 데이터) 실행하면 두 버튼 모두 바로 홈으로 간다.
- 캐릭터 이미지는 회사 캐릭터라 공개 저장소에 올리지 않는다. `assets/characters/splash/README.md` 참고.
  파일이 없으면 이름이 적힌 동그라미로 대신 보인다.

## 카카오 로그인 — 붙일 때 할 일

픽클 서버는 이미 `POST /v1/auth/social/kakao`(OIDC id_token, 처음이면 202 가입 티켓 → `/v1/auth/social/kakao/signup`)를 지원한다.

1. **픽클의 카카오 앱을 같이 쓴다.** 서버가 id_token의 aud(카카오 앱 키)를 검사하고, 카카오 회원번호는 앱마다 다르다.
   이 앱용 카카오 앱을 따로 만들지 말고 픽클 카카오 앱에 이 앱의 패키지명·번들 ID를 플랫폼으로 추가한다(픽클 팀과 협의).
2. `kakao_flutter_sdk_user` 추가, 네이티브 앱 키는 dart-define으로(커밋 금지).
3. 처음 들어온 사용자는 가입 티켓을 받으므로 약관 동의 등 짧은 가입 화면이 필요하다.
4. iOS는 App Store 가이드라인 4.8 때문에 Apple 로그인도 함께 넣어야 한다(픽클 서버 `apple` 지원).
5. 로그인 409(세션 충돌)도 이메일 로그인과 같은 확인 흐름을 쓴다(소셜은 replacementToken).

## 픽클 투표 — 따로 만들지 않고, 여행하다 보면 생기게 (2026-11-17)

코드: `lib/core/votes/vote_repository.dart`(경계·예시 구현), `lib/features/votes/`(말풍선·투표 현황 화면).
지금은 `FixtureVoteRepository`만 쓴다. 아래 "정할 것"이 픽클 쪽에서 정해지면 원격 구현을 붙인다.

| 자리 | 화면에서 | 메서드 |
|---|---|---|
| 여행 중 · 체크인 직후 | 픽클이 말풍선: "방금 간 곳이랑 그 전에 간 곳, 어디가 더 좋았어?" 한 번 누르면 끝, +포인트 | `answerPair` |
| 여행 중 · 추천 목록 | "다녀온 1,240명이 고른 해변 1위" 한 줄, 다녀온 곳엔 "나도 한 표" | `PlaceSuggestion.visitorRank`, `setPlaceVote` |
| 여행지 고르기 | 시·군·구 카드의 ♡로 후보 담기 → 2곳부터 "친구한테 물어보기" → 투표 현황, 마감하면 "○○로 여행 만들기" | `askFriends`, `vote`, `close` |
| 여행 카드 | 스티커 서랍 "투표" 칸의 "한 표 핀"을 장소 옆에 붙이면 후보 → 2곳 이상이면 "투표로 공유" | `voteCandidates()`, `shareCardPoll` |
| 픽클 쪽 | 위에서 생긴 질문이 픽클 잠금화면에 "○○ 다녀온 픽클러의 질문"으로, 체크인·투표는 픽클 포인트로 | (픽클 서버) |

후보 목록(`lib/features/explore/trip_candidates.dart`): 기기에 저장해서 고민 중이면 앱을 다시 켜도 남는다. 후보 중 한 곳으로 여행을 시작하면(투표 1위로 만들었든 직접 골랐든) 비우고 "되돌리기" 알림을 띄운다. 물어본 투표는 후보를 비워도 최근 5개까지 따로 남아 여행지 화면에서 다시 열 수 있다.

정할 것(픽클 Backend·PM):
- `POST /v1/polls`에 지역(시·군·구)·장소를 붙일 칸 — 추천 순위와 잠금화면 노출에 필요
- 체크인 질문을 누구 투표로 볼지(앱이 만드는 공용 투표 vs 사용자 투표)
- "다녀온 사람 표": 표마다 체크인 여부를 받아 주는지, GPS 조작·반복 체크인 대책
- 이 앱 채널의 포인트 기준(+10P는 예시)
- 공유 링크는 픽클 투표 미리보기 웹으로(앱 없이도 투표)

## 채널 구분

픽클 서버는 요청 채널(앱/웹)에 따라 포인트·투표 생성 권한을 다르게 준다. 이 앱이 투표 참여·생성·포인트를 쓰려면 서버가 이 앱을 어떤 채널로 볼지 정해야 한다. 1차는 **읽기 위주**라 영향이 작다.

## 위치 정보

- 체크인: 장소에서 버튼을 누를 때만 한 번 위치 확인
- 걸은 길: 사용자가 켰을 때만 기록, 끄면 즉시 중단. 백그라운드 상시 추적 없음
- 정밀 좌표 저장 최소화, 보관 기간 명시. 위치기반서비스사업 신고 전에는 출시하지 않는다([출시 전 체크리스트](launch-checklist.md))
