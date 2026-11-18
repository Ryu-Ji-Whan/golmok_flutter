import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:gal/gal.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

/// 화면 일부를 그림으로 만들어 앨범에 저장하거나 공유하기 (사진 꾸미기, 스티커 카드)
class ImageOut {
  /// [key]를 단 RepaintBoundary를 PNG로 그린다. 그리기 전에 한 프레임 기다린다.
  static Future<Uint8List?> capture(GlobalKey key, {double pixelRatio = 3}) async {
    await WidgetsBinding.instance.endOfFrame;
    final box = key.currentContext?.findRenderObject() as RenderRepaintBoundary?;
    if (box == null) return null;
    final img = await box.toImage(pixelRatio: pixelRatio);
    final data = await img.toByteData(format: ui.ImageByteFormat.png);
    img.dispose();
    return data?.buffer.asUint8List();
  }

  /// 공유·저장용 임시 파일
  static Future<String> toTemp(Uint8List bytes, {String prefix = 'golmok'}) async {
    final dir = await getTemporaryDirectory();
    final f = File(p.join(dir.path, '${prefix}_${DateTime.now().millisecondsSinceEpoch}.png'));
    await f.writeAsBytes(bytes);
    return f.path;
  }

  /// 앨범 "골목대장"에 저장. 성공하면 null, 실패하면 보여 줄 문장.
  static Future<String?> saveToGallery(String path) async {
    const noPermission = '사진 권한이 꺼져 있어요. 설정에서 골목대장의 사진 접근을 켜 주세요';
    try {
      if (!await Gal.hasPermission(toAlbum: true) && !await Gal.requestPermission(toAlbum: true)) return noPermission;
      await Gal.putImage(path, album: '골목대장');
      return null;
    } on GalException catch (e) {
      return switch (e.type) {
        GalExceptionType.permissionDenied => noPermission,
        GalExceptionType.notEnoughSpace => '폰 저장 공간이 모자라요',
        _ => '저장하지 못했어요. 다시 해 주세요',
      };
    } catch (_) {
      return '저장하지 못했어요. 다시 해 주세요';
    }
  }

  /// 카카오톡·인스타그램·문자 등으로 보내기 (폰의 공유 창을 연다). 실패하면 보여 줄 문장.
  static Future<String?> share(String path, {String? text}) async {
    try {
      await SharePlus.instance.share(ShareParams(files: [XFile(path, mimeType: 'image/png')], text: text));
      return null;
    } catch (_) {
      return '공유하지 못했어요. 다시 해 주세요';
    }
  }
}
