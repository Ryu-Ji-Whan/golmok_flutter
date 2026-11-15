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
const cellM = 50.0;

/// 걸은 지점에서 이 반경 안의 칸을 밝힌다(미터).
const revealM = 100.0;

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

/// p 주변 [radius] 미터 안의 칸 키 목록
List<String> cellsAround(LatLng p, [double radius = revealM]) {
  final ci = (p.lat / dLat).floor();
  final cj = (p.lng / dLng).floor();
  final n = (radius / cellM).ceil() + 1;
  final keys = <String>[];
  for (var di = -n; di <= n; di++) {
    for (var dj = -n; dj <= n; dj++) {
      final center = LatLng((ci + di + 0.5) * dLat, (cj + dj + 0.5) * dLng);
      if (distanceM(p, center) <= radius + cellM / 2) keys.add(cellKey(ci + di, cj + dj));
    }
  }
  return keys;
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
