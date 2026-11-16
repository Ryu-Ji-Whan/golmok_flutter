import 'package:flutter_test/flutter_test.dart';
import 'package:golmok_flutter/data/geo.dart';

void main() {
  test('100m 떨어진 점 사이 거리는 약 100m', () {
    final b = offset(defaultCenter, 100, 0);
    expect(distanceM(defaultCenter, b), closeTo(100, 1));
  });

  test('걸은 지점 주변 칸을 밝힌다 (40m 반경, 20m 칸)', () {
    final cells = cellsAround(defaultCenter);
    expect(cells.length, inInclusiveRange(5, 16));
    expect(cells.toSet().length, cells.length);
  });

  test('예전 50m 칸 하나는 20m 칸 여러 개로 옮겨진다', () {
    final moved = migrateCells50to20(['5000:3000']);
    expect(moved.length, inInclusiveRange(4, 12));
  });

  test('거리 표시', () {
    expect(formatDistance(850), '850m');
    expect(formatDistance(1530), '1.5km');
  });
}
