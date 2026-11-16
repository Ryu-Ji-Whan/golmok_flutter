import 'dart:math' as math;

/// 위도·경도 한 점
class LatLng {
  const LatLng(this.lat, this.lng);
  final double lat;
  final double lng;

  /// 지도(WebView)에 보낼 때는 [경도, 위도] 순서
  List<double> toLngLat() => [lng, lat];
}

/// 안개 격자 한 칸 크기(미터). 지도 HTML(assets/map/cartoon_map.html)과 같아야 한다.
/// (처음에는 50m였다. 예전 기록은 [migrateCells50to20]으로 옮긴다)
const cellM = 20.0;

/// 걸은 지점에서 대략 이 반경까지 안개가 걷힌다(미터). 골목에서 사람이 실제로 보는 거리.
const revealM = 40.0;

const _mPerDegLat = 111320.0;
// 한국 중부 위도(37.5도) 기준으로 경도 간격을 고정해 어디서나 같은 칸 번호를 갖게 한다.
final _cosRef = math.cos(37.5 * math.pi / 180);
final dLat = cellM / _mPerDegLat;
final dLng = cellM / (_mPerDegLat * _cosRef);

const defaultCenter = LatLng(37.2836, 127.0152); // 수원 행궁동

String cellKey(int i, int j) => '$i:$j';

double distanceM(LatLng a, LatLng b) {
  const r = 6371000.0;
  double rad(double d) => d * math.pi / 180;
  final dLa = rad(b.lat - a.lat);
  final dLo = rad(b.lng - a.lng);
  final s = math.pow(math.sin(dLa / 2), 2) +
      math.cos(rad(a.lat)) * math.cos(rad(b.lat)) * math.pow(math.sin(dLo / 2), 2);
  return 2 * r * math.asin(math.sqrt(s));
}

/// p 주변을 밝힐 칸 키 목록.
/// 지도는 칸마다 반지름 약 0.75~1칸짜리 동그라미로 안개를 걷으므로,
/// 칸 중심이 (radius - 반 칸) 안에 있는 칸만 고르면 보이는 가장자리가 대략 [radius]가 된다.
List<String> cellsAround(LatLng p, [double radius = revealM]) {
  final ci = (p.lat / dLat).floor();
  final cj = (p.lng / dLng).floor();
  final n = (radius / cellM).ceil() + 1;
  final reach = radius - cellM / 2;
  final keys = <String>[cellKey(ci, cj)];
  for (var di = -n; di <= n; di++) {
    for (var dj = -n; dj <= n; dj++) {
      if (di == 0 && dj == 0) continue;
      final center = LatLng((ci + di + 0.5) * dLat, (cj + dj + 0.5) * dLng);
      if (distanceM(p, center) <= reach) keys.add(cellKey(ci + di, cj + dj));
    }
  }
  return keys;
}

/// 예전 50m 칸 기록을 지금 20m 칸으로 옮긴다 (같은 땅을 덮는 작은 칸들로).
Set<String> migrateCells50to20(Iterable<String> oldKeys) {
  const oldM = 50.0;
  final oLat = oldM / _mPerDegLat;
  final oLng = oldM / (_mPerDegLat * _cosRef);
  final out = <String>{};
  for (final k in oldKeys) {
    final parts = k.split(':');
    if (parts.length != 2) continue;
    final i = int.tryParse(parts[0]), j = int.tryParse(parts[1]);
    if (i == null || j == null) continue;
    final a0 = (i * oLat / dLat).floor(), a1 = (((i + 1) * oLat) / dLat - 1e-9).floor();
    final b0 = (j * oLng / dLng).floor(), b1 = (((j + 1) * oLng) / dLng - 1e-9).floor();
    for (var a = a0; a <= a1; a++) {
      for (var b = b0; b <= b1; b++) {
        out.add(cellKey(a, b));
      }
    }
  }
  return out;
}

/// p에서 북쪽 [northM], 동쪽 [eastM] 미터 떨어진 점
LatLng offset(LatLng p, double northM, double eastM) => LatLng(
      p.lat + northM / _mPerDegLat,
      p.lng + eastM / (_mPerDegLat * math.cos(p.lat * math.pi / 180)),
    );

String formatDistance(double m) => m >= 1000 ? '${(m / 1000).toStringAsFixed(1)}km' : '${m.round()}m';

String formatDuration(Duration d) {
  final min = d.inMinutes;
  if (min < 60) return '$min분';
  return '${min ~/ 60}시간 ${min % 60}분';
}

String formatDate(DateTime t) => '${t.year}.${t.month}.${t.day}';
