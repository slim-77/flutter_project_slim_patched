class Activity {
  final String id;
  final String actorId;
  final String actorName;
  final String action; // add | edit | delete
  final String customerName;
  final String details;
  final String createdAtRaw;
  final DateTime createdAt;

  const Activity({
    required this.id,
    required this.actorId,
    required this.actorName,
    required this.action,
    required this.customerName,
    required this.details,
    required this.createdAtRaw,
    required this.createdAt,
  });

  String get _who => actorName.isEmpty ? 'أحد العمال' : actorName;

  String get headline {
    switch (action) {
      case 'add':
        return '$_who أضاف عميلاً جديداً';
      case 'delete':
        return '$_who حذف عميلاً';
      default:
        return '$_who عدّل بيانات عميل';
    }
  }

  String get body =>
      details.isEmpty ? customerName : '$customerName • $details';

  factory Activity.fromJson(Map<String, dynamic> j) {
    final raw = j['created_at']?.toString() ?? '';
    return Activity(
      id: j['id'].toString(),
      actorId: j['actor_id'] as String? ?? '',
      actorName: j['actor_name'] as String? ?? '',
      action: j['action'] as String? ?? 'edit',
      customerName: j['customer_name'] as String? ?? '',
      details: j['details'] as String? ?? '',
      createdAtRaw: raw,
      createdAt: DateTime.tryParse(raw)?.toLocal() ?? DateTime.now(),
    );
  }
}
