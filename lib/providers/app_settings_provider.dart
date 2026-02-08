import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppSettingsProvider extends ChangeNotifier {
  late SharedPreferences _prefs;
  bool _isDarkMode = false;
  String _backendUrl = 'http://127.0.0.1:8000';
  bool _onboardingCompleted = false;
  
  // 新增：种子颜色和动态配色开关
  Color _seedColor = const Color(0xFF00A8E8);
  bool _useDynamicColor = true;
  
  bool get isDarkMode => _isDarkMode;
  String get backendUrl => _backendUrl;
  bool get onboardingCompleted => _onboardingCompleted;
  Color get seedColor => _seedColor;
  bool get useDynamicColor => _useDynamicColor;

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
    _isDarkMode = _prefs.getBool('isDarkMode') ?? false;
    _backendUrl = _prefs.getString('backendUrl') ?? 'http://127.0.0.1:8000';
    _onboardingCompleted = _prefs.getBool('onboardingCompleted') ?? false;
    
    // 加载种子颜色
    final colorValue = _prefs.getInt('seedColor') ?? const Color(0xFF00A8E8).value;
    _seedColor = Color(colorValue);
    _useDynamicColor = _prefs.getBool('useDynamicColor') ?? true;
  }

  Future<void> setDarkMode(bool value) async {
    _isDarkMode = value;
    await _prefs.setBool('isDarkMode', value);
    notifyListeners();
  }

  Future<void> setBackendUrl(String url) async {
    _backendUrl = url;
    await _prefs.setString('backendUrl', url);
    notifyListeners();
  }

  Future<void> setOnboardingCompleted(bool value) async {
    _onboardingCompleted = value;
    await _prefs.setBool('onboardingCompleted', value);
    notifyListeners();
  }

  // 新增：设置种子颜色
  Future<void> setSeedColor(Color color) async {
    _seedColor = color;
    await _prefs.setInt('seedColor', color.value);
    notifyListeners();
  }

  // 新增：设置是否使用动态配色
  Future<void> setUseDynamicColor(bool value) async {
    _useDynamicColor = value;
    await _prefs.setBool('useDynamicColor', value);
    notifyListeners();
  }
}
