import 'package:flutter/material.dart';

class InferenceLogger extends ChangeNotifier {
  final List<String> _logs = [];
  static const int maxLogs = 500;

  void addLog(String message) {
    final timestamp = DateTime.now().toString().split('.')[0];
    final logMessage = '[$timestamp] $message';
    
    _logs.add(logMessage);
    
    // 保持日志数量在合理范围内
    if (_logs.length > maxLogs) {
      _logs.removeAt(0);
    }
    
    notifyListeners();
  }

  void clearLogs() {
    _logs.clear();
    notifyListeners();
  }

  List<String> get logs => List.unmodifiable(_logs);

  String get allLogsText => _logs.join('\n');

  void addInfoLog(String message) => addLog('[INFO] $message');
  void addErrorLog(String message) => addLog('[ERROR] $message');
  void addWarningLog(String message) => addLog('[WARNING] $message');
  void addSuccessLog(String message) => addLog('[SUCCESS] $message');
}
