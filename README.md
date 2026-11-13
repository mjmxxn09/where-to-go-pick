# 어디갈지 Pick! (where-to-go-pick)

픽클 친구들과 여행지를 고르고, 여행 중엔 명소·맛집에 체크인하고, 다녀온 길을 모눈종이 여행 노트와 색칠 지도로 남기는 앱이에요.
픽클(VoteLock) 계정과 `/v1` API를 그대로 사용해요.

> 지금은 **첫 뼈대** 단계예요. 서버 주소 없이 실행하면 예시 데이터(강릉 2박 3일)로 모든 화면을 볼 수 있어요.

## 화면

| 탭 | 하는 일 |
|---|---|
| 내 지도 | 다녀온 시·군·구만 색칠된 대한민국 지도. 도를 누르면 시·군·구 지도로 들어가요. |
| 여행지 | 픽클 관심사 칩 → 도 → 시·군·구 고르기 → 그날 날씨 → 여행 만들기 |
| 여행 중 | 그날 날씨, 명소/맛집 추천(픽클 투표 배지), 버튼 한 번 체크인, 시간순 기록, 걸은 길 기록 스위치 |
| 산책 | 2차 범위(준비 중) |

여행 카드: 체크인을 시간순으로 구불구불한 길 위에 놓은 모눈종이 노트. **한 장에 모아보기 / 하루씩 나눠보기(폴더)** 를 고를 수 있어요.

화면 시안: 픽클 Design 캔버스 "픽클 마을 생활 앱 화면 예시"

## 실행

필요한 것: Flutter 3.47 이상(Dart 3.13 이상), Android SDK 또는 macOS + Xcode.

이 저장소에는 `lib/`, `test/`, `assets/`만 있고 `android/`·`ios/` 폴더는 아직 없어요. 처음 한 번 만들어 주세요.

```bash
flutter create . --project-name where_to_go_pick --org io.github.mjmxxn09 --platforms android,ios
flutter pub get
flutter test
flutter run                     # 예시 데이터 모드
```

`flutter create .`는 이미 있는 파일(`lib/main.dart`, `pubspec.yaml`, `test/widget_test.dart`)을 덮어쓰지 않아요.

### 서버에 연결하기

```bash
cp env/dev.example.json env/dev.json   # env/dev.json은 커밋되지 않아요
flutter run --dart-define-from-file=env/dev.json
```

| 키 | 뜻 |
|---|---|
| `PICKLE_API_BASE_URL` | 픽클 Backend 주소. 비우면 예시 데이터 |
| `LIFE_API_BASE_URL` | 날씨·관광정보 프록시와 여행 기록을 맡을 생활 서버(아직 없음). 비우면 예시 데이터 |
| `APP_VERSION` | 로그인 시 서버에 보내는 앱 버전 |

공공데이터 API 키(기상청·TourAPI)는 **앱에 넣지 않아요**. 생활 서버에만 둬요.

## 폴더 구조

```text
lib/
  app/              앱 셸(하단 4탭), 의존성(AppScope)
  core/
    config/         dart-define 설정
    theme/          픽클 테마 5(바이올렛) 토큰
    auth/           토큰 저장소(보안 저장소)
    network/        API 오류 모델
    pickle/         픽클 /v1 클라이언트·모델·저장소(예시/원격)
    life/           생활 서버 경계(날씨·명소) + 예시 데이터
  features/
    korea_map/      귀여운 대한민국 지도(도 → 시·군·구), 경로 파서
    home/           내 지도
    explore/        여행지 고르기
    trip/           여행·체크인 모델, 컨트롤러, 여행 중 화면
    trip_card/      여행 노트 배치 규칙, 손그림 아이콘, 카드 화면
    walk/           산책(준비 중)
assets/maps/        시·도·시군구 경계(단순화본)
docs/               제품·아키텍처·출시 체크리스트
```

## 문서

- [제품 개요](docs/product.md)
- [아키텍처와 픽클 API 연동](docs/architecture.md)
- [여행 노트 배치 규칙](docs/trip-card.md)
- [출시 전 체크리스트](docs/launch-checklist.md)

## 데이터 출처

- 행정구역 경계: 통계청 SGIS(2018), **공공누리 제1유형**(출처 표시). [southkorea-maps](https://github.com/southkorea/southkorea-maps) 가공본을 다시 단순화했어요. 출시 전 최신 경계로 바꿔야 해요(강원·전북특별자치도, 군위군 대구 편입 등).
- 날씨(예정): 기상청 단기예보 조회서비스
- 명소·맛집(예정): 한국관광공사 TourAPI
