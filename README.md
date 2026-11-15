# 골목대장 (Flutter 버전)

디자인 보드 「골목대장 앱 화면 시안」의 화면 흐름을 Flutter로 옮긴 데모 앱이에요.
지도는 만화풍(C안), 기록은 폰 안 데이터베이스(SQLite)에 저장돼요.

## 들어 있는 화면

| 디자인 보드 | 파일 |
|---|---|
| ①-1 온보딩 | `lib/screens/onboarding.dart` |
| ①-2 로그인, ①-A 진행 상태 | `lib/screens/login.dart` |
| ①-B~H 약관·닉네임·캐릭터·위치·동네·완료 | `lib/screens/signup.dart` |
| ①-4 산책 시작, ②-1 산책 중 지도, 산책 요약 | `lib/screens/walk.dart` |
| ②-2 스티커 붙여 기록, ②-3a 사진 넣기 | `lib/screens/record.dart` |
| ③-1 저장된 기록, ④-1 기록 공유하기 | `lib/screens/spot_detail.dart` |
| ③-2 내 지도 | `lib/screens/mymap.dart` |
| ④-2 골목 피드 | `lib/screens/feed.dart` |
| ⑤ 동네 리더보드 | `lib/screens/town.dart` |
| ⑥ 스티커 상점 | `lib/screens/shop.dart` |
| ⑦-1 스탬프 투어 | `lib/screens/campaign.dart` |
| ⑦-2 제휴 가게·쿠폰 | `lib/screens/stores.dart` |
| 부록 프로필·설정 | `lib/screens/profile.dart` |

아직 없는 것: ②-3 사진 꾸미기(스티커 여러 개 붙이기·갤러리 저장), ②-4 지도 꾸미기, 실제 카메라/앨범, 실제 소셜 로그인.

## 구조

- `assets/map/cartoon_map.html` — 만화풍 지도. MapLibre GL JS + OpenFreeMap(무료, 키 없음). 안개·경로·스티커 표시 포함
- `lib/widgets/cartoon_map.dart` — 위 지도를 WebView로 띄우고 Flutter에서 명령을 보내는 위젯
- `lib/data/db.dart` — 폰 안 데이터베이스(표: profile, walks, walk_points, spots, explored, marks, coupons, kv)
- `lib/data/store.dart` — 앱 상태 + 위치 추적. 바뀌면 바로 DB에 저장
- `supabase/schema.sql` — 나중에 서버를 붙일 때 쓸 같은 구조의 서버 DB 초안

## 빌드

`android/`, `ios/` 폴더는 저장소에 없고 GitHub Actions가 빌드할 때 만들어요 (`.github/workflows/build.yml`).
GitHub에 올리면 Releases에 `golmok-flutter.apk`, `golmok-flutter-unsigned.ipa`가 올라와요.

내 컴퓨터에서 돌려 보려면 Flutter SDK를 설치한 뒤:

```bash
flutter create --platforms=android,ios --org kr.golmok --project-name golmok_flutter .
rm test/widget_test.dart
flutter run
```

(위치 권한 문구는 workflow 파일의 "Generate native" 단계를 참고해 AndroidManifest.xml, Info.plist에 넣어 주세요.)

## 책상에서 시험하기

산책을 시작한 뒤 **데모 걷기**를 켜면 1초마다 8m씩 걷는 흉내를 내서, 안개가 걷히고 경로가 그려지는 걸 볼 수 있어요.
