# 골목대장 (golmok_flutter) — 에이전트 작업 지침

배포할 앱은 이 저장소다. (`~/Downloads/golmok-app`은 예전 Expo 데모, 더 이상 손대지 않음)
전역 규칙(한국어 답변, 비밀값 금지 등)은 `~/.claude/CLAUDE.md`를 따른다.

## 구조

- Flutter 앱 `lib/` — 화면 `lib/screens/`, 데이터 `lib/data/`(db·store·remote·places·geo), 공통 부품 `lib/widgets/`, 색 `lib/theme.dart`
- 지도: `assets/map/cartoon_map.html`(MapLibre + OpenFreeMap 만화풍, WebView) ↔ `lib/widgets/cartoon_map.dart`
- 폰 DB: SQLite `lib/data/db.dart` (지금 3판: 2판 explored에 area·at 칸, 3판 spots.from_name). 상태·동기화 `lib/data/store.dart`
- 서버: Supabase `lib/data/remote.dart`, URL·공개 키 `lib/config.dart`
- 동네 이름: OpenStreetMap Nominatim `lib/data/places.dart` (1초 1회 규칙, 실패 시 30초 쉼)

## 빌드·배포 (이 맥에는 Xcode 없음 → 앱 빌드는 GitHub Actions)

- 맥에 Flutter 3.50.0 stable 설치됨 (`~/development/flutter`, PATH는 `~/.zshrc`). push 전에 `flutter analyze`로 오류 검사 (info는 무시 가능, error 0이어야 함)

- `main`에 push → `.github/workflows/build.yml`이 `flutter create`로 android/ios 생성 → APK·IPA를 Releases에
  - 권한 문구, 로그인 복귀 주소 `golmok://login-callback`, 앱 아이콘(flutter_launcher_icons), 고정 서명 키는 이 워크플로에서 넣는다
- `README.md`·`docs/`·`supabase/`만 바뀌면 앱 빌드 안 함
- `docs/` = GitHub Pages: 디자인 시안 `docs/design/`, 이메일 인증 완료 페이지 `docs/auth/`
  - 시안 화면 `docs/design/screens/*.dc.html`: 예전 것은 디자인 도구가 묶은 큰 파일, 2026-11-19에 더한 6개(Friends·FriendAdd·SendSticker·GiftReceive·MapTheme·PickPlace)는 손으로 쓴 HTML + `screens/app.css`
  - `docs/design/map/index.html`은 앱 지도(`assets/map/cartoon_map.html`)를 그대로 복사한 것 → 지도를 고치면 같이 복사. 테마 미리보기 그림 `docs/design/img/theme-*.jpg`
- `docs/design/` 바뀌면 `screenshots.yml`이 README용 PNG(`docs/screenshots/`)를 다시 찍는다
- 끝나면 `gh release download`로 IPA를 `~/Downloads/golmok-flutter-unsigned.ipa`에 받아 둔다 (사용자는 Sideloadly로 설치)
- 커밋 메시지는 한국어, 끝에 `Co-Authored-By` 줄

## 서버 (Supabase 프로젝트 `iozoocgrtqzscexbxtox`)

- 처음 `supabase/schema.sql`, 이후 `supabase/migrations/00N_*.sql`을 번호 순서로 SQL Editor에서 실행 (사용자가 직접)
  - 002 아이디 로그인(accounts·username_taken·가입 트리거), 003 걸은 동네 리더보드, 004 거리 기준(area_steps·add_area_meters) — **2026-11-16에 모두 실행 확인됨**
  - 005 친구·스티커 보내기(friend_links·gifts·my_friends·my_gifts·저장소 버킷 gifts·spots.from_name) — 2026-11-19 실행 확인됨
  - 006 친구 방(rooms·room_members·room_spots, create_room·join_room·invite_to_room·room_today 등) — 2026-11-26 만듦, **사용자 실행 확인 전**
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
- 다른 사람에게는 경로·좌표를 절대 보여 주지 않는다 (피드는 좌표 빼고, 리더보드는 닉네임·거리만). 예외: 내가 친구에게 직접 보낸 기록 한 곳의 위치, 내가 들어간 친구 방 사람들에게 오늘 경로·방에 올린 스티커
- 예시·데모 데이터는 넣지 않는다 (가짜 이웃·글·스탬프 투어·제휴 가게·쿠폰 모두 삭제함)
- 사진: 찍기·앨범, 폰 앱 폴더에 `file:photos/…`로 저장 (서버 업로드는 아직)
- 사진 꾸미기 `lib/screens/photo_edit.dart`: 스티커 20개까지 + 날짜 도장 1개, 완료하면 꾸민 PNG가 원본을 대신함. 갤러리 저장 `gal`(앨범 "골목대장"), 공유 `share_plus`
- 지도 꾸미기는 2026-11-26 사용자 결정으로 뺌 (화면·MapDeco·store 코드 삭제. 폰에 남은 kv `map_deco`는 안 씀, 지도 html의 setDecos는 안 쓰는 채로 남김)
- 내 지도 (2026-11-26): 지난 산책 경로를 전부 그리지 않고 **고른 산책 하나만** 경로 표시(`setPath`) + 경로 전체로 확대(`fitTo`). 기록한 장소를 누르면 그 자리 확대 + 콩, 한 번 더 누르거나 › 누르면 자세히
- 친구 방 (2026-11-26 사용자 결정): `lib/screens/rooms.dart`, `lib/data/rooms.dart`, 서버 006. 동네 탭 = [친구 방 | 리더보드]
  - 들어가기: 6자리 코드 + 골목대장 친구 바로 초대(수락 필요). 한 방 최대 10명
  - 방 사람끼리만 **오늘(한국 시간 0시부터) 끝낸 산책 경로**가 자동으로 보임(서버 walks 표에서 함수로 읽음), 방마다 내 경로 숨기기. 방 지도는 안개 없음, 사람마다 색(`setTracks`)
  - 방에 내 스티커 올리기(위치·스티커·제목·메모, 사진은 아직 안 감). 나가면 내가 올린 스티커도 지움
- 친구에게 보내기 `lib/screens/share_card.dart`: 기록을 스티커 카드(4:5, 1080×1350 PNG) 한 장으로 공유·앨범 저장. 좌표 없음, 동네 이름·메모는 켜고 끔. 저장·공유 공통 `lib/widgets/image_out.dart`
- 비밀번호 찾기 `lib/screens/forgot_password.dart`: 이메일 입력 → `/auth/v1/recover`를 직접 불러 implicit 링크로 받음 → `docs/auth/index.html`이 `#type=recovery`를 보고 아이디 표시 + 새 비밀번호 설정. redirect는 `emailConfirmedUrl`과 같은 주소(Supabase Redirect URLs에 있어야 함)
- 친구·스티커 보내기 (2026-11-19 사용자 결정): `friends.dart`, `send_sticker.dart`, `gift_receive.dart`, 서버 005
  - 친구 추가는 아이디 또는 닉네임 **정확히** 입력(카카오 가입자는 아이디가 없어서 닉네임) → 요청 → 수락
  - 보내기: 기록 한 곳의 정확한 위치·스티커·제목·메모·사진 (경로는 절대 안 감). 보낼 때 스티커가 슝 날아가는 효과
  - 받기: 받은 사람 지도에서 스티커가 날아와 콩 붙음(`window.stamp(id, true)`), 받은 순간부터 받은 사람 기록(`spots.from_name`, 나만 보기). 보낸 사람이 원래 기록을 지워도 남고, 받은 사람이 마음대로 지울 수 있음
  - 받기·거절하면 서버 gifts 줄과 사진을 지운다. 받은 스티커·친구 요청은 앱 켤 때·다시 열 때·1분마다 확인(`refreshInbox`)
- 내 기록 저장하면 지도에서 스티커가 도장처럼 콩 찍힘 (`window.stamp`, 폰 진동)
- 이미 밝힌 곳에 스티커 붙이기 (2026-11-19): 산책·내 지도에서 지도 빈 곳을 누르면 그 칸이 밝힌 칸(`cellOf`)일 때만 "이 자리에 붙일까요?" → `RecordScreen(at:)`. 안개 낀 곳은 안내만
  - 지도 표시(Marker) 바깥 요소에 CSS transform 애니메이션을 걸면 위치가 틀어진다 → 움직임은 안쪽 요소에만
- 지도 테마 7가지 (기본 pastel) = **앱 테마**: 테마를 바꾸면 앱 전체 색·제목 글씨체도 바뀜 (`lib/theme.dart`의 `palettes`, 이름은 지도 THEMES와 같게)
  - 색은 `C.forest` 등 getter라서 **const 자리에 못 씀**. `C.white`는 카드 바탕이자 주 색 위 글자(밤 테마에선 남색). 늘 어두운 화면(사진 꾸미기)은 `Colors.white`
  - 테마를 바꾸면 `C.use` + `reassembleApplication()`으로 모든 화면 다시 그림(상태 유지). 제목 글씨체는 Jua 말고는 google_fonts로 처음 쓸 때 받음
  - 2026-11-19 사용자 의견: 테두리가 지도를 많이 가림 → 얇게, 보물 지도 탄 구멍 뺌
- 지도 테마: `cartoon_map.html`의 `THEMES` + `lib/widgets/cartoon_map.dart`의 `mapThemes` (이름 맞출 것). 폰 kv `map_theme`
  - 테마마다 색·선·무늬·글씨체(구글 글꼴, 한글 조각 미리 받음)·종이 질감·테두리·움직임이 다름. 테마를 바꾸면 지도를 새로 만들고 안개·경로·스티커·꾸미기를 다시 올림
  - 지도 스타일의 오솔길 층 이름이 'path'라서 내 산책 경로 층은 'route'(같은 이름이면 경로가 안 그려지던 버그 고침)
- 앱 아이콘: 초록 지도 핀 속 참새 (`assets/icon/`)

## 남은 일

- [ ] 카카오 로그인 실기기 확인 (이메일 동의항목 켠 뒤)
- [ ] 아이디 회원가입 → 인증 → 로그인 실기기 확인, accounts 표에 아이디 들어가는지
- [ ] 사진 꾸미기·비밀번호 찾기 실기기 확인 (2026-11-18 만듦)
- [ ] 사진 서버 저장
- [ ] 006 SQL 실행 → 친구 방(만들기·코드·초대·오늘 경로·스티커 올리기) 실기기 확인 (2026-11-26 만듦)
- [ ] 005 SQL 실행 확인 → 친구 추가·스티커 보내기·받기 실기기 확인 (2026-11-19 만듦)
- [ ] 지도 테마 7가지·콩 찍기 효과 실기기 확인 (특히 iOS 글씨체 로딩, 꽃잎 움직임 배터리). 레트로는 저해상도로 그리면 글씨가 깨져서 선명하게 그리고 격자·각진 길로 바꿈
- [ ] 링크로 공유 (카드 먼저 했음, 사진 서버 저장 뒤 링크 → 웹/앱에서 기록 보기)
- [ ] 실제 앱 스크린샷으로 README 갤러리 교체
