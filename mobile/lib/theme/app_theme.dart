// mobile/lib/theme/app_theme.dart
//
// 集中的設計系統（原本散落各頁的 inline Color(0xFF...) 收斂於此）。
// 維持既有 dark 視覺：主色 Spotify 綠 #1DB954、背景 #121212、表面 #1E1E1E/#2A2A2A。
// 刻意單一 dark 主題（不做 light/切換）。

import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  // 品牌 / 背景 / 表面
  static const Color primary = Color(0xFF1DB954);
  static const Color primaryInk = Colors.black; // 綠底上的字
  static const Color background = Color(0xFF121212);
  static const Color surface1 = Color(0xFF1E1E1E);
  static const Color surface2 = Color(0xFF2A2A2A);
  static const Color border = Color(0xFF404040);

  // 文字
  static const Color textPrimary = Colors.white;
  static const Color textSecondary = Color(0xFFB3B3B3);
  static const Color textMuted = Color(0xFF808080);

  // 語意色（與 primary 分離）
  static const Color success = Color(0xFF1DB954);
  static const Color warning = Color(0xFFFFB84D);
  static const Color danger = Color(0xFFE5484D);
  static const Color info = Color(0xFF3B82F6);
}

class AppTheme {
  AppTheme._();

  static ThemeData dark() {
    const scheme = ColorScheme.dark(
      primary: AppColors.primary,
      onPrimary: AppColors.primaryInk,
      surface: AppColors.surface1,
      onSurface: AppColors.textPrimary,
      error: AppColors.danger,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: AppColors.background,
      primaryColor: AppColors.primary,
      colorScheme: scheme,
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        elevation: 2,
      ),
      cardTheme: CardThemeData(
        color: AppColors.surface1,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: const BorderSide(color: AppColors.border, width: 1),
        ),
        margin: const EdgeInsets.symmetric(vertical: 6),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: AppColors.surface1,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        titleTextStyle: const TextStyle(
          color: AppColors.textPrimary, fontSize: 20, fontWeight: FontWeight.bold),
        contentTextStyle: const TextStyle(color: AppColors.textSecondary, fontSize: 15),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surface2,
        hintStyle: const TextStyle(color: AppColors.textMuted),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.primary, width: 2),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: AppColors.primaryInk,
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
      textTheme: const TextTheme(
        bodyMedium: TextStyle(color: AppColors.textPrimary),
        bodySmall: TextStyle(color: AppColors.textSecondary),
        titleMedium: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold),
        titleLarge: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold),
      ),
    );
  }
}

/// 狀態徽章（行程 / 支付 / 爭議狀態），語意色。
class StatusPill extends StatelessWidget {
  final String label;
  final Color color;
  final IconData? icon;

  const StatusPill({super.key, required this.label, required this.color, this.icon});

  /// 依 payment_status（pending/locked/released/refunded/failed）配色
  factory StatusPill.payment(String status) {
    switch (status) {
      case 'locked':
        return const StatusPill(label: '已鎖定託管', color: AppColors.info, icon: Icons.lock);
      case 'released':
        return const StatusPill(label: '已放款', color: AppColors.success, icon: Icons.check_circle);
      case 'refunded':
        return const StatusPill(label: '已退款', color: AppColors.warning, icon: Icons.undo);
      case 'failed':
        return const StatusPill(label: '金流失敗', color: AppColors.danger, icon: Icons.error);
      default:
        return const StatusPill(label: '待付款', color: AppColors.textMuted, icon: Icons.schedule);
    }
  }

  /// 依 trip.status 配色（含 disputed）
  factory StatusPill.trip(String status) {
    switch (status) {
      case 'disputed':
        return const StatusPill(label: '爭議中（凍結）', color: AppColors.warning, icon: Icons.gavel);
      case 'completed':
        return const StatusPill(label: '已完成', color: AppColors.success, icon: Icons.check_circle);
      case 'cancelled':
        return const StatusPill(label: '已取消', color: AppColors.danger, icon: Icons.cancel);
      case 'in_progress':
        return const StatusPill(label: '行程中', color: AppColors.info, icon: Icons.directions_car);
      case 'picked_up':
        return const StatusPill(label: '已上車', color: AppColors.info, icon: Icons.person_pin_circle);
      case 'accepted':
        return const StatusPill(label: '已接單', color: AppColors.primary, icon: Icons.how_to_reg);
      case 'matched':
        return const StatusPill(label: '已配對', color: AppColors.primary, icon: Icons.link);
      default:
        return const StatusPill(label: '等待中', color: AppColors.textMuted, icon: Icons.schedule);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[Icon(icon, size: 14, color: color), const SizedBox(width: 5)],
          Text(label, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}
