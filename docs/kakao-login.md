# 카카오 로그인 (2026-11-23)

## 지금: Supabase Auth로 바로 (1단계)

"카카오로 시작하기" → 브라우저(안드로이드 Custom Tabs, iOS 로그인 시트)에서 카카오 로그인 → 앱으로 돌아와 Supabase 계정 세션.
픽클 서버 없이 된다. 같은 카카오 계정이면 다른 폰에서도 같은 기록.

- 흐름(PKCE): `/auth/v1/authorize?provider=kakao&redirect_to=wheretogopick://login-callback&code_challenge=…`
  → `wheretogopick://login-callback?code=…` → `POST /auth/v1/token?grant_type=pkce {auth_code, code_verifier}`.
  코드: `CloudSession.signInWithKakao`, 브라우저는 `lib/core/cloud/oauth_browser.dart`(flutter_web_auth_2).
- 세션(refresh token)은 보안 저장소 `supabase.account_refresh.v1`에. 앱을 다시 켜면 시작 화면에서 바로 홈.
  세션이 만료·폐기되면 지우고 게스트(개발용)·폰 저장으로 돌아간다.
- 토큰 순서: 픽클 로그인 → 카카오 세션 → 게스트(픽클 서버 없을 때) → 없음.
- 게스트로 쓰다 카카오로 로그인하면, **폰에 있는 기록은 다음 동기화 때 카카오 계정으로 올라간다**(여행·체크인, 카드 꾸미기는 카드를 열 때).
  게스트 계정에만 있고 이 폰에 없는 기록은 옮겨지지 않는다.
- 웹에서는 아직 안 된다(안내만). 로그아웃 화면은 아직 없다(`CloudSession.signOutAccount`는 있음).

### 처음 한 번 설정 (PC·대시보드)

1. **카카오 디벨로퍼스**(developers.kakao.com) → 내 애플리케이션 → 어디갈지 Pick(장소 검색에 쓰는 그 앱)
   - [카카오 로그인] → [사용 설정] → 상태 **ON**
   - [앱] → [플랫폼 키] → **REST API 키**(장소 검색에 쓰는 그 키)를 눌러 들어가서
     - **카카오 로그인 리다이렉트 URI**: `https://vwgtsqjpemvyhmjvlgoe.supabase.co/auth/v1/callback` → 저장
     - **클라이언트 시크릿**: 코드가 없으면 [코드 생성], 활성화 **ON**(새 키는 기본 ON), 코드를 복사해 2번에서 쓴다
     (2025년 콘솔 개편 전에는 [카카오 로그인] → [보안]에 있던 메뉴)
   - 카카오 로그인 → 동의항목: **닉네임**, **프로필 사진**, **카카오계정(이메일)** 을 켠다.
     Supabase가 이메일을 함께 요청하므로 이메일 항목이 꺼져 있으면 `KOE205` 오류가 난다.
     이메일 항목은 비즈 앱에서만 켤 수 있다 — 앱 설정 → 비즈니스 → **개인 개발자 비즈 앱 전환**(본인인증, 무료) 후 켠다.
2. **Supabase 대시보드** → Authentication
   - Sign In / Providers → **Kakao** 켜기: REST API Key = 앱 키의 REST API 키, Client Secret = 1번에서 만든 코드
   - URL Configuration → **Redirect URLs**에 `wheretogopick://login-callback` 추가
3. **안드로이드**: `android/app/src/main/AndroidManifest.xml`에 콜백 액티비티와 Custom Tabs 질의(PC에 반영해 둠)
   ```xml
   <activity android:name="com.linusu.flutter_web_auth_2.CallbackActivity" android:exported="true">
     <intent-filter android:label="flutter_web_auth_2">
       <action android:name="android.intent.action.VIEW"/>
       <category android:name="android.intent.category.DEFAULT"/>
       <category android:name="android.intent.category.BROWSABLE"/>
       <data android:scheme="wheretogopick"/>
     </intent-filter>
   </activity>
   <!-- <queries> 안 -->
   <intent><action android:name="android.support.customtabs.action.CustomTabsService"/></intent>
   ```
4. `flutter pub get` → `flutter run`

## 나중에: 픽클 계정과 이어 쓰기 (2단계, 픽클 서버가 붙으면)

목표: **이미 픽클에 가입한 사람은 카카오로 들어와도 그 픽클 계정**을 쓴다(새로 가입시키지 않는다).

- 누가 픽클 회원인지는 픽클 서버만 안다 → 카카오 로그인을 픽클 서버로 보내야 한다.
  픽클 서버는 `POST /v1/auth/social/kakao`(카카오 OIDC id_token)를 지원한다 — 이미 가입했으면 그 계정 토큰,
  처음이면 202 가입 티켓(→ `/v1/auth/social/kakao/signup`, 약관 동의 화면 필요). [architecture.md](architecture.md) "카카오 로그인".
- **카카오 회원번호는 카카오 앱마다 다르다.** 픽클 서버는 id_token의 aud(카카오 앱 키)도 본다.
  그래서 2단계에서는 이 앱용 카카오 앱이 아니라 **픽클의 카카오 앱**으로 로그인해야 같은 사람으로 알아본다
  (픽클 카카오 앱에 이 앱의 패키지명·번들 ID를 플랫폼으로 추가 — 픽클 팀·백엔드와 협의).
- 바꿀 곳: "카카오로 시작하기"를 `kakao_flutter_sdk_user`(픽클 카카오 앱 네이티브 키, dart-define) → id_token
  → 픽클 `/v1/auth/social/kakao` → 픽클 토큰 → 기존 `pickle-exchange`로 바꾼다. 이메일 로그인과 같은 길.
- **1단계에서 쌓인 기록 옮기기**:
  - 그 폰에 있는 기록은 픽클 로그인 뒤 첫 동기화에서 픽클 계정으로 저절로 올라간다(폰 우선 저장).
  - 다른 폰에서만 남긴 기록(Supabase 카카오 계정에만 있는 것)은 Edge Function을 하나 더 둔다:
    앱이 **두 토큰(1단계 카카오 세션 + 픽클 교환 토큰)을 함께** 보내면, 둘 다 검증한 뒤 `trips`·`check_ins`·`card_decorations`의
    `user_id`를 카카오 계정 UUID → `pickle:<id>`로 옮긴다. 두 토큰을 다 가진 사람만 옮길 수 있어 남의 기록을 가져갈 수 없다.
  - 옮긴 뒤 1단계 세션은 지운다(`signOutAccount`).
- iOS 출시 때는 Apple 로그인도 같이(가이드라인 4.8).
