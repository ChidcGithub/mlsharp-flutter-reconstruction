import 'package:flutter/material.dart';

class AppTheme {
  // 默认品牌色彩定义
  static const Color defaultSeedColor = Color(0xFF00A8E8); // 科技蓝

  static ThemeData theme(ColorScheme? dynamicColorScheme, Brightness brightness) {
    final colorScheme = dynamicColorScheme ??
        ColorScheme.fromSeed(
          seedColor: defaultSeedColor,
          brightness: brightness,
        );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      
      // AppBar 样式优化
      appBarTheme: AppBarTheme(
        elevation: 0,
        centerTitle: true,
        backgroundColor: colorScheme.surface,
        foregroundColor: colorScheme.primary,
        titleTextStyle: TextStyle(
          color: colorScheme.primary,
          fontSize: 20,
          fontWeight: FontWeight.w600,
        ),
      ),
      
      // 卡片样式优化
      cardTheme: CardThemeData(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(
            color: colorScheme.outlineVariant.withOpacity(0.5),
            width: 1,
          ),
        ),
        color: colorScheme.surfaceContainerLow,
      ),
      
      // 按钮样式优化
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          backgroundColor: colorScheme.primary,
          foregroundColor: colorScheme.onPrimary,
        ),
      ),
      
      // 输入框样式优化
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: colorScheme.surfaceContainerHighest.withOpacity(0.3),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: colorScheme.outline),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: colorScheme.outlineVariant),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: colorScheme.primary, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
      
      // 导航栏样式优化
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: colorScheme.surface,
        indicatorColor: colorScheme.secondaryContainer,
        labelTextStyle: WidgetStateProperty.all(
          TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: colorScheme.onSurface),
        ),
      ),
    );
  }

  // 保留旧方法以兼容，但内部调用新逻辑
  static ThemeData lightTheme({ColorScheme? colorScheme}) => theme(colorScheme, Brightness.light);
  static ThemeData darkTheme({ColorScheme? colorScheme}) => theme(colorScheme, Brightness.dark);
}
