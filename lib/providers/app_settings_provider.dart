import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppSettingsProvider extends ChangeNotifier {
  late SharedPreferences _prefs;
  bool _isDarkMode = false;
  String _backendUrl = 'http://127.0.0.1:8000';
  bool _onboardingCompleted = false;
  
  bool get isDarkMode => _isDarkMode;
  String get backendUrl => _backendUrl;
  bool get onboardingCompleted => _onboardingCompleted;

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
    _isDarkMode = _prefs.getBool('isDarkMode') ?? false;
    _backendUrl = _prefs.getString('backendUrl') ?? 'http://127.0.0.1:8000';
    _onboardingCompleted = _prefs.getBool('onboardingCompleted') ?? false;
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
}
