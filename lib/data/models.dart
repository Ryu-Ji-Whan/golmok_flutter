import 'geo.dart';

/// 로그인 방법: kakao / apple / google / guest(둘러보기)
class Profile {
  Profile({
    required this.nickname,
    required this.characterId,
    required this.areaName,
    required this.provider,
    required this.marketing,
    required this.joinedAt,
    this.loggedIn = true,
  });

  final String nickname;
  final String characterId;
  final String areaName;
  final String provider;
  final bool marketing;
  final DateTime joinedAt;

  /// false = 로그아웃 상태. 같은 방법으로 다시 로그인하면 이 계정으로 돌아온다.
  final bool loggedIn;

  bool get isGuest => provider == 'guest';

  Profile copyWith({String? nickname, String? characterId, String? areaName, bool? loggedIn}) => Profile(
        nickname: nickname ?? this.nickname,
        characterId: characterId ?? this.characterId,
        areaName: areaName ?? this.areaName,
        provider: provider,
        marketing: marketing,
        joinedAt: joinedAt,
        loggedIn: loggedIn ?? this.loggedIn,
      );

  Map<String, Object?> toRow() => {
        'id': 1,
        'nickname': nickname,
        'character_id': characterId,
        'area_name': areaName,
        'provider': provider,
        'marketing': marketing ? 1 : 0,
        'joined_at': joinedAt.millisecondsSinceEpoch,
        'logged_in': loggedIn ? 1 : 0,
      };

  static Profile fromRow(Map<String, Object?> r) => Profile(
        nickname: r['nickname'] as String,
        characterId: r['character_id'] as String,
        areaName: r['area_name'] as String,
        provider: r['provider'] as String,
        marketing: (r['marketing'] as int) == 1,
        joinedAt: DateTime.fromMillisecondsSinceEpoch(r['joined_at'] as int),
        loggedIn: (r['logged_in'] as int) == 1,
      );
}

class Walk {
  Walk({required this.id, required this.startedAt, this.endedAt, this.distanceM = 0, this.newCells = 0, List<LatLng>? path})
      : path = path ?? [];

  final String id;
  final DateTime startedAt;
  DateTime? endedAt;
  double distanceM;
  int newCells;
  final List<LatLng> path;

  Duration get duration => (endedAt ?? DateTime.now()).difference(startedAt);

  Map<String, Object?> toRow() => {
        'id': id,
        'started_at': startedAt.millisecondsSinceEpoch,
        'ended_at': endedAt?.millisecondsSinceEpoch,
        'distance_m': distanceM,
        'new_cells': newCells,
      };

  static Walk fromRow(Map<String, Object?> r, List<LatLng> path) => Walk(
        id: r['id'] as String,
        startedAt: DateTime.fromMillisecondsSinceEpoch(r['started_at'] as int),
        endedAt: r['ended_at'] == null ? null : DateTime.fromMillisecondsSinceEpoch(r['ended_at'] as int),
        distanceM: (r['distance_m'] as num).toDouble(),
        newCells: r['new_cells'] as int,
        path: path,
      );
}

enum SpotVisibility { all, friends, me }

const visibilityLabel = {SpotVisibility.all: '전체 공개', SpotVisibility.friends: '친구만', SpotVisibility.me: '나만 보기'};

class Spot {
  Spot({
    required this.id,
    required this.lat,
    required this.lng,
    required this.stickerId,
    required this.title,
    required this.memo,
    required this.createdAt,
    this.walkId,
    this.photo,
    this.visibility = SpotVisibility.all,
    this.shared = false,
  });

  final String id;
  final double lat;
  final double lng;
  final String stickerId;
  final String title;
  final String memo;
  final DateTime createdAt;
  final String? walkId;

  /// 사진 (지금은 앱에 들어 있는 예시 사진 경로만)
  final String? photo;
  final SpotVisibility visibility;

  /// 골목 피드에 공유했는지
  final bool shared;

  LatLng get pos => LatLng(lat, lng);

  /// [clearPhoto]가 true면 사진을 뺀다 (photo: null 만으로는 "그대로 두기"와 구분이 안 되므로)
  Spot copyWith({String? stickerId, String? title, String? memo, SpotVisibility? visibility, bool? shared, String? photo, bool clearPhoto = false}) => Spot(
        id: id,
        lat: lat,
        lng: lng,
        stickerId: stickerId ?? this.stickerId,
        title: title ?? this.title,
        memo: memo ?? this.memo,
        createdAt: createdAt,
        walkId: walkId,
        photo: clearPhoto ? null : (photo ?? this.photo),
        visibility: visibility ?? this.visibility,
        shared: shared ?? this.shared,
      );

  Map<String, Object?> toRow() => {
        'id': id,
        'walk_id': walkId,
        'lat': lat,
        'lng': lng,
        'sticker_id': stickerId,
        'title': title,
        'memo': memo,
        'photo': photo,
        'visibility': visibility.name,
        'shared': shared ? 1 : 0,
        'created_at': createdAt.millisecondsSinceEpoch,
      };

  static Spot fromRow(Map<String, Object?> r) => Spot(
        id: r['id'] as String,
        walkId: r['walk_id'] as String?,
        lat: (r['lat'] as num).toDouble(),
        lng: (r['lng'] as num).toDouble(),
        stickerId: r['sticker_id'] as String,
        title: r['title'] as String,
        memo: r['memo'] as String,
        photo: r['photo'] as String?,
        visibility: SpotVisibility.values.firstWhere((v) => v.name == r['visibility'], orElse: () => SpotVisibility.all),
        shared: (r['shared'] as int) == 1,
        createdAt: DateTime.fromMillisecondsSinceEpoch(r['created_at'] as int),
      );
}

class Coupon {
  Coupon({required this.id, required this.storeId, required this.title, required this.issuedAt, this.usedAt});

  final String id;
  final String storeId;
  final String title;
  final DateTime issuedAt;
  DateTime? usedAt;

  Map<String, Object?> toRow() => {
        'id': id,
        'store_id': storeId,
        'title': title,
        'issued_at': issuedAt.millisecondsSinceEpoch,
        'used_at': usedAt?.millisecondsSinceEpoch,
      };

  static Coupon fromRow(Map<String, Object?> r) => Coupon(
        id: r['id'] as String,
        storeId: r['store_id'] as String,
        title: r['title'] as String,
        issuedAt: DateTime.fromMillisecondsSinceEpoch(r['issued_at'] as int),
        usedAt: r['used_at'] == null ? null : DateTime.fromMillisecondsSinceEpoch(r['used_at'] as int),
      );
}
