# 스플래시 캐릭터 이미지

시작 화면(스플래시·로그인)에 나오는 픽클 친구 얼굴 6장을 이 폴더에 둔다.

- 픽클(VoteLock) 회사 캐릭터라 **공개 저장소에는 올리지 않는다**. `*.png`는 `.gitignore`에 들어 있다.
- 파일이 없으면 앱은 이름이 적힌 동그라미로 대신 보여 준다.

| 파일 | 캐릭터 |
|---|---|
| `face_pickle.png` | 픽클이 |
| `face_bori.png` | 보리 |
| `face_moa.png` | 모아 |
| `face_tori.png` | 토리 |
| `face_yieldy.png` | 일디 |
| `face_rhythmi.png` | 리듬이 |

원본: 픽클 저장소 `web/assets/characters/*-master-*-384.webp`에서 머리~가슴 위까지 잘라 배경을 투명하게 한 PNG.
모아 꼬리, 일디 흔드는 날개는 지웠다. 크기·위치 값은 `lib/features/splash/splash_character.dart`.
