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

/// 全局主题配置（Material 3）。
abstract final class AppTheme {
  /// 主题种子色。
  static const Color seedColor = Color(0xFFEC407A);
  static const double cardRadius = 16;
  static const double controlRadius = 12;
  static const double dialogRadius = 20;

  /// 亮色主题。
  static final ThemeData light = _build(Brightness.light, seedColor);

  /// 暗色主题。
  static final ThemeData dark = _build(Brightness.dark, seedColor);

  static ThemeData lightFor(Color seed) => _build(Brightness.light, seed);
  static ThemeData darkFor(Color seed) => _build(Brightness.dark, seed);

  static ThemeData _build(Brightness brightness, Color seed) {
    final ColorScheme generated = ColorScheme.fromSeed(
      seedColor: seed,
      brightness: brightness,
    );
    final ColorScheme colorScheme = generated;
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
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        elevation: 0,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(cardRadius),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: colorScheme.surfaceContainer,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 13,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(controlRadius),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(controlRadius),
          borderSide: BorderSide(color: colorScheme.outlineVariant),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(controlRadius),
          borderSide: BorderSide(color: colorScheme.primary, width: 2),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(controlRadius),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(controlRadius),
          ),
        ),
      ),
      dialogTheme: DialogThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(dialogRadius),
        ),
      ),
      listTileTheme: ListTileThemeData(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        minVerticalPadding: 8,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: colorScheme.surface,
        indicatorColor: colorScheme.secondaryContainer,
      ),
      chipTheme: ChipThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(controlRadius),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(controlRadius),
        ),
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
      titleMedium: titleBase.copyWith(
        fontSize: 16,
        fontWeight: FontWeight.w500,
      ),
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
