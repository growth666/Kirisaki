import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:kirisaki_app/core/theme/app_theme.dart';

void main() {
  test('双层字体：标题用快乐体、正文用思源黑体系', () {
    expect(
      AppTheme.light.textTheme.titleLarge?.fontFamily,
      AppFonts.title,
    );
    expect(
      AppTheme.light.textTheme.bodyMedium?.fontFamily,
      AppFonts.body,
    );
    // 全局默认正文体系 + 系统字体栈兜底（作用于具体样式）。
    expect(
      AppTheme.light.textTheme.bodyMedium?.fontFamily,
      AppFonts.body,
    );
    expect(
      AppTheme.light.textTheme.bodyMedium?.fontFamilyFallback,
      AppFonts.fallback,
    );
  });

  test('暗黑模式正文为浅灰（避免纯白高对比）', () {
    final TextStyle? darkBody = AppTheme.dark.textTheme.bodyMedium;
    expect(darkBody?.color, const Color(0xFFB8BCC4));
    // 亮色模式正文为常规 onSurface 87% 对比。
    expect(
      AppTheme.light.textTheme.bodyMedium?.color,
      AppTheme.light.colorScheme.onSurface.withValues(alpha: 0.87),
    );
  });

  test('正文常规字重（消除锐利感，非粗体）', () {
    expect(AppTheme.light.textTheme.bodyMedium?.fontWeight, FontWeight.w400);
    expect(AppTheme.light.textTheme.bodySmall?.fontWeight, FontWeight.w400);
  });

  test('AppBar 纯色不透明背景', () {
    expect(
      AppTheme.light.appBarTheme.backgroundColor,
      AppTheme.light.colorScheme.surface,
    );
  });
}
