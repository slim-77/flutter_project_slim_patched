enum CustomerStatus { active, suspended }

class Customer {
  final String id;
  final String name;
  final String phone;
  final String address;
  final String routerNumber;
  final String routerType;
  final String locationUrl;
  final String plan;
  final CustomerStatus status;
  final String notes;
  final DateTime createdAt;

  const Customer({
    required this.id,
    required this.name,
    required this.phone,
    this.address = '',
    this.routerNumber = '',
    this.routerType = '',
    this.locationUrl = '',
    this.plan = '10 Mbps',
    this.status = CustomerStatus.active,
    this.notes = '',
    required this.createdAt,
  });

  /// الحقول المرسلة إلى Supabase (بدون id و created_at، فالسيرفر يولدهما).
  Map<String, dynamic> toJson() => {
        'name': name,
        'phone': phone,
        'address': address,
        'router_number': routerNumber,
        'router_type': routerType,
        'location_url': locationUrl,
        'plan': plan,
        'status': status.name,
        'notes': notes,
      };

  factory Customer.fromJson(Map<String, dynamic> j) => Customer(
        id: j['id'].toString(),
        name: j['name'] as String? ?? '',
        phone: j['phone'] as String? ?? '',
        address: j['address'] as String? ?? '',
        routerNumber: j['router_number'] as String? ?? '',
        routerType: j['router_type'] as String? ?? '',
        locationUrl: j['location_url'] as String? ?? '',
        plan: j['plan'] as String? ?? '10 Mbps',
        status: CustomerStatus.values.firstWhere(
          (s) => s.name == j['status'],
          orElse: () => CustomerStatus.active,
        ),
        notes: j['notes'] as String? ?? '',
        createdAt: DateTime.tryParse(j['created_at']?.toString() ?? '')
                ?.toLocal() ??
            DateTime.now(),
      );
}
