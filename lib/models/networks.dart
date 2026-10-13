import 'package:flutter/material.dart';

/// الشبكتان الثابتتان وألوانهما.
class Networks {
  static const fourji = 'فورجي';
  static const netMarket = 'نت ماركت';
  static const all = [fourji, netMarket];

  static const fourjiColor = Color(0xFF7DD3FC); // أزرق فاتح
  static const netMarketColor = Color(0xFFCA8A04); // أصفر غامق

  static Color? colorOf(String type) {
    switch (type.trim()) {
      case fourji:
        return fourjiColor;
      case netMarket:
        return netMarketColor;
    }
    return null;
  }
}
