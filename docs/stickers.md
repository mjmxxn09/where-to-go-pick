# 여행 노트 스티커 만들기 (AI 시안용)

## 현재 상태 (2026-11-13)

- Gemini로 만든 스티커 시트 3장을 잘라 `assets/stickers/`에 34장 저장(512×512 투명 PNG, 흰 스티커 테두리, 256색 압축)
- 장소: 해변 3 · 카페 3 · 문화유산 3 · 시장 3 · 맛집 6(찌개·국수·고기·치킨·맥주·짜장면) · 수산시장 2 · 자연 4(숲·폭포·들판·대나무) · 숙소 4(한옥·호텔·리조트·캠핑) / 이동: 버스·자동차·자전거·비행기·배·발자국
- 유저가 카드 아래 스티커 서랍에서 골라 직접 붙인다(docs/trip-card.md). 서랍 분류: `lib/features/trip_card/sticker_book.dart`, "자동으로 꾸미기"의 이름→스티커 대응표: `place_sticker_match.dart`
- 파일이 없는 스티커는 서랍에 나오지 않는다
- **출시 전**: Gemini 이용 약관의 상업적 이용 조건 확인. 'CAFÉ', '시장' 글자가 들어간 그림이 있음

여행 카드의 반원 안쪽 그림(장소 종류별 8장)을 이미지 생성 AI로 먼저 시안을 뽑기 위한 프롬프트 모음.
마음에 드는 스타일이 나오면 디자이너·일러스트레이터에게 정식 제작을 맡긴다.

## 규격

- 투명 배경 PNG, 512×512 (정사각형)
- 파일 이름: `place_beach.png` 같은 형식, 위치 `assets/stickers/`
- 8장의 그림체가 같아야 한다. 아래 **공통 스타일 문장을 매번 그대로** 앞에 붙인다.

## 1. 공통 스타일 (둘 중 하나를 골라 8장 모두 같은 것 사용)

**A. 손그림 수채화 스티커** — 모눈종이 여행 노트 느낌

```text
A single cute hand-drawn sticker illustration, soft watercolor and colored-pencil texture,
thin dark purple outline, pastel colors (soft pink, butter yellow, mint, sky blue, lilac),
thick white sticker border around the whole shape, centered, plain white background,
simple shapes that stay readable when small, no text, no letters, no logo, square 1:1.
```

**B. 픽클 클레이 스타일** — 픽클 캐릭터와 같은 3D 점토 느낌

```text
A single cute 3D clay miniature object, soft matte plasticine texture, rounded chunky shapes,
pastel colors (soft pink, butter yellow, mint, sky blue, lilac), soft studio lighting,
very light contact shadow, centered, isolated on plain white background,
no text, no letters, no logo, square 1:1.
```

## 2. 장면 (공통 스타일 문장 뒤에 이어 붙이기)

| 파일 | 장면 문장 |
|---|---|
| `place_beach.png` | `Subject: a striped beach parasol standing in a small patch of sand, with two tiny waves at its foot.` |
| `place_cafe.png` | `Subject: a steaming coffee cup on a small saucer, with one round cookie beside it.` |
| `place_heritage.png` | `Subject: a tiny traditional Korean hanok house with a gently curved dark tiled roof, with a few stalks of black bamboo beside it.` |
| `place_market.png` | `Subject: a tiny traditional market stall with a scalloped striped awning and a row of round golden pancakes on the counter.` |
| `place_food.png` | `Subject: a small bowl of Korean soft tofu stew with white tofu cubes and gentle steam, wooden chopsticks resting on the side.` |
| `place_seafood.png` | `Subject: a cheerful blue fish lying on crushed ice in a small woven basket.` |
| `place_nature.png` | `Subject: two small pine trees on a round grassy hill.` |
| `place_other.png` | `Subject: a round map pin with a little star on top.` |

뒤에 붙이면 좋은 금지 문장(서비스가 지원하면 negative prompt 칸에):

```text
no text, no watermark, no photo realism, no background scenery, no people, no frame, no multiple objects
```

## 3. 그림체를 맞추는 요령

- 8장을 **한 대화(세션) 안에서 이어서** 만들고, 두 번째부터는 "앞 그림과 같은 그림체로"를 덧붙인다.
- 시드(seed)를 고정할 수 있는 서비스면 고정한다.
- 또는 한 번에 "a sticker sheet of 8 items in a 4×2 grid, same style"로 만든 뒤 잘라 쓰면 그림체가 가장 잘 맞는다.
- 특정 작가·작품 이름이나 참고 이미지를 넣어 따라 그리게 하지 않는다(저작권).

## 4. 후처리

1. 배경 제거(투명 PNG) — 흰 스티커 테두리는 남긴다
2. 512×512 정사각형 캔버스 가운데 맞춤, 여백 약 6%
3. 위 파일 이름으로 `assets/stickers/`에 저장

## 5. 쓰기 전에 확인

- 사용한 AI 서비스의 **상업적 이용 약관**(앱 배포 가능 여부, 출처 표기 의무)
- 결과물에 실제 상호·로고·글자가 섞여 들어가지 않았는지

## 투표 스티커 (2026-11-17)

- `vote_pick`(한 표 핀), `vote_vs`(VS), `vote_box`(투표함) — 직접 그린 SVG를 512px PNG로 옮긴 것(외부 그림 아님).
- 한 표 핀을 장소 막대 옆(90px 안)에 붙이면 그 장소가 투표 후보가 된다. 2곳 이상이면 공유 버튼이 "투표로 공유"로 바뀐다.

## 직접 그린 장소 스티커 10종 (2026-11-20)

2025~2026 한국관광 100선(세부 154곳)을 분류해 보니 절반 넘게(81곳) 어울리는 스티커가 없어 직접 그려 더했다.
SVG로 그리고(`tool`: rsvg) 색연필 결·흰 칼선을 입혀 512px PNG로 옮김. 외부 그림 아님.

| 파일 | 서랍 칸(장소 종류) | 이름 키워드 예 | 100선에서 걸리는 곳 |
|---|---|---|---|
| place_nature_mountain | 자연 | 국립공원·오름·일출봉, 이름 끝 …산/…봉 | 14 |
| place_leisure_themepark | 놀거리(새 종류) | 놀이공원·테마파크·에버랜드·루지·아쿠아리움 | 14 |
| place_culture_street | 문화시설(새 종류) | 골목·벽화·○○거리·문화마을·황리단길 | 10 |
| place_culture_museum | 문화시설 | 박물관·미술관·과학관·기념관 | 9 |
| place_leisure_cablecar | 놀거리 | 케이블카·모노레일·레일바이크 | 7 |
| place_leisure_tower | 놀거리 | 타워·전망대·스카이워크 | 7 |
| place_heritage_tomb | 문화유산 | 왕릉·고분·첨성대·유적 | 6 |
| place_nature_bridge | 자연 | 출렁다리·잔도·부채길·주상절리 | 5 |
| place_nature_lake | 자연 | 호수·늪·습지·두물머리 | 4 |
| place_beach_lighthouse | 해변 | 등대·곶·태종대·대왕암 | 해안 바위 명소 |
| place_nature_river (11-20 추가) | 자연 | 한강·북한강·낙동강 등 강 이름, 강변·강가·하천, 이름 끝 …강 | 한강공원 11곳 등 |

- 장소 종류에 `leisure`(놀거리)·`culture`(문화시설)를 더했다. TourAPI 분류의 체험·레포츠, 문화시설에 대응.
- 이름 매칭에서 "공원·파크·거리·숲·광장"은 흔한 말로 보고 또렷한 말이 없을 때만 쓴다(예: 대왕암공원 → 등대).
- 바꾼 뒤 100선 154곳 중 133곳이 이름만으로 스티커가 정해진다(나머지는 종류 대표 그림).
- 강: '강' 한 글자는 강릉·강원·강화가 걸려 쓰지 않는다. "태화강 국가정원"은 정원(들판), "여의도한강공원"은 강.

## 명소 전용 스티커 15종 (2026-11-20)

유명 명소는 종류별 그림 대신 그곳만의 손그림을 붙인다. 사진을 고쳐 쓰지 않고 직접 그렸다(SVG → 색연필 결·흰 칼선 → 512px PNG).
서랍의 **명소** 칸에 모여 있고, "자동으로 꾸미기"는 이름이 맞으면 다른 규칙보다 먼저 쓴다(`landmarkKeywords`).

| 파일 | 그림 | 이름 키워드 |
|---|---|---|
| landmark_namsan_tower | 남산 위 타워, 성곽, 사랑의 자물쇠 하트 | 남산서울타워·남산타워·N서울타워 |
| landmark_gwanghwamun | 북악산 앞 광화문(세 홍예문, 2층 지붕) | 경복궁·광화문 |
| landmark_suwon_hwaseong | 성곽과 성문, 깃발 | 수원화성·화성행궁·팔달문·장안문·화서문·방화수류정 |
| landmark_donggung_wolji | 밤 연못에 비친 누각, 달 | 동궁과 월지·안압지 |
| landmark_dabotap | 다보탑 + 단풍 가지 | 불국사·다보탑·석가탑 |
| landmark_seongsan | 일출과 분화구 봉우리, 유채꽃 | 성산일출봉 |
| landmark_dokdo | 동도·서도와 태극기, 갈매기 | 독도 |
| landmark_gwangan_bridge | 현수교와 해변 파라솔 | 광안대교·광안리 |
| landmark_haedong_yonggungsa | 바닷가 바위 위 절집 | 해동용궁사 |
| landmark_gamcheon | 언덕의 알록달록 집들 | 감천문화마을 |
| landmark_hahoe_mask | 웃는 양반탈 | 하회마을·하회탈·하회 |
| landmark_namiseom | 단풍 든 메타세쿼이아 길과 두 사람 | 남이섬 |
| landmark_suncheonman | 갈대밭과 굽은 나무 데크길, 새 | 순천만 |
| landmark_dodamsambong | 강 위 세 바위 봉우리와 정자 | 도담삼봉 |
| landmark_daegwallyeong | 풍력발전기와 양떼, 울타리 | 대관령·양떼목장 |

- '남산', '감천'처럼 짧은 말은 다른 곳(경주 남산 등)도 걸려서 넣지 않았다.

두 번째 묶음 16종(같은 날): 순천만 데크길·감천 집 배치도 다시 그림.

| 파일 | 그림 | 이름 키워드 |
|---|---|---|
| landmark_jeonju_hanok | 한옥 지붕 마을 + 오목대 정자 + 은행나무 | 전주한옥마을·경기전·오목대 (완주 오성한옥마을은 일반 한옥) |
| landmark_pohang_spacewalk | 한 바퀴 도는 철제 산책로 | 스페이스워크 |
| landmark_ulsanbawi | 둥근 화강암 봉우리 + 소나무 | 울산바위·설악산·외설악 |
| landmark_yeosu_night | 밤바다 돌산대교 조명 + 빨간 등대 | 여수밤바다·돌산대교·하멜등대·여수엑스포 |
| landmark_chinatown | 빨간 패루 + 홍등 | 차이나타운 |
| landmark_dolhareubang | 돌하르방 + 귤 | 돌하르방·올레길·제주올레 |
| landmark_hallasan | 눈 덮인 백록담 + 구상나무 | 한라산·백록담·영실·성판악 |
| landmark_udo | 우도봉 등대 + 옥빛 바다 + 흰 모래 | 우도 |
| landmark_cheomseongdae | 첨성대 + 핑크뮬리 + 달 | 첨성대 |
| landmark_mancheonha | 세 갈래 전망대 | 만천하 |
| landmark_lotte_tower | 롯데월드타워 + 강변 건물 | 롯데월드타워·서울스카이 |
| landmark_boseong_tea | 굽이치는 녹차밭 고랑 + 삼나무 | 보성녹차·녹차밭·대한다원·차밭 |
| landmark_jinhae_cherry | 벚꽃 터널 + 빨간 다리 | 여좌천·군항제·경화역·벚꽃 |
| landmark_jeongdongjin | 해돋이 + 바닷가 기차 | 정동진 |
| landmark_gyeongpodae | 밤 호수의 달들 + 경포대 정자 | 경포대·경포호 (경포해변은 해변 그대로) |
| landmark_ojukheon | 한옥 대문 + 검은 대나무(오죽) | 오죽헌 |


세 번째 묶음 14종(같은 날):

| 파일 | 그림 | 이름 키워드 |
|---|---|---|
| landmark_dongpirang | 천사 날개 벽화 + 항구 배 | 동피랑 |
| landmark_hwangnidan | 한옥 지붕 가게 거리 + 홍등 | 황리단길 |
| landmark_haeundae_capsule | 바닷가 레일 위 알록달록 캡슐 | 스카이캡슐·해변열차·블루라인파크 |
| landmark_kkotji | 노을 속 두 바위섬 | 꽃지·할미할아비 (꽃지해수욕장도 이 그림) |
| landmark_bukchon | 비탈 한옥 골목 + 멀리 남산타워 | 북촌 |
| landmark_daereungwon | 두 고분 사이 목련 한 그루 | 대릉원·천마총 |
| landmark_woljeonggyo | 불 켜진 지붕 다리(밤) | 월정교 |
| landmark_hyeopjae | 옥빛 바다·비양도·현무암 | 협재·금능 |
| landmark_abai_gaetbae | 줄 당겨 건너는 갯배 | 아바이마을·갯배 |
| landmark_banpo_rainbow | 다리에서 쏟아지는 무지개 분수(밤) | 반포대교·달빛무지개·반포한강공원·세빛섬 |
| landmark_german_village | 주황 지붕 흰 집들 + 바다 | 독일마을 |
| landmark_windy_hill | 언덕 위 풍차 | 바람의 언덕 |
| landmark_gwangmyeong_cave | 불빛 걸린 동굴 입구 | 광명동굴·동굴(모든 동굴) |
| landmark_imjingak | 바람개비 언덕 + 리본 울타리 | 임진각·평화누리·DMZ |

- 명소 스티커는 모두 45종. 다음 후보: 서울 청계천, 수원 행궁동, 춘천 소양강 스카이워크, 제주 섭지코지, 부산 흰여울문화마을, 경주 불국사 단풍길.
