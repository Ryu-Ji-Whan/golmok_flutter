import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../data/geo.dart';
import '../theme.dart';

/// 산책 경로 미리보기 (지도 없이 경로 모양만, 만화풍: 잉크 테두리 + 주황 선, 출발·도착 점)
/// 내 기록에서만 쓴다. 다른 사람의 경로는 보여 주지 않는다.
class RouteThumb extends StatelessWidget {
  const RouteThumb(this.path, {super.key, this.size = 64, this.radius = 14});
  final List<LatLng> path;
  final double size;
  final double radius;

  @override
  Widget build(BuildContext context) => ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: SizedBox(
          width: size,
          height: size,
          child: CustomPaint(painter: _RoutePainter(path, size)),
        ),
      );
}

class _RoutePainter extends CustomPainter {
  _RoutePainter(this.path, this.box);
  final List<LatLng> path;
  final double box;

  @override
  void paint(Canvas canvas, Size size) {
    // 바탕: 민트에 옅은 골목 격자
    canvas.drawRect(Offset.zero & size, Paint()..color = C.mint);
    final grid = Paint()
      ..color = C.white
      ..strokeWidth = math.max(2, size.width / 22);
    for (var i = 1; i < 4; i++) {
      final t = size.width * i / 4;
      canvas.drawLine(Offset(t, 0), Offset(t, size.height), grid);
      canvas.drawLine(Offset(0, t), Offset(size.width, t), grid);
    }
    if (path.length < 2) {
      final dot = Paint()..color = C.forest;
      canvas.drawCircle(size.center(Offset.zero), size.width / 10, dot);
      return;
    }

    // 위도·경도를 미터 비율에 맞춰 상자 안에 넣는다 (가로세로 비율 유지)
    final lat0 = path.first.lat;
    final kx = math.cos(lat0 * math.pi / 180);
    var minX = double.infinity, maxX = -double.infinity, minY = double.infinity, maxY = -double.infinity;
    for (final p in path) {
      final x = p.lng * kx, y = p.lat;
      minX = math.min(minX, x);
      maxX = math.max(maxX, x);
      minY = math.min(minY, y);
      maxY = math.max(maxY, y);
    }
    final pad = size.width * 0.16;
    final span = math.max(math.max(maxX - minX, maxY - minY), 1e-6);
    final scale = (size.width - pad * 2) / span;
    final ox = pad + ((size.width - pad * 2) - (maxX - minX) * scale) / 2;
    final oy = pad + ((size.height - pad * 2) - (maxY - minY) * scale) / 2;
    Offset at(LatLng p) => Offset(ox + (p.lng * kx - minX) * scale, size.height - (oy + (p.lat - minY) * scale));

    final line = Path()..moveTo(at(path.first).dx, at(path.first).dy);
    // 점이 많으면 건너뛰며 그린다 (미리보기라 300점이면 충분)
    final step = math.max(1, path.length ~/ 300);
    for (var i = step; i < path.length; i += step) {
      final o = at(path[i]);
      line.lineTo(o.dx, o.dy);
    }
    final last = at(path.last);
    line.lineTo(last.dx, last.dy);

    final w = math.max(2.5, size.width / 18);
    canvas.drawPath(
        line,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = w + 3
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round
          ..color = C.ink);
    canvas.drawPath(
        line,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = w
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round
          ..color = C.orange);

    final r = w * 1.1;
    final start = at(path.first);
    canvas.drawCircle(start, r + 1.5, Paint()..color = C.white);
    canvas.drawCircle(start, r, Paint()..color = C.leaf);
    canvas.drawCircle(last, r + 1.5, Paint()..color = C.white);
    canvas.drawCircle(last, r, Paint()..color = C.forest);
  }

  @override
  bool shouldRepaint(_RoutePainter old) => old.path.length != path.length || old.box != box;
}
