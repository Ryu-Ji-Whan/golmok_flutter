import 'package:flutter_test/flutter_test.dart';
import 'package:golmok_flutter/data/geo.dart';

void main() {
  test('100m 떨어진 점 사이 거리는 약 100m', () {
    final b = offset(defaultCenter, 100, 0);
    expect(distanceM(defaultCenter, b), closeTo(100, 1));
  });

  test('한 지점 주변 100m 안의 칸을 밝힌다', () {
    final cells = cellsAround(defaultCenter);
    expect(cells.length, greaterThan(9));
    expect(cells.toSet().length, cells.length);
  });

  test('거리 표시', () {
    expect(formatDistance(850), '850m');
    expect(formatDistance(1530), '1.5km');
  });
}
