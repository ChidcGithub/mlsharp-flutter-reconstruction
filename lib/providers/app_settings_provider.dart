import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppSettingsProvider extends ChangeNotifier {
  late SharedPreferences _prefs;
  bool _isDarkMode = false;
  String _backendUrl = 'http://127.0.0.1:8000';
  
  bool get isDarkMode => _isDarkMode;
  String get backendUrl => _backendUrl;

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
    _isDarkMode = _prefs.getBool('isDarkMode') ?? false;
    _backendUrl = _prefs.getString('backendUrl') ?? 'http://127.0.0.1:8000';
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
}
