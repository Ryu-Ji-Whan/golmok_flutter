# 골목대장 (golmok_flutter) — 에이전트 작업 지침

배포할 앱은 이 저장소다. (`~/Downloads/golmok-app`은 예전 Expo 데모, 더 이상 손대지 않음)
전역 규칙(한국어 답변, 비밀값 금지 등)은 `~/.claude/CLAUDE.md`를 따른다.

## 구조

- Flutter 앱 `lib/` — 화면 `lib/screens/`, 데이터 `lib/data/`(db·store·remote·places·geo), 공통 부품 `lib/widgets/`, 색 `lib/theme.dart`
- 지도: `assets/map/cartoon_map.html`(MapLibre + OpenFreeMap 만화풍, WebView) ↔ `lib/widgets/cartoon_map.dart`
- 폰 DB: SQLite `lib/data/db.dart` (지금 2판: explored에 area·at 칸). 상태·동기화 `lib/data/store.dart`
- 서버: Supabase `lib/data/remote.dart`, URL·공개 키 `lib/config.dart`
- 동네 이름: OpenStreetMap Nominatim `lib/data/places.dart` (1초 1회 규칙, 실패 시 30초 쉼)

## 빌드·배포 (이 맥에는 Xcode 없음 → 앱 빌드는 GitHub Actions)

- 맥에 Flutter 3.50.0 stable 설치됨 (`~/development/flutter`, PATH는 `~/.zshrc`). push 전에 `flutter analyze`로 오류 검사 (info는 무시 가능, error 0이어야 함)

- `main`에 push → `.github/workflows/build.yml`이 `flutter create`로 android/ios 생성 → APK·IPA를 Releases에
  - 권한 문구, 로그인 복귀 주소 `golmok://login-callback`, 앱 아이콘(flutter_launcher_icons), 고정 서명 키는 이 워크플로에서 넣는다
- `README.md`·`docs/`·`supabase/`만 바뀌면 앱 빌드 안 함
- `docs/` = GitHub Pages: 디자인 시안 `docs/design/`, 이메일 인증 완료 페이지 `docs/auth/`
- `docs/design/` 바뀌면 `screenshots.yml`이 README용 PNG(`docs/screenshots/`)를 다시 찍는다
- 끝나면 `gh release download`로 IPA를 `~/Downloads/golmok-flutter-unsigned.ipa`에 받아 둔다 (사용자는 Sideloadly로 설치)
- 커밋 메시지는 한국어, 끝에 `Co-Authored-By` 줄

## 서버 (Supabase 프로젝트 `iozoocgrtqzscexbxtox`)

- 처음 `supabase/schema.sql`, 이후 `supabase/migrations/00N_*.sql`을 번호 순서로 SQL Editor에서 실행 (사용자가 직접)
  - 002 아이디 로그인(accounts·username_taken·가입 트리거), 003 걸은 동네 리더보드, 004 거리 기준(area_steps·add_area_meters) — **2026-11-16에 모두 실행 확인됨**
- Edge Function `login-with-username`(아이디→이메일을 서버에서만 찾아 로그인, JWT 확인 끔) — 배포 확인됨
  - 앱은 `functions.invoke` 대신 apikey 헤더만 붙여 직접 호출 (새 키 `sb_publishable_`가 Authorization에서 거절됨)
- 공개 키(`sb_publishable_`)만 앱에. secret·service_role 키, DB 비밀번호는 절대 코드·대화에 넣지 않음
- 서버 상태 확인은 공개 키로 REST/RPC를 불러 본다 (로그인 필요한 함수는 401 permission denied가 정상)
- Supabase 기본 메일 서버라 인증 메일 템플릿 수정 불가(Custom SMTP 필요) — 지금은 기본 영어 메일

## 정해진 것 (바꾸기 전에 사용자와 상의)

- 로그인: **아이디·비밀번호**(이메일 인증 가입) + **카카오**. 구글은 보류(`login.dart`에 주석으로 남김), Apple은 유료 개발자 계정 전까지 숨김
- 카카오: Supabase가 항상 account_email을 요청 → 카카오 앱을 개인 개발자 비즈 앱으로 전환함, 이메일 동의항목 켜기가 필요
- 안개: 걸은 곳 주변 **40m**, 격자 **20m 칸**, 동글동글 구름 모양(캔버스). 예전 50m 칸은 자동 이전(`migrateCells50to20`, marks `meta/cell20`)
- 사람에게 보이는 숫자는 **칸 수가 아니라 걸은 거리**
- 리더보드: **실제로 걸은 동(시·구·동 전체 이름) 기준, 최근 7일 걸은 거리**. 기본은 지금 있는 동네, 내 동네(주 생활 동네)·이번 주 걸은 동네별 순위, 리더보드에 나 숨기기. 동네 대장 보상은 내 동네·4명 이상·3위 안
- 내 동네: 전국 검색 + 현재 위치로 찾기 (고정 목록 없음)
- 다른 사람에게는 경로·좌표를 절대 보여 주지 않는다 (피드는 좌표 빼고, 리더보드는 닉네임·거리만)
- 예시·데모 데이터는 넣지 않는다 (가짜 이웃·글·스탬프 투어·제휴 가게·쿠폰 모두 삭제함)
- 사진: 찍기·앨범, 폰 앱 폴더에 `file:photos/…`로 저장 (서버 업로드는 아직)
- 사진 꾸미기 `lib/screens/photo_edit.dart`: 스티커 20개까지 + 날짜 도장 1개, 완료하면 꾸민 PNG가 원본을 대신함. 갤러리 저장 `gal`(앨범 "골목대장"), 공유 `share_plus`
- 지도 꾸미기 `lib/screens/map_decorate.dart`: 스티커·글씨(12자) 50개까지, 폰 kv `map_deco`에만 저장(서버 동기화 아직, 나만 보임)
- 친구에게 보내기 `lib/screens/share_card.dart`: 기록을 스티커 카드(4:5, 1080×1350 PNG) 한 장으로 공유·앨범 저장. 좌표 없음, 동네 이름·메모는 켜고 끔. 저장·공유 공통 `lib/widgets/image_out.dart`
- 비밀번호 찾기 `lib/screens/forgot_password.dart`: 이메일 입력 → `/auth/v1/recover`를 직접 불러 implicit 링크로 받음 → `docs/auth/index.html`이 `#type=recovery`를 보고 아이디 표시 + 새 비밀번호 설정. redirect는 `emailConfirmedUrl`과 같은 주소(Supabase Redirect URLs에 있어야 함)
- 앱 아이콘: 초록 지도 핀 속 참새 (`assets/icon/`)

## 남은 일

- [ ] 카카오 로그인 실기기 확인 (이메일 동의항목 켠 뒤)
- [ ] 아이디 회원가입 → 인증 → 로그인 실기기 확인, accounts 표에 아이디 들어가는지
- [ ] 사진 꾸미기·지도 꾸미기·비밀번호 찾기 실기기 확인 (2026-11-18 만듦)
- [ ] 사진 서버 저장, 지도 꾸미기 서버 동기화
- [ ] 링크로 공유 (사용자가 원함: 카드 먼저, 사진 서버 저장 뒤 링크 → 웹/앱에서 기록 보기)
- [ ] 실제 앱 스크린샷으로 README 갤러리 교체
