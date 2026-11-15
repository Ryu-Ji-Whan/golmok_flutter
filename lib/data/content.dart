// 데모용 고정 데이터 (Expo 앱 src/lib/content.ts 와 같은 내용).
// 서버가 생기면 API 응답으로 바뀌는 부분이다.

class Character {
  const Character(this.id, this.name);
  final String id;
  final String name;
}

const characters = [
  Character('a02', '빼꼼 고양이'),
  Character('a00', '산책 고양이'),
  Character('a04', '응원 고양이'),
  Character('a21', '낮잠 고양이'),
  Character('c01', '골목 참새'),
  Character('c13', '깃발 참새'),
];

enum PackKind { starter, welcome, paid, reward }

class Pack {
  const Pack(this.id, this.name, this.desc, this.kind, this.stickers, {this.howToGet});
  final String id;
  final String name;
  final String desc;
  final PackKind kind;
  final List<String> stickers;
  final String? howToGet;
}

const packs = [
  Pack('starter', '기본 팩', '처음부터 가진 스티커', PackKind.starter,
      ['a00', 'a01', 'a02', 'a04', 'a21', 'c01', 'a11', 'a13', 'a14', 'a15', 'a18', 'a19']),
  Pack('welcome', '환영 팩', '가입 선물', PackKind.welcome, ['c13', 'a20', 'a17']),
  Pack('autumn', '가을 골목 팩', '스티커 8종', PackKind.paid, ['a12', 'b04', 'b05', 'b06', 'b07', 'b08', 'b09', 'b10']),
  Pack('sparrow', '참새 친구 팩', '스티커 6종', PackKind.paid, ['a05', 'a06', 'a07', 'a08', 'a09', 'a10']),
  Pack('cats', '골목 고양이 팩', '스티커 4종', PackKind.paid, ['a03', 'c02', 'c03', 'c05']),
  Pack('leader', '동네 대장 한정', '리더보드 3위 안 보상', PackKind.reward, ['b11', 'b12'], howToGet: '동네 리더보드 3위 안에 들기'),
  Pack('campaign', '스탬프 투어 한정', '캠페인 완주 보상', PackKind.reward, ['c14', 'c04'], howToGet: '동네 스탬프 투어 5곳 완주'),
];

final starterStickers = packs[0].stickers;
final welcomeStickers = packs[1].stickers;

const areas = [
  '수원시 팔달구 행궁동', '수원시 팔달구 매향동', '수원시 팔달구 신풍동', '수원시 팔달구 남창동', '수원시 장안구 장안동',
  '서울특별시 종로구 익선동', '서울특별시 종로구 서촌', '서울특별시 마포구 연남동', '서울특별시 성동구 성수동', '서울특별시 용산구 해방촌',
];

const takenNicknames = ['골목대장', '관리자', '운영자', '행궁산책러', 'admin'];

class Neighbor {
  const Neighbor(this.name, this.character, this.cells);
  final String name;
  final String character;
  final int cells;
}

/// 리더보드 예시 이웃 (점수 = 이번 주 밝힌 칸 수)
const neighbors = [
  Neighbor('행궁산책러', 'a04', 96),
  Neighbor('참새방앗간', 'c01', 74),
  Neighbor('수원천냥', 'a00', 52),
  Neighbor('깃발참새', 'c13', 31),
  Neighbor('낮잠고양이', 'a21', 18),
];

class FeedPost {
  const FeedPost(this.id, this.author, this.character, this.area, this.ago, this.sticker, this.title, this.body, this.likes, this.comments);
  final String id, author, character, area, ago, sticker, title, body;
  final int likes, comments;
}

const feedPosts = [
  FeedPost('f1', '참새방앗간', 'c01', '행궁동', '1시간 전', 'a18', '해 질 녘 벤치', '여기 앉아 있으면 노란 고양이가 와요.', 128, 12),
  FeedPost('f2', '책방참새', 'c13', '매향동', '어제', 'b02', '골목 끝 작은 책방', '창가 자리는 고양이 차지.', 64, 5),
  FeedPost('f3', '수원천냥', 'a00', '행궁동', '2일 전', 'a11', '담장 위 능소화', '이번 주까지가 제일 예뻐요.', 41, 3),
];

class CampaignSpot {
  const CampaignSpot(this.id, this.name, this.north, this.east);
  final String id, name;
  final double north, east; // 집(처음 위치) 기준 북쪽·동쪽 미터
}

class Campaign {
  static const id = 'autumn-tour';
  static const title = '가을 골목 스탬프 투어';
  static const organizer = 'OO구청 × 골목대장 (데모)';
  static const radiusM = 40.0;
  static const reward = '스탬프 투어 한정 스티커 + 동네 가게 쿠폰';
  static const spots = [
    CampaignSpot('s1', '느티나무 쉼터', 120, 80),
    CampaignSpot('s2', '벽화 골목 계단', -150, 200),
    CampaignSpot('s3', '고양이 벤치', 250, -100),
    CampaignSpot('s4', '징검다리', -80, -220),
    CampaignSpot('s5', '노을 언덕', 320, 260),
  ];
}

class Store {
  const Store(this.id, this.name, this.category, this.sticker, this.north, this.east, this.benefit, {this.isNew = false});
  final String id, name, category, sticker, benefit;
  final double north, east;
  final bool isNew;
}

const stores = [
  Store('cafe', '골목 끝 카페', '카페', 'b00', 60, 140, '방문 인증 시 음료 할인 쿠폰 (데모)'),
  Store('books', '작은 골목 책방', '책방', 'b02', -110, 60, '책 구매 시 한정 책갈피 (데모)', isNew: true),
  Store('flower', '들꽃 한 다발', '꽃집', 'b03', 180, -150, '꽃 한 송이 덤 (데모)'),
  Store('bakery', '아침 빵집', '빵집', 'b01', -200, -60, '오전 방문 시 빵 1개 덤 (데모)', isNew: true),
];
