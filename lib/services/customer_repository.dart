import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../config/supabase_config.dart';
import '../models/customer.dart';

class RepoException implements Exception {
  final String message;
  RepoException(this.message);
  @override
  String toString() => message;
}

String friendlyError(Object e) {
  if (e is RepoException) return e.message;
  if (e is SocketException || e is http.ClientException) {
    return 'تعذر الاتصال بالسيرفر؛ تم الاحتفاظ بالتغييرات محلياً إن أمكن';
  }
  if (e is TimeoutException) return 'انتهت مهلة الاتصال؛ تحقق من الإنترنت';
  return 'حدث خطأ غير متوقع';
}

/// Offline-first repository. Local cache and pending operations are persisted
/// on the device and replayed in order when the server becomes reachable.
class CustomerRepository {
  static const _timeout = Duration(seconds: 20);
  static const _cacheKey = 'customers_cache_v1';
  static const _queueKey = 'customers_pending_v1';
  final String _base = '${SupabaseConfig.url}/rest/v1/customers';
  Future<void>? _syncing;

  Map<String, String> get _headers => {
        'apikey': SupabaseConfig.publishableKey,
        'Content-Type': 'application/json; charset=utf-8',
        'Prefer': 'return=representation',
      };

  String _newUuid() {
    final r = Random.secure();
    final b = List<int>.generate(16, (_) => r.nextInt(256));
    b[6] = (b[6] & 0x0f) | 0x40;
    b[8] = (b[8] & 0x3f) | 0x80;
    final h = b.map((v) => v.toRadixString(16).padLeft(2, '0')).join();
    return '${h.substring(0, 8)}-${h.substring(8, 12)}-${h.substring(12, 16)}-${h.substring(16, 20)}-${h.substring(20)}';
  }

  Future<SharedPreferences> get _prefs => SharedPreferences.getInstance();

  Future<List<Customer>> _readCache() async {
    final p = await _prefs;
    final raw = p.getString(_cacheKey);
    if (raw == null || raw.isEmpty) return [];
    try {
      return (jsonDecode(raw) as List<dynamic>)
          .map((e) => Customer.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) { return []; }
  }

  Future<void> _writeCache(List<Customer> customers) async {
    final p = await _prefs;
    await p.setString(_cacheKey, jsonEncode(customers.map((c) => {
      'id': c.id, ...c.toJson(), 'created_at': c.createdAt.toUtc().toIso8601String(),
    }).toList()));
  }

  Future<List<Map<String, dynamic>>> _readQueue() async {
    final p = await _prefs;
    final raw = p.getString(_queueKey);
    if (raw == null || raw.isEmpty) return [];
    try { return (jsonDecode(raw) as List).cast<Map<String, dynamic>>(); }
    catch (_) { return []; }
  }

  Future<void> _writeQueue(List<Map<String, dynamic>> q) async {
    final p = await _prefs;
    await p.setString(_queueKey, jsonEncode(q));
  }

  bool _isNetworkError(Object e) => e is SocketException || e is http.ClientException || e is TimeoutException;

  Future<List<Customer>> fetchAll() async {
    try {
      await syncPending();
      final res = await http.get(Uri.parse('$_base?select=*&order=created_at.desc'), headers: _headers).timeout(_timeout);
      checkResponse(res);
      final list = (jsonDecode(utf8.decode(res.bodyBytes)) as List<dynamic>)
          .map((e) => Customer.fromJson(e as Map<String, dynamic>)).toList();
      // Overlay pending local operations so un-synced work remains visible.
      final merged = {for (final c in list) c.id: c};
      for (final op in await _readQueue()) {
        final id = op['id']?.toString() ?? '';
        if (op['type'] == 'delete') { merged.remove(id); }
        else if (op['customer'] is Map<String, dynamic>) {
          merged[id] = Customer.fromJson(op['customer'] as Map<String, dynamic>);
        }
      }
      final result = merged.values.toList()..sort((a,b) => b.createdAt.compareTo(a.createdAt));
      await _writeCache(result);
      return result;
    } catch (e) {
      if (!_isNetworkError(e)) rethrow;
      final cache = await _readCache();
      if (cache.isNotEmpty) return cache;
      throw RepoException('لا توجد بيانات محفوظة على هذا الجهاز بعد. اتصل بالإنترنت أول مرة لتنزيل العملاء.');
    }
  }

  Future<void> insert(Customer c) async {
    final id = c.id.isEmpty ? _newUuid() : c.id;
    final item = Customer(id: id, name: c.name, phone: c.phone, address: c.address,
      routerNumber: c.routerNumber, routerType: c.routerType, locationUrl: c.locationUrl,
      plan: c.plan, status: c.status, notes: c.notes, createdAt: c.createdAt);
    try {
      final res = await http.post(Uri.parse(_base), headers: _headers,
        body: jsonEncode({'id': id, ...item.toJson()})).timeout(_timeout);
      checkResponse(res);
    } catch (e) {
      if (!_isNetworkError(e)) rethrow;
      await _enqueue({'type':'insert','id':id,'customer':_customerMap(item)});
    }
    final all = await _readCache();
    await _writeCache([item, ...all.where((x) => x.id != id)]);
  }

  Future<void> update(Customer c) async {
    try {
      final res = await http.patch(Uri.parse('$_base?id=eq.${c.id}'), headers: _headers,
        body: jsonEncode(c.toJson())).timeout(_timeout);
      checkResponse(res);
    } catch (e) {
      if (!_isNetworkError(e)) rethrow;
      await _enqueue({'type':'update','id':c.id,'customer':_customerMap(c)});
    }
    final all = await _readCache();
    await _writeCache([c, ...all.where((x) => x.id != c.id)]);
  }

  Future<void> delete(String id) async {
    try {
      final res = await http.delete(Uri.parse('$_base?id=eq.$id'), headers: _headers).timeout(_timeout);
      checkResponse(res);
    } catch (e) {
      if (!_isNetworkError(e)) rethrow;
      await _enqueue({'type':'delete','id':id});
    }
    final all = await _readCache();
    await _writeCache(all.where((x) => x.id != id).toList());
  }

  Map<String, dynamic> _customerMap(Customer c) => {
    'id':c.id, ...c.toJson(), 'created_at':c.createdAt.toUtc().toIso8601String(),
  };

  Future<void> _enqueue(Map<String, dynamic> op) async {
    final q = await _readQueue();
    // Keep only the latest pending operation per customer, except preserve a
    // new insert followed by edits as a final insert with the latest payload.
    final id = op['id'];
    final index = q.lastIndexWhere((x) => x['id'] == id);
    if (index >= 0 && q[index]['type'] != 'delete' && op['type'] != 'delete') {
      if (q[index]['type'] == 'insert') {
        q[index] = {'type':'insert','id':id,'customer':op['customer']};
      } else {
        q[index] = op;
      }
    } else {
      q.add(op);
    }
    await _writeQueue(q);
  }

  /// Safe to call repeatedly; operations are removed only after server success.
  Future<void> syncPending() async {
    if (_syncing != null) return _syncing!;
    _syncing = _doSync();
    try { await _syncing; } finally { _syncing = null; }
  }

  Future<void> _doSync() async {
    final q = await _readQueue();
    if (q.isEmpty) return;
    var completed = 0;
    for (final op in q) {
      final id = op['id'].toString();
      final type = op['type'];
      http.Response res;
      if (type == 'delete') {
        res = await http.delete(Uri.parse('$_base?id=eq.$id'), headers: _headers).timeout(_timeout);
      } else if (type == 'insert') {
        res = await http.post(Uri.parse(_base), headers: _headers,
          body: jsonEncode(op['customer'])).timeout(_timeout);
      } else {
        final customer = Map<String, dynamic>.from(op['customer'] as Map);
        customer.remove('id'); customer.remove('created_at');
        res = await http.patch(Uri.parse('$_base?id=eq.$id'), headers: _headers,
          body: jsonEncode(customer)).timeout(_timeout);
      }
      checkResponse(res);
      completed++;
    }
    if (completed > 0) await _writeQueue(q.skip(completed).toList());
  }
}

void checkResponse(http.Response res) {
  if (res.statusCode >= 200 && res.statusCode < 300) return;
  final body = utf8.decode(res.bodyBytes);
  if (res.statusCode == 404 || body.contains('PGRST205')) {
    throw RepoException('جدول غير موجود في Supabase، نفّذ ملف supabase_setup.sql');
  }
  if (res.statusCode == 401 || res.statusCode == 403) {
    throw RepoException('الصلاحيات غير مفعلة في Supabase (RLS)، راجع سياسات Supabase.');
  }
  if (body.contains('customers_phone_check')) throw RepoException('رقم الهاتف يجب أن يكون 9 أرقام بالضبط');
  throw RepoException('فشل الطلب (${res.statusCode})');
}
