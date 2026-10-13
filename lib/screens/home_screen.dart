import 'dart:async';

import 'package:flutter/material.dart';

import '../models/activity.dart';
import '../models/customer.dart';
import '../models/networks.dart';
import '../services/activity_repository.dart';
import '../services/customer_repository.dart';
import '../services/identity.dart';
import '../services/notification_service.dart';
import '../theme/app_theme.dart';
import '../widgets/customer_card.dart';
import '../widgets/name_dialog.dart';
import 'activity_screen.dart';
import 'customer_form_screen.dart';

enum _Filter { all, active, suspended }

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  final _repo = CustomerRepository();
  final _activity = ActivityRepository();
  List<Customer> _all = [];
  String _query = '';
  _Filter _filter = _Filter.all;
  String? _network; // null = كل الشبكات
  bool _loading = true;
  String? _error;

  Timer? _timer;
  bool _polling = false;
  int _unread = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _load();
    _timer = Timer.periodic(const Duration(seconds: 10), (_) => _poll());
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (Identity.name.isEmpty && mounted) {
        await askWorkerName(context, required: true);
      }
      _poll();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _poll();
  }

  Future<void> _load() async {
    try {
      final data = await _repo.fetchAll();
      if (!mounted) return;
      setState(() {
        _all = data;
        _loading = false;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      final msg = friendlyError(e);
      setState(() {
        _loading = false;
        _error = msg;
      });
      if (_all.isNotEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
      }
    }
  }

  /// يفحص سجل النشاط: إذا فيه تغييرات من عمال آخرين يحدّث القائمة ويرسل إشعار.
  Future<void> _poll() async {
    if (_polling || !mounted) return;
    _polling = true;
    try {
      // Retry offline customer changes whenever the periodic monitor runs.
      await _repo.syncPending();
      final since = Identity.lastSeen;
      if (since == null) {
        // أول تشغيل: نبدأ من آخر نشاط موجود بدون إغراق بإشعارات قديمة
        final latest = await _activity.latestStamp();
        await Identity.setLastSeen(latest ?? ActivityRepository.epoch);
        return;
      }
      final items = await _activity.fetchSince(since);
      if (items.isEmpty) return;
      await Identity.setLastSeen(items.last.createdAtRaw);
      await _load();
      final others = items.where((a) => a.actorId != Identity.id).toList();
      if (others.isEmpty || !mounted) return;
      setState(() => _unread += others.length);
      _notify(others);
    } catch (_) {
      // تجاهل أخطاء الشبكة المؤقتة
    } finally {
      _polling = false;
    }
  }

  void _notify(List<Activity> others) {
    if (others.length > 3) {
      NotificationService.show(
        id: DateTime.now().millisecondsSinceEpoch & 0x7fffffff,
        title: 'تحديثات جديدة على العملاء',
        body: '${others.length} تغييرات جديدة، افتح النشاط للتفاصيل',
      );
    } else {
      for (final a in others) {
        NotificationService.show(
          id: a.id.hashCode & 0x7fffffff,
          title: a.headline,
          body: a.body,
        );
      }
    }
    final last = others.last;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text('${last.headline}: ${last.body}'),
        action: SnackBarAction(label: 'عرض', onPressed: _openActivity),
      ));
  }

  Future<void> _openActivity() async {
    setState(() => _unread = 0);
    await Navigator.of(context)
        .push(MaterialPageRoute(builder: (_) => const ActivityScreen()));
  }

  List<Customer> _filtered() {
    final q = _query.trim().toLowerCase();
    return _all.where((c) {
      final matchFilter = switch (_filter) {
        _Filter.all => true,
        _Filter.active => c.status == CustomerStatus.active,
        _Filter.suspended => c.status == CustomerStatus.suspended,
      };
      if (!matchFilter) return false;
      if (_network != null && c.routerType.trim() != _network) return false;
      if (q.isEmpty) return true;
      return c.name.toLowerCase().contains(q) ||
          c.phone.contains(q) ||
          c.routerNumber.toLowerCase().contains(q) ||
          c.routerType.toLowerCase().contains(q);
    }).toList();
  }

  Future<void> _openForm([Customer? customer]) async {
    final message = await Navigator.of(context).push<String>(
      MaterialPageRoute(
        builder: (_) => CustomerFormScreen(customer: customer, repo: _repo),
      ),
    );
    if (message == null) return;
    await _load();
    _poll();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final list = _filtered();
    final activeCount =
        _all.where((c) => c.status == CustomerStatus.active).length;
    final stoppedCount = _all.length - activeCount;

    return Scaffold(
      appBar: AppBar(
        title: const Text('عملاء الشبكة'),
        actions: [
          IconButton(
            tooltip: 'النشاط',
            onPressed: _openActivity,
            icon: Badge(
              isLabelVisible: _unread > 0,
              label: Text('$_unread'),
              child: const Icon(Icons.notifications_none_rounded),
            ),
          ),
          IconButton(
            tooltip: 'تحديث',
            onPressed: _load,
            icon: const Icon(Icons.refresh_rounded),
          ),
          const SizedBox(width: 4),
        ],
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openForm(),
        icon: const Icon(Icons.person_add_alt_1_rounded),
        label: const Text('إضافة عميل',
            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : (_error != null && _all.isEmpty)
              ? _ErrorState(message: _error!, onRetry: _load)
              : Column(
                  children: [
                    // العدّادات تعمل كأزرار فلترة (الكل / نشط / موقوف)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 10),
                      child: Row(children: [
                        _StatTile(
                          label: 'الإجمالي',
                          value: '${_all.length}',
                          icon: Icons.groups_rounded,
                          color: AppColors.primary,
                          selected: _filter == _Filter.all,
                          onTap: () => setState(() => _filter = _Filter.all),
                        ),
                        const SizedBox(width: 10),
                        _StatTile(
                          label: 'نشط',
                          value: '$activeCount',
                          icon: Icons.wifi_rounded,
                          color: AppColors.success,
                          selected: _filter == _Filter.active,
                          onTap: () => setState(() => _filter =
                              _filter == _Filter.active
                                  ? _Filter.all
                                  : _Filter.active),
                        ),
                        const SizedBox(width: 10),
                        _StatTile(
                          label: 'موقوف',
                          value: '$stoppedCount',
                          icon: Icons.wifi_off_rounded,
                          color: AppColors.warning,
                          selected: _filter == _Filter.suspended,
                          onTap: () => setState(() => _filter =
                              _filter == _Filter.suspended
                                  ? _Filter.all
                                  : _Filter.suspended),
                        ),
                      ]),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: TextField(
                        onChanged: (v) => setState(() => _query = v),
                        decoration: const InputDecoration(
                          hintText: 'بحث بالاسم أو الهاتف أو رقم الروتر',
                          prefixIcon: Icon(Icons.search_rounded),
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
                      child: Row(children: [
                        _NetTab(
                          label: 'الكل',
                          color: AppColors.primary,
                          selected: _network == null,
                          onTap: () => setState(() => _network = null),
                        ),
                        const SizedBox(width: 8),
                        _NetTab(
                          label: Networks.fourji,
                          color: Networks.fourjiColor,
                          selected: _network == Networks.fourji,
                          onTap: () =>
                              setState(() => _network = Networks.fourji),
                        ),
                        const SizedBox(width: 8),
                        _NetTab(
                          label: Networks.netMarket,
                          color: Networks.netMarketColor,
                          selected: _network == Networks.netMarket,
                          onTap: () =>
                              setState(() => _network = Networks.netMarket),
                        ),
                      ]),
                    ),
                    Expanded(
                      child: RefreshIndicator(
                        onRefresh: _load,
                        child: list.isEmpty
                            ? ListView(
                                physics: const AlwaysScrollableScrollPhysics(),
                                children: [
                                  _EmptyState(hasData: _all.isNotEmpty),
                                ],
                              )
                            : ListView.separated(
                                physics: const AlwaysScrollableScrollPhysics(),
                                padding:
                                    const EdgeInsets.fromLTRB(16, 4, 16, 100),
                                itemCount: list.length,
                                separatorBuilder: (_, __) =>
                                    const SizedBox(height: 10),
                                itemBuilder: (_, i) => CustomerCard(
                                  customer: list[i],
                                  onTap: () => _openForm(list[i]),
                                ),
                              ),
                      ),
                    ),
                  ],
                ),
    );
  }
}

class _StatTile extends StatelessWidget {
  final String label, value;
  final IconData icon;
  final Color color;
  final bool selected;
  final VoidCallback onTap;

  const _StatTile({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: selected ? color.withValues(alpha: 0.14) : AppColors.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
                color: selected ? color : AppColors.border,
                width: selected ? 1.6 : 1),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(height: 8),
              Text(value,
                  style: const TextStyle(
                      fontSize: 22, fontWeight: FontWeight.w800)),
              Text(label,
                  style: const TextStyle(
                      color: AppColors.textMuted, fontSize: 12)),
            ],
          ),
        ),
      ),
    );
  }
}

class _NetTab extends StatelessWidget {
  final String label;
  final Color color;
  final bool selected;
  final VoidCallback onTap;

  const _NetTab({
    required this.label,
    required this.color,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          height: 40,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected ? color : color.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: color),
          ),
          child: Text(label,
              style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 13.5,
                  color: selected ? Colors.black : color)),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final bool hasData;
  const _EmptyState({required this.hasData});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 80),
      child: Column(
        children: [
          Icon(hasData ? Icons.search_off_rounded : Icons.router_outlined,
              size: 64, color: AppColors.textMuted),
          const SizedBox(height: 12),
          Text(
            hasData ? 'لا توجد نتائج مطابقة' : 'لا يوجد عملاء بعد',
            style: const TextStyle(
                color: AppColors.textMuted,
                fontSize: 16,
                fontWeight: FontWeight.w600),
          ),
          if (!hasData)
            const Padding(
              padding: EdgeInsets.only(top: 6),
              child: Text('اضغط "إضافة عميل" للبدء',
                  style: TextStyle(color: AppColors.textMuted)),
            ),
        ],
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ErrorState({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off_rounded,
                size: 64, color: AppColors.danger),
            const SizedBox(height: 14),
            Text(message,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 15, height: 1.5)),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('إعادة المحاولة'),
            ),
          ],
        ),
      ),
    );
  }
}
