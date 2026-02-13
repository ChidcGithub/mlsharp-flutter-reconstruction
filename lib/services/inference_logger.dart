import 'package:flutter/material.dart';

enum LogLevel { info, warning, error, success, debug }

class InferenceLogger extends ChangeNotifier {
  final List<Map<String, dynamic>> _logs = [];
  static const int maxLogs = 1000;

  void addLog(String message, {LogLevel level = LogLevel.info, dynamic error, StackTrace? stackTrace}) {
    final timestamp = DateTime.now().toString().split('.')[0];
    String prefix = '';
    
    switch (level) {
      case LogLevel.info: prefix = '[INFO]'; break;
      case LogLevel.warning: prefix = '[WARNING]'; break;
      case LogLevel.error: prefix = '[ERROR]'; break;
      case LogLevel.success: prefix = '[SUCCESS]'; break;
      case LogLevel.debug: prefix = '[DEBUG]'; break;
    }

    String fullMessage = '$prefix $message';
    if (error != null) {
      fullMessage += '\nException: $error';
    }
    if (stackTrace != null) {
      fullMessage += '\nStackTrace: $stackTrace';
    }

    _logs.add({
      'timestamp': timestamp,
      'message': message,
      'level': level,
      'fullText': '[$timestamp] $fullMessage',
      'error': error?.toString(),
    });
    
    if (_logs.length > maxLogs) {
      _logs.removeAt(0);
    }
    
    notifyListeners();
  }

  void clearLogs() {
    _logs.clear();
    notifyListeners();
  }

  List<Map<String, dynamic>> get logs => List.unmodifiable(_logs);

  String get allLogsText => _logs.map((l) => l['fullText']).join('\n');

  void info(String message) => addLog(message, level: LogLevel.info);
  void error(String message, {dynamic error, StackTrace? stackTrace}) => 
      addLog(message, level: LogLevel.error, error: error, stackTrace: stackTrace);
  void warning(String message) => addLog(message, level: LogLevel.warning);
  void success(String message) => addLog(message, level: LogLevel.success);
  void debug(String message) => addLog(message, level: LogLevel.debug);
}
