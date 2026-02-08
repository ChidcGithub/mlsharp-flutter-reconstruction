import 'dart:async';
import 'dart:io';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dio/dio.dart';

class DiagnosticResult {
  final bool isConnected;
  final String connectionType;
  final int? latency;
  final bool isVpnActive;
  final String message;
  final List<String> suggestions;

  DiagnosticResult({
    required this.isConnected,
    required this.connectionType,
    this.latency,
    required this.isVpnActive,
    required this.message,
    required this.suggestions,
  });
}

class NetworkDiagnosticsService {
  final Dio _dio = Dio(BaseOptions(connectTimeout: const Duration(seconds: 3)));

  Future<DiagnosticResult> runFullDiagnostics(String baseUrl) async {
    bool isConnected = false;
    String connectionType = '未知';
    int? latency;
    bool isVpnActive = false;
    List<String> suggestions = [];

    // 1. 检查物理连接
    final connectivityResult = await Connectivity().checkConnectivity();
    if (connectivityResult == ConnectivityResult.mobile) {
      connectionType = '移动数据';
      suggestions.add('建议使用 WiFi 以获得更稳定的局域网连接');
    } else if (connectivityResult == ConnectivityResult.wifi) {
      connectionType = 'WiFi';
    } else if (connectivityResult == ConnectivityResult.none) {
      connectionType = '无网络';
      return DiagnosticResult(
        isConnected: false,
        connectionType: connectionType,
        isVpnActive: false,
        message: '未检测到网络连接',
        suggestions: ['请开启 WiFi 或移动数据'],
      );
    }

    // 2. 检查 VPN (通过检查网络接口名)
    try {
      final interfaces = await NetworkInterface.list();
      for (var interface in interfaces) {
        if (interface.name.contains('tun') || 
            interface.name.contains('ppp') || 
            interface.name.contains('tap')) {
          isVpnActive = true;
          break;
        }
      }
    } catch (_) {}

    if (isVpnActive) {
      suggestions.add('检测到 VPN 开启，这可能会拦截局域网连接，建议关闭后重试');
    }

    // 3. 测试后端连通性与延迟
    final stopwatch = Stopwatch()..start();
    try {
      final response = await _dio.get('$baseUrl/health');
      stopwatch.stop();
      if (response.statusCode == 200) {
        isConnected = true;
        latency = stopwatch.elapsedMilliseconds;
      }
    } catch (e) {
      stopwatch.stop();
      isConnected = false;
    }

    String message = isConnected ? '连接正常' : '无法连接到后端';
    if (!isConnected) {
      if (baseUrl.contains('127.0.0.1') || baseUrl.contains('localhost')) {
        suggestions.add('检测到使用了 127.0.0.1，请改为电脑的局域网 IP');
      }
      suggestions.add('请确保电脑端服务已启动 (python app.py)');
      suggestions.add('请确保手机和电脑在同一个 WiFi 网络下');
    }

    return DiagnosticResult(
      isConnected: isConnected,
      connectionType: connectionType,
      latency: latency,
      isVpnActive: isVpnActive,
      message: message,
      suggestions: suggestions,
    );
  }
}
