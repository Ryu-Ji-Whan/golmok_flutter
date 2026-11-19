import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../theme.dart';

/// 기록 사진 저장 방식
/// - 찍거나 고른 사진은 앱 폴더(Documents/photos)에 복사하고, DB에는 'file:photos/이름.jpg'처럼 앱 폴더 기준 경로만 저장한다.
///   (iOS는 앱을 업데이트하면 앱 폴더의 전체 경로가 바뀌므로 전체 경로를 저장하면 사진을 잃는다)
/// - 'assets/'로 시작하면 앱에 들어 있는 그림 (예전 데모 기록)
class Photos {
  static String _docs = '';

  /// 앱 시작할 때 한 번 (main.dart)
  static Future<void> init() async {
    try {
      _docs = (await getApplicationDocumentsDirectory()).path;
    } catch (_) {}
  }

  static String resolve(String stored) => stored.startsWith('file:') ? p.join(_docs, stored.substring(5)) : stored;

  /// 사진을 찍거나 앨범에서 골라 앱 폴더에 넣는다. 취소하면 null.
  /// 권한이 없거나 실패하면 [PhotoError]를 던진다.
  static Future<String?> pick(ImageSource source) async {
    final XFile? x;
    try {
      x = await ImagePicker().pickImage(source: source, maxWidth: 1600, maxHeight: 1600, imageQuality: 85);
    } on PlatformException catch (e) {
      final denied = e.code.contains('denied') || e.code.contains('access');
      throw PhotoError(denied
          ? (source == ImageSource.camera ? '카메라 권한이 꺼져 있어요. 설정에서 골목대장의 카메라를 켜 주세요' : '사진 권한이 꺼져 있어요. 설정에서 골목대장의 사진 접근을 켜 주세요')
          : '사진을 불러오지 못했어요');
    }
    if (x == null) return null;
    final dir = Directory(p.join(_docs, 'photos'));
    await dir.create(recursive: true);
    final ext = p.extension(x.path).isEmpty ? '.jpg' : p.extension(x.path).toLowerCase();
    final name = 'photo_${DateTime.now().millisecondsSinceEpoch}$ext';
    await x.saveTo(p.join(dir.path, name));
    return 'file:photos/$name';
  }

  /// 앱에서 만든 그림(꾸민 사진 등)을 앱 폴더에 저장하고 'file:photos/…' 경로를 돌려준다.
  static Future<String> saveBytes(List<int> bytes, {String ext = '.png'}) async {
    final dir = Directory(p.join(_docs, 'photos'));
    await dir.create(recursive: true);
    final name = 'photo_${DateTime.now().millisecondsSinceEpoch}$ext';
    await File(p.join(dir.path, name)).writeAsBytes(bytes);
    return 'file:photos/$name';
  }

  /// 기록을 지우거나 사진을 바꿀 때 예전 파일 정리
  static Future<void> delete(String? stored) async {
    if (stored == null || !stored.startsWith('file:')) return;
    try {
      await File(resolve(stored)).delete();
    } catch (_) {}
  }
}

class PhotoError implements Exception {
  PhotoError(this.message);
  final String message;
}

/// 기록 사진 한 장
class SpotPhoto extends StatelessWidget {
  const SpotPhoto(this.stored, {super.key, this.height, this.width, this.fit = BoxFit.cover});
  final String stored;
  final double? height;
  final double? width;
  final BoxFit fit;

  @override
  Widget build(BuildContext context) {
    Widget broken(BuildContext _, Object __, StackTrace? ___) => Container(
          height: height,
          width: width,
          color: C.sand,
          alignment: Alignment.center,
          child: Icon(Icons.broken_image_outlined, color: C.muted),
        );
    if (stored.startsWith('assets/')) {
      return Image.asset(stored, height: height, width: width, fit: fit, errorBuilder: broken);
    }
    return Image.file(File(Photos.resolve(stored)), height: height, width: width, fit: fit, errorBuilder: broken);
  }
}
