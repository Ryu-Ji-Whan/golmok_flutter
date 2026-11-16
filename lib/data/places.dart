import 'dart:async';
import 'dart:convert';
import 'dart:io';

/// 동네 하나 (예: "수원시 팔달구 행궁동")
class Place {
  const Place(this.name, this.lat, this.lng);
  final String name;
  final double lat;
  final double lng;
}

/// 전국 동네 찾기 — OpenStreetMap Nominatim (무료, 키 없음)
/// 이용 규칙: 1초에 한 번 이하, 앱 이름을 User-Agent로 밝히기. 그래서 검색은 입력을 멈춘 뒤에만 보낸다.
class Places {
  static const _ua = 'GolmokDaejang/0.1 (Flutter neighborhood walking app)';
  static const _host = 'nominatim.openstreetmap.org';

  /// 동·읍·면 이름으로 찾기
  static Future<List<Place>> search(String query) async {
    final q = query.trim();
    if (q.isEmpty) return [];
    final data = await _get(Uri.https(_host, '/search', {
      'q': q,
      'countrycodes': 'kr',
      'format': 'jsonv2',
      'addressdetails': '1',
      'limit': '15',
      'accept-language': 'ko',
    }));
    if (data is! List) return [];
    final seen = <String>{};
    final out = <Place>[];
    for (final r in data) {
      if (r is! Map) continue;
      final name = _name(r['address']);
      if (name == null || !seen.add(name)) continue;
      out.add(Place(name, double.tryParse('${r['lat']}') ?? 0, double.tryParse('${r['lon']}') ?? 0));
    }
    return out;
  }

  /// 지금 위치의 동네
  static Future<Place?> reverse(double lat, double lng) async {
    final data = await _get(Uri.https(_host, '/reverse', {
      'lat': '$lat',
      'lon': '$lng',
      'format': 'jsonv2',
      'addressdetails': '1',
      'zoom': '16',
      'accept-language': 'ko',
    }));
    if (data is! Map) return null;
    final name = _name(data['address']);
    return name == null ? null : Place(name, lat, lng);
  }

  /// 주소에서 "시 구 동" 모양의 이름을 만든다. 동·읍·면·리가 없으면 동네가 아니라고 보고 null.
  static String? _name(Object? address) {
    if (address is! Map) return null;
    String? pick(List<String> keys) {
      for (final k in keys) {
        final v = address[k];
        if (v is String && v.trim().isNotEmpty) return v.trim();
      }
      return null;
    }

    final dong = pick(['quarter', 'suburb', 'village', 'neighbourhood', 'town', 'hamlet']);
    if (dong == null) return null;
    final gu = pick(['borough', 'city_district', 'county']);
    final si = pick(['city', 'province', 'state']);
    final parts = <String>[];
    for (final p in [si, gu, dong]) {
      if (p != null && !parts.contains(p)) parts.add(p);
    }
    return parts.join(' ');
  }

  static Future<Object?> _get(Uri uri) async {
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 8);
    try {
      final req = await client.getUrl(uri);
      req.headers.set(HttpHeaders.userAgentHeader, _ua);
      req.headers.set(HttpHeaders.acceptLanguageHeader, 'ko');
      final res = await req.close().timeout(const Duration(seconds: 10));
      if (res.statusCode != 200) return null;
      return jsonDecode(await res.transform(utf8.decoder).join());
    } catch (_) {
      return null;
    } finally {
      client.close();
    }
  }
}
