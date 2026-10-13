import 'package:flutter/material.dart';

import '../models/customer.dart';
import '../models/networks.dart';
import '../theme/app_theme.dart';

class CustomerCard extends StatelessWidget {
  final Customer customer;
  final VoidCallback onTap;

  const CustomerCard({super.key, required this.customer, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final active = customer.status == CustomerStatus.active;
    final statusColor = active ? AppColors.success : AppColors.warning;
    final typeColor = Networks.colorOf(customer.routerType);
    final hasRouter =
        customer.routerType.isNotEmpty || customer.routerNumber.isNotEmpty;

    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              CircleAvatar(
                radius: 26,
                backgroundColor: AppColors.primary.withValues(alpha: 0.15),
                child: Text(
                  customer.name.isNotEmpty ? customer.name.characters.first : '?',
                  style: const TextStyle(
                    color: AppColors.primary,
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      customer.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 4),
                    Row(children: [
                      const Icon(Icons.phone_rounded,
                          size: 14, color: AppColors.textMuted),
                      const SizedBox(width: 4),
                      Text(customer.phone,
                          style: const TextStyle(
                              color: AppColors.textMuted, fontSize: 13)),
                    ]),
                    if (hasRouter) ...[
                      const SizedBox(height: 2),
                      Row(children: [
                        const Icon(Icons.router_rounded,
                            size: 14, color: AppColors.textMuted),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text.rich(
                            TextSpan(children: [
                              if (customer.routerType.isNotEmpty)
                                TextSpan(
                                  text: customer.routerType,
                                  style: TextStyle(
                                    color: typeColor ?? AppColors.textMuted,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              if (customer.routerType.isNotEmpty &&
                                  customer.routerNumber.isNotEmpty)
                                const TextSpan(text: ' • '),
                              TextSpan(text: customer.routerNumber),
                            ]),
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                color: AppColors.textMuted, fontSize: 13),
                          ),
                        ),
                      ]),
                    ],
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      active ? 'نشط' : 'موقوف',
                      style: TextStyle(
                          color: statusColor,
                          fontSize: 12,
                          fontWeight: FontWeight.w700),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(customer.plan,
                      style: const TextStyle(
                          color: AppColors.primary,
                          fontSize: 12,
                          fontWeight: FontWeight.w600)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
