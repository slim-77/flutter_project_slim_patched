import 'package:flutter/material.dart';

import '../models/activity.dart';
import '../services/activity_repository.dart';
import '../services/customer_repository.dart';
import '../services/identity.dart';
import '../theme/app_theme.dart';
import '../widgets/name_dialog.dart';

/// سجل كل الإضافات والتعديلات والحذف من جميع العمال.
class ActivityScreen extends StatefulWidget {
  const ActivityScreen({super.key});

  @override
  State<ActivityScreen> createState() => _ActivityScreenState();
}

class _ActivityScreenState extends State<ActivityScreen> {
  final _repo = ActivityRepository();
  List<Activity> _items = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final data = await _repo.fetchRecent();
      if (!mounted) return;
      setState(() {
        _items = data;
        _loading = false;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = friendlyError(e);
      });
    }
  }

  String _ago(DateTime t) {
    final d = DateTime.now().difference(t);
    if (d.inMinutes < 1) return 'الآن';
    if (d.inMinutes < 60) return 'منذ ${d.inMinutes} د';
    if (d.inHours < 24) return 'منذ ${d.inHours} ساعة';
    return 'منذ ${d.inDays} يوم';
  }

  (IconData, Color) _style(String action) {
    switch (action) {
      case 'add':
        return (Icons.person_add_alt_1_rounded, AppColors.success);
      case 'delete':
        return (Icons.delete_outline_rounded, AppColors.danger);
      default:
        return (Icons.edit_rounded, AppColors.primary);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('النشاط'),
        actions: [
          IconButton(
            tooltip: 'اسمي: ${Identity.name}',
            icon: const Icon(Icons.badge_outlined),
            onPressed: () async {
              await askWorkerName(context, required: false);
              if (mounted) setState(() {});
            },
          ),
          IconButton(
            tooltip: 'تحديث',
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _load,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null && _items.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Text(_error!, textAlign: TextAlign.center),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _load,
                  child: _items.isEmpty
                      ? ListView(children: const [
                          Padding(
                            padding: EdgeInsets.only(top: 100),
                            child: Center(
                              child: Text('لا يوجد نشاط بعد',
                                  style: TextStyle(color: AppColors.textMuted)),
                            ),
                          )
                        ])
                      : ListView.separated(
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                          itemCount: _items.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 8),
                          itemBuilder: (_, i) {
                            final a = _items[i];
                            final (icon, color) = _style(a.action);
                            return Card(
                              child: Padding(
                                padding: const EdgeInsets.all(12),
                                child: Row(children: [
                                  CircleAvatar(
                                    radius: 20,
                                    backgroundColor:
                                        color.withValues(alpha: 0.15),
                                    child: Icon(icon, color: color, size: 20),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(a.headline,
                                            style: const TextStyle(
                                                fontWeight: FontWeight.w700)),
                                        const SizedBox(height: 2),
                                        Text(a.body,
                                            style: const TextStyle(
                                                color: AppColors.textMuted,
                                                fontSize: 13,
                                                height: 1.4)),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(_ago(a.createdAt),
                                      style: const TextStyle(
                                          color: AppColors.textMuted,
                                          fontSize: 11)),
                                ]),
                              ),
                            );
                          },
                        ),
                ),
    );
  }
}
