import 'package:flutter/material.dart';

/// 全局字体常量（二次元双层字体方案）。
abstract final class AppFonts {
  /// 正文字体：思源黑体在线版（思源柔黑体系）。
  static const String body = 'Noto Sans SC';

  /// 标题/强调字体：站酷快乐体（提升二次元氛围）。
  static const String title = 'ZCOOL KuaiLe';

  /// 系统字体栈兜底（非 Web 平台或在线字体加载失败时）。
  static const List<String> fallback = <String>[
    'PingFang SC',
    'Microsoft YaHei',
    'sans-serif',
  ];
}

/// 全局主题配置（Kazumi 风格粉色系，Material 3）。
abstract final class AppTheme {
  /// 主题种子色。
  static const Color seedColor = Color(0xFFEC407A);

  /// 亮色主题。
  static final ThemeData light = _build(Brightness.light);

  /// 暗色主题。
  static final ThemeData dark = _build(Brightness.dark);

  static ThemeData _build(Brightness brightness) {
    final ColorScheme colorScheme = ColorScheme.fromSeed(
      seedColor: seedColor,
      brightness: brightness,
    );
    return ThemeData(
      colorScheme: colorScheme,
      // 双层字体：默认正文（思源黑体系），标题走 TextTheme 内快乐体；
      // 字体缺失时回退系统字体栈。
      fontFamily: AppFonts.body,
      fontFamilyFallback: AppFonts.fallback,
      textTheme: _buildTextTheme(colorScheme),
      appBarTheme: AppBarTheme(
        centerTitle: true,
        // 纯色不透明背景（无半透明效果）。
        backgroundColor: colorScheme.surface,
        foregroundColor: colorScheme.onSurface,
        elevation: 0,
        scrolledUnderElevation: 2,
        surfaceTintColor: Colors.transparent,
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: colorScheme.surface,
        indicatorColor: colorScheme.secondaryContainer,
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  /// 双层 TextTheme：
  /// - 标题/强调（titleLarge/titleMedium/headlineSmall/labelLarge）
  ///   使用站酷快乐体；
  /// - 正文（body*/labelMedium/labelSmall）使用思源黑体系 +
  ///   常规字重（w400/w500），消除锐利感；
  /// - 暗黑模式正文用浅灰，避免纯白高对比带来的锐利感。
  static TextTheme _buildTextTheme(ColorScheme colorScheme) {
    final bool isDark = colorScheme.brightness == Brightness.dark;
    // 正文颜色：亮色 onSurface 87% 常规对比；暗黑浅灰。
    final Color bodyColor = isDark
        ? const Color(0xFFB8BCC4)
        : colorScheme.onSurface.withValues(alpha: 0.87);

    final TextTheme base = ThemeData.light().textTheme;
    final TextStyle titleBase = TextStyle(
      fontFamily: AppFonts.title,
      color: colorScheme.onSurface,
      fontWeight: FontWeight.w700,
    );
    final TextStyle bodyBase = TextStyle(
      fontFamily: AppFonts.body,
      color: bodyColor,
      fontWeight: FontWeight.w400,
    );
    return base.copyWith(
      // —— 标题/强调：快乐体 ——
      headlineSmall: titleBase.copyWith(fontSize: 24),
      titleLarge: titleBase.copyWith(fontSize: 20),
      titleMedium: titleBase.copyWith(fontSize: 16, fontWeight: FontWeight.w500),
      titleSmall: titleBase.copyWith(fontSize: 14, fontWeight: FontWeight.w500),
      labelLarge: titleBase.copyWith(fontSize: 14, fontWeight: FontWeight.w500),
      // —— 正文：思源黑体系，常规字重 ——
      bodyLarge: bodyBase.copyWith(fontSize: 16, fontWeight: FontWeight.w500),
      bodyMedium: bodyBase.copyWith(fontSize: 14),
      bodySmall: bodyBase.copyWith(fontSize: 12),
      labelMedium: bodyBase.copyWith(fontSize: 12, fontWeight: FontWeight.w500),
      labelSmall: bodyBase.copyWith(fontSize: 11),
    );
  }
}
