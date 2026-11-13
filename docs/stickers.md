# 여행 노트 스티커 만들기 (AI 시안용)

## 현재 상태 (2026-11-13)

- Gemini로 만든 스티커 시트 3장을 잘라 `assets/stickers/`에 34장 저장(512×512 투명 PNG, 흰 스티커 테두리, 256색 압축)
- 장소: 해변 3 · 카페 3 · 문화유산 3 · 시장 3 · 맛집 6(찌개·국수·고기·치킨·맥주·짜장면) · 수산시장 2 · 자연 4(숲·폭포·들판·대나무) · 숙소 4(한옥·호텔·리조트·캠핑) / 이동: 버스·자동차·자전거·비행기·배·발자국
- 유저가 카드 아래 스티커 서랍에서 골라 직접 붙인다(docs/trip-card.md). 서랍 분류·"자동으로 꾸미기" 대응표: `lib/features/trip_card/sticker_book.dart`
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
