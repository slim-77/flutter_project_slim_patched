import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/customer.dart';
import '../models/networks.dart';
import '../services/activity_repository.dart';
import '../services/customer_repository.dart';
import '../theme/app_theme.dart';

/// يحوّل الأرقام العربية (٠١٢) إلى لاتينية ويحذف أي حرف غير رقم.
class _DigitsOnlyFormatter extends TextInputFormatter {
  static const _arabic = '٠١٢٣٤٥٦٧٨٩';

  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue, TextEditingValue newValue) {
    final buf = StringBuffer();
    for (final ch in newValue.text.split('')) {
      final i = _arabic.indexOf(ch);
      if (i >= 0) {
        buf.write(i);
      } else if (RegExp(r'[0-9]').hasMatch(ch)) {
        buf.write(ch);
      }
    }
    final t = buf.toString();
    return TextEditingValue(
      text: t,
      selection: TextSelection.collapsed(offset: t.length),
    );
  }
}

class CustomerFormScreen extends StatefulWidget {
  final Customer? customer;
  final CustomerRepository repo;
  final List<String> knownTypes;
  const CustomerFormScreen({
    super.key,
    this.customer,
    required this.repo,
    this.knownTypes = const [],
  });

  @override
  State<CustomerFormScreen> createState() => _CustomerFormScreenState();
}

class _CustomerFormScreenState extends State<CustomerFormScreen> {
  static const _plans = ['5 Mbps', '10 Mbps', '20 Mbps', '50 Mbps', '100 Mbps'];
  static const _phoneLength = 9;

  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name,
      _phone,
      _address,
      _routerNumber,
      _routerType,
      _location;
  late String _plan;
  late CustomerStatus _status;
  bool _busy = false;

  bool get _isEdit => widget.customer != null;

  @override
  void initState() {
    super.initState();
    final c = widget.customer;
    _name = TextEditingController(text: c?.name);
    _phone = TextEditingController(text: c?.phone);
    _address = TextEditingController(text: c?.address);
    _routerNumber = TextEditingController(text: c?.routerNumber);
    _routerType = TextEditingController(text: c?.routerType);
    _location = TextEditingController(text: c?.locationUrl);
    _plan = c?.plan ?? _plans[1];
    if (!_plans.contains(_plan)) _plan = _plans[1];
    _status = c?.status ?? CustomerStatus.active;
  }

  @override
  void dispose() {
    for (final t in [
      _name,
      _phone,
      _address,
      _routerNumber,
      _routerType,
      _location,
    ]) {
      t.dispose();
    }
    super.dispose();
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _busy = true);
    try {
      final c = Customer(
        id: widget.customer?.id ?? '',
        name: _name.text.trim(),
        phone: _phone.text.trim(),
        address: _address.text.trim(),
        routerNumber: _routerNumber.text.trim(),
        routerType: _routerType.text.trim(),
        locationUrl: _location.text.trim(),
        plan: _plan,
        status: _status,
        notes: widget.customer?.notes ?? '',
        createdAt: widget.customer?.createdAt ?? DateTime.now(),
      );
      if (_isEdit) {
        await widget.repo.update(c);
      } else {
        await widget.repo.insert(c);
      }
      // تسجيل النشاط ليراه الجميع (فشله لا يمنع الحفظ)
      try {
        await ActivityRepository().log(
          action: _isEdit ? 'edit' : 'add',
          customerName: c.name,
          details: '${_isEdit ? _changes(widget.customer!, c) : 'إضافة عميل'} | رقم الهاتف: ${c.phone} | رقم المودم: ${c.routerNumber.isEmpty ? '—' : c.routerNumber} | الشبكة: ${c.routerType.isEmpty ? '—' : c.routerType} | الحالة: ${c.status == CustomerStatus.active ? 'نشط' : 'موقوف'}',
        );
      } catch (_) {}
      if (!mounted) return;
      Navigator.of(context)
          .pop(_isEdit ? 'تم حفظ التعديلات' : 'تمت إضافة العميل');
    } catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      _snack(friendlyError(e));
    }
  }

  /// وصف مختصر للحقول التي تغيّرت (يظهر في الإشعار وسجل النشاط).
  String _changes(Customer o, Customer n) {
    final parts = <String>[];
    String v(String x) => x.isEmpty ? '—' : x;
    void diff(String label, String a, String b, {bool values = true}) {
      if (a == b) return;
      parts.add(values ? '$label: من ${v(a)} إلى ${v(b)}' : label);
    }

    String st(CustomerStatus s) => s == CustomerStatus.active ? 'نشط' : 'موقوف';
    diff('الاسم', o.name, n.name);
    diff('الهاتف', o.phone, n.phone);
    diff('العنوان', o.address, n.address);
    diff('رقم الروتر', o.routerNumber, n.routerNumber);
    diff('الشبكة', o.routerType, n.routerType);
    diff('الموقع', o.locationUrl, n.locationUrl, values: false);
    diff('الباقة', o.plan, n.plan);
    diff('الحالة', st(o.status), st(n.status));
    return parts.isEmpty ? 'بدون تغيير' : parts.join('، ');
  }

  Future<void> _confirmDelete() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surfaceHigh,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('حذف العميل؟'),
        content: Text('سيتم حذف "${widget.customer!.name}" نهائياً.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('إلغاء')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('حذف',
                  style: TextStyle(color: AppColors.danger))),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    setState(() => _busy = true);
    try {
      await widget.repo.delete(widget.customer!.id);
      try {
        await ActivityRepository()
            .log(action: 'delete', customerName: widget.customer!.name, details: 'رقم الهاتف: ${widget.customer!.phone} | رقم المودم: ${widget.customer!.routerNumber.isEmpty ? '—' : widget.customer!.routerNumber} | الشبكة: ${widget.customer!.routerType.isEmpty ? '—' : widget.customer!.routerType}');
      } catch (_) {}
      if (!mounted) return;
      Navigator.of(context).pop('تم حذف العميل');
    } catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      _snack(friendlyError(e));
    }
  }

  Future<void> _openUrl(String url) async {
    try {
      final ok = await launchUrl(Uri.parse(url),
          mode: LaunchMode.externalApplication);
      if (!ok) _snack('تعذر فتح الرابط');
    } catch (_) {
      _snack('تعذر فتح الرابط');
    }
  }

  Future<void> _pasteLocation() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final text = data?.text?.trim() ?? '';
    if (text.isEmpty) {
      _snack('لا يوجد رابط منسوخ');
      return;
    }
    setState(() => _location.text = text);
  }

  String? _requiredName(String? v) =>
      (v == null || v.trim().isEmpty) ? 'أدخل اسم العميل' : null;

  String? _validatePhone(String? v) {
    final t = (v ?? '').trim();
    if (t.isEmpty) return 'أدخل رقم الهاتف';
    if (t.length != _phoneLength) {
      return 'رقم الهاتف يجب أن يكون $_phoneLength أرقام بالضبط (الحالي: ${t.length})';
    }
    return null;
  }

  String? _validateLocation(String? v) {
    final t = (v ?? '').trim();
    if (t.isEmpty) return null;
    if (!t.startsWith('http://') && !t.startsWith('https://')) {
      return 'الرابط يجب أن يبدأ بـ http أو https';
    }
    return null;
  }

  Widget _section(String title, IconData icon) => Padding(
        padding: const EdgeInsets.only(top: 14, bottom: 8),
        child: Row(children: [
          Icon(icon, size: 18, color: AppColors.primary),
          const SizedBox(width: 8),
          Text(title,
              style: const TextStyle(
                  fontSize: 14,
                  letterSpacing: 1.2,
                  fontWeight: FontWeight.w800,
                  color: AppColors.primary)),
        ]),
      );

  OutlineInputBorder _phoneBorder(Color c, double w) => OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: c, width: w),
      );

  /// لون إطار الهاتف: أصفر إذا ناقص، أحمر إذا زاد، الأصلي عند 9 أو فارغ.
  InputDecoration _phoneDecoration() {
    final len = _phone.text.length;
    Color? c;
    if (len > _phoneLength) {
      c = AppColors.danger;
    } else if (len > 0 && len < _phoneLength) {
      c = AppColors.warning;
    }
    if (c == null) return const InputDecoration(labelText: 'رقم الهاتف');
    return InputDecoration(
      labelText: 'رقم الهاتف',
      enabledBorder: _phoneBorder(c, 1.8),
      focusedBorder: _phoneBorder(c, 2.2),
      errorBorder: _phoneBorder(c, 1.8),
      focusedErrorBorder: _phoneBorder(c, 2.2),
    );
  }

  Widget _networkChip(String name, Color color) {
    final sel = _routerType.text.trim() == name;
    return GestureDetector(
      onTap: () => setState(() => _routerType.text = sel ? '' : name),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: sel ? color : color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color),
        ),
        child: Text(name,
            style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: sel ? Colors.black : color)),
      ),
    );
  }

  Widget _statusSeg({
    required CustomerStatus value,
    required String label,
    required IconData icon,
    required Color color,
    required bool alwaysTinted,
  }) {
    final sel = _status == value;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _status = value),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          height: 46,
          decoration: BoxDecoration(
            color: sel ? color.withValues(alpha: 0.2) : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
                color: (sel || alwaysTinted)
                    ? color
                    : color.withValues(alpha: 0.35),
                width: sel ? 1.8 : 1.2),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 18, color: color),
              const SizedBox(width: 6),
              Text(label,
                  style: TextStyle(color: color, fontWeight: FontWeight.w700)),
            ],
          ),
        ),
      ),
    );
  }

  ButtonStyle get _toolButtonStyle => OutlinedButton.styleFrom(
        foregroundColor: AppColors.primary,
        side: const BorderSide(color: AppColors.primary),
        minimumSize: const Size.fromHeight(46),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEdit ? 'EDIT CLIENT' : 'NEW CLIENT'),
        actions: [
          if (_isEdit)
            IconButton(
              tooltip: 'حذف',
              onPressed: _busy ? null : _confirmDelete,
              icon: const Icon(Icons.delete_outline_rounded,
                  color: AppColors.danger),
            ),
        ],
      ),
      body: AbsorbPointer(
        absorbing: _busy,
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
            children: [
              _section('ENTER CLIENT DETAILS', Icons.person_rounded),
              TextFormField(
                controller: _name,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(labelText: 'الاسم الكامل'),
                validator: _requiredName,
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _phone,
                keyboardType: TextInputType.number,
                textInputAction: TextInputAction.next,
                textAlign: TextAlign.start,
                inputFormatters: [
                  _DigitsOnlyFormatter(),
                  LengthLimitingTextInputFormatter(15),
                ],
                onChanged: (_) => setState(() {}),
                decoration: _phoneDecoration(),
                validator: _validatePhone,
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _address,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(labelText: 'العنوان'),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _routerNumber,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(labelText: 'رقم الروتر'),
              ),
              const SizedBox(height: 8),
              InputDecorator(
                isEmpty: false,
                decoration: const InputDecoration(
                  labelText: 'نوع الروتر',
                  contentPadding:
                      EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                ),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    _networkChip(Networks.fourji, Networks.fourjiColor),
                    _networkChip(Networks.netMarket, Networks.netMarketColor),
                    // قيمة قديمة مخزنة لا تطابق الشبكتين
                    if (_routerType.text.trim().isNotEmpty &&
                        !Networks.all.contains(_routerType.text.trim()))
                      _networkChip(_routerType.text.trim(), AppColors.primary),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _location,
                keyboardType: TextInputType.url,
                textDirection: TextDirection.ltr,
                decoration: const InputDecoration(
                  labelText: 'رابط الموقع',
                  helperMaxLines: 3,
                  helperText:
                      'افتح خرائط قوقل وحدّد الموقع، ثم اضغط مشاركة وانسخ الرابط، وارجع واضغط "لصق الرابط"',
                ),
                validator: _validateLocation,
              ),
              const SizedBox(height: 8),
              Row(children: [
                Expanded(
                  child: OutlinedButton.icon(
                    style: _toolButtonStyle,
                    onPressed: () => _openUrl('https://www.google.com/maps'),
                    icon: const Icon(Icons.map_rounded),
                    label: const Text('خرائط قوقل'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    style: _toolButtonStyle,
                    onPressed: _pasteLocation,
                    icon: const Icon(Icons.content_paste_rounded),
                    label: const Text('لصق الرابط'),
                  ),
                ),
              ]),
              ValueListenableBuilder<TextEditingValue>(
                valueListenable: _location,
                builder: (_, value, __) {
                  final url = value.text.trim();
                  final valid = url.startsWith('http://') ||
                      url.startsWith('https://');
                  if (!valid) return const SizedBox.shrink();
                  return Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: OutlinedButton.icon(
                      style: _toolButtonStyle,
                      onPressed: () => _openUrl(url),
                      icon: const Icon(Icons.location_on_rounded),
                      label: const Text('عرض الموقع على الخريطة'),
                    ),
                  );
                },
              ),
              _section('الاشتراك', Icons.speed_rounded),
              DropdownButtonFormField<String>(
                value: _plan,
                dropdownColor: AppColors.surfaceHigh,
                decoration: const InputDecoration(labelText: 'الباقة'),
                items: _plans
                    .map((p) => DropdownMenuItem(value: p, child: Text(p)))
                    .toList(),
                onChanged: (v) => setState(() => _plan = v!),
              ),
              const SizedBox(height: 8),
              Row(children: [
                _statusSeg(
                  value: CustomerStatus.active,
                  label: 'نشط',
                  icon: Icons.wifi_rounded,
                  color: AppColors.primary,
                  alwaysTinted: false,
                ),
                const SizedBox(width: 10),
                _statusSeg(
                  value: CustomerStatus.suspended,
                  label: 'موقوف',
                  icon: Icons.wifi_off_rounded,
                  color: AppColors.warning,
                  alwaysTinted: true,
                ),
              ]),
              const SizedBox(height: 20),
              FilledButton.icon(
                onPressed: _busy ? null : _save,
                icon: _busy
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                            strokeWidth: 2.5, color: Colors.black),
                      )
                    : const Icon(Icons.check_rounded),
                label: const Text('Save'),
              ),
              if (_isEdit) ...[
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: _busy ? null : _confirmDelete,
                  icon: const Icon(Icons.delete_outline_rounded),
                  label: const Text('حذف العميل'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
