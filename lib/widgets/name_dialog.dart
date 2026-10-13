import 'package:flutter/material.dart';

import '../services/identity.dart';
import '../theme/app_theme.dart';

/// نافذة إدخال اسم العامل (يظهر للجميع في الإشعارات وسجل النشاط).
Future<void> askWorkerName(BuildContext context, {required bool required}) {
  final c = TextEditingController(text: Identity.name);
  return showDialog<void>(
    context: context,
    barrierDismissible: !required,
    builder: (ctx) => PopScope(
      canPop: !required,
      child: AlertDialog(
        backgroundColor: AppColors.surfaceHigh,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('اسمك'),
        content: TextField(
          controller: c,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'اكتب اسمك (يظهر للجميع عند أي تعديل)',
          ),
        ),
        actions: [
          if (!required)
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('إلغاء'),
            ),
          TextButton(
            onPressed: () async {
              if (c.text.trim().isEmpty) return;
              await Identity.setName(c.text);
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: const Text('حفظ'),
          ),
        ],
      ),
    ),
  );
}
