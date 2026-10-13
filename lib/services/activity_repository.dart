import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../config/supabase_config.dart';
import '../models/activity.dart';
import 'customer_repository.dart';
import 'identity.dart';

/// Shared audit log. Activities created offline are queued on-device and sent
/// to Supabase when a later request succeeds.
class ActivityRepository {
  static const _timeout = Duration(seconds: 20);
  static const epoch = '1970-01-01T00:00:00+00:00';
  static const _queueKey = 'activity_pending_v1';
  final String _base = '${SupabaseConfig.url}/rest/v1/activity_log';

  Map<String, String> get _headers => {
        'apikey': SupabaseConfig.publishableKey,
        'Content-Type': 'application/json; charset=utf-8',
        'Prefer': 'return=representation',
      };

  Future<SharedPreferences> get _prefs => SharedPreferences.getInstance();

  Future<List<Map<String, dynamic>>> _queue() async {
    final raw = (await _prefs).getString(_queueKey);
    if (raw == null) return [];
    try { return (jsonDecode(raw) as List).cast<Map<String, dynamic>>(); }
    catch (_) { return []; }
  }

  Future<void> _saveQueue(List<Map<String, dynamic>> q) async =>
      (await _prefs).setString(_queueKey, jsonEncode(q));

  Future<void> log({required String action, required String customerName, String details = ''}) async {
    final record = {
      'actor_id': Identity.id,
      'actor_name': Identity.name.isEmpty ? 'عامل غير مسمى' : Identity.name,
      'action': action,
      'customer_name': customerName,
      'details': details,
    };
    try {
      final res = await http.post(Uri.parse(_base), headers: _headers,
        body: jsonEncode(record)).timeout(_timeout);
      checkResponse(res);
    } on SocketException catch (_) { await _addPending(record); }
      on http.ClientException catch (_) { await _addPending(record); }
      on TimeoutException catch (_) { await _addPending(record); }
  }

  Future<void> _addPending(Map<String, dynamic> record) async {
    final q = await _queue();
    q.add(record..['local_created_at'] = DateTime.now().toUtc().toIso8601String());
    await _saveQueue(q);
  }

  Future<void> syncPending() async {
    final q = await _queue();
    var done = 0;
    for (final record in q) {
      final payload = Map<String, dynamic>.from(record)..remove('local_created_at');
      final res = await http.post(Uri.parse(_base), headers: _headers,
        body: jsonEncode(payload)).timeout(_timeout);
      checkResponse(res);
      done++;
    }
    if (done > 0) await _saveQueue(q.skip(done).toList());
  }

  List<Activity> _parse(http.Response res) {
    checkResponse(res);
    final list = jsonDecode(utf8.decode(res.bodyBytes)) as List<dynamic>;
    return list.map((e) => Activity.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<List<Activity>> fetchRecent({int limit = 100}) async {
    await syncPending();
    final uri = Uri.parse(_base).replace(queryParameters: {
      'select': '*', 'order': 'created_at.desc', 'limit': '$limit',
    });
    return _parse(await http.get(uri, headers: _headers).timeout(_timeout));
  }

  Future<List<Activity>> fetchSince(String since) async {
    await syncPending();
    final uri = Uri.parse(_base).replace(queryParameters: {
      'select': '*', 'created_at': 'gt.$since', 'order': 'created_at.asc', 'limit': '100',
    });
    return _parse(await http.get(uri, headers: _headers).timeout(_timeout));
  }

  Future<String?> latestStamp() async {
    final items = await fetchRecent(limit: 1);
    return items.isEmpty ? null : items.first.createdAtRaw;
  }
}
