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
];

final starterStickers = packs[0].stickers;
final welcomeStickers = packs[1].stickers;

/// 쓸 수 없는 닉네임 (운영용 이름)
const takenNicknames = ['골목대장', '관리자', '운영자', 'admin'];
