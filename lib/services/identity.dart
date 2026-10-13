import 'dart:math';

import 'package:shared_preferences/shared_preferences.dart';

/// هوية هذا الجهاز/العامل (اسم + معرّف) وآخر نشاط تم استلامه.
class Identity {
  static late SharedPreferences _p;
  static String id = '';
  static String name = '';
  static String? lastSeen;

  static Future<void> load() async {
    _p = await SharedPreferences.getInstance();
    var i = _p.getString('device_id');
    if (i == null || i.isEmpty) {
      final r = Random.secure();
      i = List.generate(16, (_) => r.nextInt(256).toRadixString(16).padLeft(2, '0'))
          .join();
      await _p.setString('device_id', i);
    }
    id = i;
    name = _p.getString('worker_name') ?? '';
    lastSeen = _p.getString('last_seen');
  }

  static Future<void> setName(String n) async {
    name = n.trim();
    await _p.setString('worker_name', name);
  }

  static Future<void> setLastSeen(String v) async {
    lastSeen = v;
    await _p.setString('last_seen', v);
  }
}
