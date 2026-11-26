import 'package:flutter/foundation.dart' show debugPrint;
import 'package:supabase_flutter/supabase_flutter.dart';

import 'geo.dart';
import 'models.dart';
import 'remote.dart';

/// 친구 방 (서버 006). 방 사람끼리만 오늘 걸은 경로와 올린 스티커가 보인다. 한 방 최대 10명
const roomLimit = 10;

/// 내 방 하나. state: member(들어감) / invited(초대 받음, 수락 전)
class Room {
  Room(this.id, this.name, this.code, this.state, this.members, this.isOwner, this.hideRoute, this.invitedBy);
  final String id, name, code, state, invitedBy;
  final int members;
  final bool isOwner, hideRoute;
  bool get invited => state == 'invited';
}

/// 방 사람 한 명
class RoomPerson {
  RoomPerson(this.id, this.nickname, this.character, this.isMe, this.hideRoute);
  final String id, nickname, character;
  final bool isMe, hideRoute;
}

/// 방 사람의 오늘 산책 하나
class RoomTrack {
  RoomTrack(this.userId, this.path, this.meters);
  final String userId;
  final List<LatLng> path;
  final double meters;
}

/// 방에 올라온 스티커 기록
class RoomSticker {
  RoomSticker({
    required this.id,
    required this.userId,
    required this.spotId,
    required this.nickname,
    required this.character,
    required this.lat,
    required this.lng,
    required this.stickerId,
    required this.title,
    required this.memo,
    required this.createdAt,
    required this.isMine,
  });
  final String id, userId, spotId, nickname, character, stickerId, title, memo;
  final double lat, lng;
  final DateTime createdAt;
  final bool isMine;
  LatLng get pos => LatLng(lat, lng);
}

/// 코드로 들어가기·초대 결과
enum RoomJoin { ok, already, full, noRoom, notFriend, failed }

RoomJoin _join(Object? v) => switch (v) {
      'ok' => RoomJoin.ok,
      'already' => RoomJoin.already,
      'full' => RoomJoin.full,
      'no_room' => RoomJoin.noRoom,
      'not_friend' => RoomJoin.notFriend,
      _ => RoomJoin.failed,
    };

class Rooms {
  static SupabaseClient get _c => Supabase.instance.client;

  static Future<List<Room>?> mine() async {
    if (!Remote.signedIn) return null;
    try {
      final rows = await _c.rpc('my_rooms') as List;
      return [
        for (final r in rows)
          Room(r['id'] as String, r['name'] as String, (r['code'] as String?) ?? '', r['state'] as String, (r['members'] as num).toInt(),
              r['is_owner'] == true, r['hide_route'] == true, (r['invited_by'] as String?) ?? ''),
      ];
    } catch (e) {
      debugPrint('my_rooms: $e');
      return null;
    }
  }

  /// 방 만들기 → 초대 코드. 실패하면 null
  static Future<String?> create(String name) async {
    try {
      final rows = await _c.rpc('create_room', params: {'p_name': name}) as List;
      return rows.isEmpty ? null : rows.first['code'] as String;
    } catch (e) {
      debugPrint('create_room: $e');
      return null;
    }
  }

  static Future<RoomJoin> join(String code) async {
    try {
      return _join(await _c.rpc('join_room', params: {'p_code': code}));
    } catch (_) {
      return RoomJoin.failed;
    }
  }

  static Future<RoomJoin> invite(String roomId, String friendId) async {
    try {
      return _join(await _c.rpc('invite_to_room', params: {'p_room': roomId, 'p_friend': friendId}));
    } catch (_) {
      return RoomJoin.failed;
    }
  }

  static Future<RoomJoin> answer(String roomId, bool accept) async {
    try {
      return _join(await _c.rpc('answer_room_invite', params: {'p_room': roomId, 'p_accept': accept}));
    } catch (_) {
      return RoomJoin.failed;
    }
  }

  static Future<bool> leave(String roomId) async {
    try {
      await _c.rpc('leave_room', params: {'p_room': roomId});
      return true;
    } catch (_) {
      return false;
    }
  }

  static Future<List<RoomPerson>?> people(String roomId) async {
    try {
      final rows = await _c.rpc('room_people', params: {'p_room': roomId}) as List;
      return [
        for (final r in rows)
          RoomPerson(r['user_id'] as String, r['nickname'] as String, r['character_id'] as String, r['is_me'] == true, r['hide_route'] == true),
      ];
    } catch (_) {
      return null;
    }
  }

  static Future<List<RoomTrack>?> today(String roomId) async {
    try {
      final rows = await _c.rpc('room_today', params: {'p_room': roomId}) as List;
      final out = <RoomTrack>[];
      for (final r in rows) {
        try {
          out.add(RoomTrack(
            r['user_id'] as String,
            [for (final p in (r['path'] as List)) LatLng((p[1] as num).toDouble(), (p[0] as num).toDouble())],
            ((r['distance_m'] as num?) ?? 0).toDouble(),
          ));
        } catch (_) {}
      }
      return out;
    } catch (_) {
      return null;
    }
  }

  static Future<bool> setHidden(String roomId, bool hide) async {
    try {
      await _c.rpc('set_room_route_hidden', params: {'p_room': roomId, 'p_hide': hide});
      return true;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> share(String roomId, Spot sp) async {
    try {
      await _c.rpc('share_to_room', params: {
        'p_room': roomId,
        'p_spot': sp.id,
        'p_lat': sp.lat,
        'p_lng': sp.lng,
        'p_sticker': sp.stickerId,
        'p_title': sp.title,
        'p_memo': sp.memo,
      });
      return true;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> unshare(String id) async {
    try {
      await _c.rpc('unshare_room_spot', params: {'p_id': id});
      return true;
    } catch (_) {
      return false;
    }
  }

  static Future<List<RoomSticker>?> stickers(String roomId) async {
    try {
      final rows = await _c.rpc('room_stickers', params: {'p_room': roomId}) as List;
      return [
        for (final r in rows)
          RoomSticker(
            id: r['id'] as String,
            userId: r['user_id'] as String,
            spotId: r['spot_id'] as String,
            nickname: r['nickname'] as String,
            character: r['character_id'] as String,
            lat: (r['lat'] as num).toDouble(),
            lng: (r['lng'] as num).toDouble(),
            stickerId: r['sticker_id'] as String,
            title: r['title'] as String,
            memo: (r['memo'] as String?) ?? '',
            createdAt: DateTime.parse(r['created_at'] as String).toLocal(),
            isMine: r['is_mine'] == true,
          ),
      ];
    } catch (_) {
      return null;
    }
  }
}
