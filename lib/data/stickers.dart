// 스티커 목록 (Expo 앱 src/lib/stickers.ts 에서 옮김)

enum StickerCategory { cat, sparrow, thing, place }

const categoryLabel = {
  StickerCategory.cat: '고양이',
  StickerCategory.sparrow: '참새',
  StickerCategory.thing: '소품',
  StickerCategory.place: '장소',
};

class Sticker {
  const Sticker(this.id, this.name, this.category);
  final String id;
  final String name;
  final StickerCategory category;
  String get asset => 'assets/map/stickers/$id.webp';
}

const stickers = <String, Sticker>{
  'a00': Sticker('a00', '산책 고양이', StickerCategory.cat),
  'a01': Sticker('a01', '앉은 고양이', StickerCategory.cat),
  'a02': Sticker('a02', '빼꼼 고양이', StickerCategory.cat),
  'a03': Sticker('a03', '지도 보는 고양이', StickerCategory.cat),
  'a04': Sticker('a04', '응원 고양이', StickerCategory.cat),
  'a05': Sticker('a05', '참새 1', StickerCategory.sparrow),
  'a06': Sticker('a06', '참새 2', StickerCategory.sparrow),
  'a07': Sticker('a07', '참새 3', StickerCategory.sparrow),
  'a08': Sticker('a08', '참새 4', StickerCategory.sparrow),
  'a09': Sticker('a09', '참새 5', StickerCategory.sparrow),
  'a10': Sticker('a10', '참새 6', StickerCategory.sparrow),
  'a11': Sticker('a11', '꽃', StickerCategory.thing),
  'a12': Sticker('a12', '노을', StickerCategory.thing),
  'a13': Sticker('a13', '커피', StickerCategory.thing),
  'a14': Sticker('a14', '나무', StickerCategory.thing),
  'a15': Sticker('a15', '발자국', StickerCategory.thing),
  'a16': Sticker('a16', '골목 소품 6', StickerCategory.thing),
  'a17': Sticker('a17', '카메라', StickerCategory.thing),
  'a18': Sticker('a18', '벤치', StickerCategory.thing),
  'a19': Sticker('a19', '핀', StickerCategory.thing),
  'a20': Sticker('a20', '도토리', StickerCategory.thing),
  'a21': Sticker('a21', '낮잠 고양이', StickerCategory.cat),
  'b00': Sticker('b00', '카페', StickerCategory.place),
  'b01': Sticker('b01', '빵집', StickerCategory.place),
  'b02': Sticker('b02', '책방', StickerCategory.place),
  'b03': Sticker('b03', '꽃집', StickerCategory.place),
  'b04': Sticker('b04', '정자', StickerCategory.place),
  'b05': Sticker('b05', '골목 풍경 6', StickerCategory.place),
  'b06': Sticker('b06', '골목 풍경 7', StickerCategory.place),
  'b07': Sticker('b07', '골목 풍경 8', StickerCategory.place),
  'b08': Sticker('b08', '골목 풍경 9', StickerCategory.place),
  'b09': Sticker('b09', '골목 풍경 10', StickerCategory.place),
  'b10': Sticker('b10', '골목 풍경 11', StickerCategory.place),
  'b11': Sticker('b11', '골목 풍경 12', StickerCategory.place),
  'b12': Sticker('b12', '골목 풍경 13', StickerCategory.place),
  'b13': Sticker('b13', '골목 풍경 14', StickerCategory.place),
  'b14': Sticker('b14', '골목 풍경 15', StickerCategory.place),
  'b15': Sticker('b15', '골목 풍경 16', StickerCategory.place),
  'b16': Sticker('b16', '골목 풍경 17', StickerCategory.place),
  'b17': Sticker('b17', '골목 풍경 18', StickerCategory.place),
  'b18': Sticker('b18', '골목 풍경 19', StickerCategory.place),
  'b19': Sticker('b19', '골목 풍경 20', StickerCategory.place),
  'c01': Sticker('c01', '골목 참새', StickerCategory.sparrow),
  'c02': Sticker('c02', '참새 8', StickerCategory.sparrow),
  'c03': Sticker('c03', '참새 9', StickerCategory.sparrow),
  'c04': Sticker('c04', '지도 참새', StickerCategory.sparrow),
  'c05': Sticker('c05', '참새 11', StickerCategory.sparrow),
  'c07': Sticker('c07', '참새 12', StickerCategory.sparrow),
  'c08': Sticker('c08', '참새 13', StickerCategory.sparrow),
  'c09': Sticker('c09', '참새 14', StickerCategory.sparrow),
  'c10': Sticker('c10', '참새 15', StickerCategory.sparrow),
  'c11': Sticker('c11', '참새 16', StickerCategory.sparrow),
  'c12': Sticker('c12', '참새 17', StickerCategory.sparrow),
  'c13': Sticker('c13', '깃발 참새', StickerCategory.sparrow),
  'c14': Sticker('c14', '참새와 고양이', StickerCategory.sparrow),
};

Sticker stickerOf(String id) => stickers[id] ?? stickers['a00']!;
