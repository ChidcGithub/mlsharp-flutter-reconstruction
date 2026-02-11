import 'dart:convert';
import 'dart:io';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:flutter/foundation.dart';

enum ViewerType { threejs, gaussianSplatter, webview }

class HistoryItem {
  final String id;
  final String imageUrl;
  final String modelUrl;
  final String localModelPath;
  final DateTime timestamp;
  final String imageFileName;
  final ViewerType viewerType;

  HistoryItem({
    required this.id,
    required this.imageUrl,
    required this.modelUrl,
    required this.localModelPath,
    required this.timestamp,
    required this.imageFileName,
    this.viewerType = ViewerType.threejs, // 默认使用Three.js查看器
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'imageUrl': imageUrl,
      'modelUrl': modelUrl,
      'localModelPath': localModelPath,
      'timestamp': timestamp.toIso8601String(),
      'imageFileName': imageFileName,
      'viewerType': viewerType.toString().split('.').last, // 只保存枚举值名称
    };
  }

  factory HistoryItem.fromJson(Map<String, dynamic> json) {
    return HistoryItem(
      id: json['id'],
      imageUrl: json['imageUrl'],
      modelUrl: json['modelUrl'],
      localModelPath: json['localModelPath'],
      timestamp: DateTime.parse(json['timestamp']),
      imageFileName: json['imageFileName'],
      viewerType: _parseViewerType(json['viewerType'] ?? 'threejs'),
    );
  }

  static ViewerType _parseViewerType(String type) {
    switch (type) {
      case 'gaussianSplatter':
        return ViewerType.gaussianSplatter;
      case 'webview':
        return ViewerType.webview;
      case 'threejs':
      default:
        return ViewerType.threejs;
    }
  }
}

class HistoryService with ChangeNotifier {
  static const String _historyKey = 'history_items';
  static const String _modelsDir = 'model_history';

  late SharedPreferences _prefs;
  late String _modelsPath;

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
    final dir = await getApplicationDocumentsDirectory();
    _modelsPath = path.join(dir.path, _modelsDir);
    
    // 创建目录
    final modelDir = Directory(_modelsPath);
    if (!await modelDir.exists()) {
      await modelDir.create(recursive: true);
    }
  }

  Future<List<HistoryItem>> getHistory() async {
    final jsonList = _prefs.getStringList(_historyKey) ?? [];
    final items = jsonList
        .map((json) => HistoryItem.fromJson(jsonDecode(json)))
        .toList();
    
    // 按时间倒序排列（最新的在前）
    items.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    return items;
  }

  Future<void> reloadHistory() async {
    // 通知监听器数据已更改，这将触发UI重建
    notifyListeners();
  }

  Future<void> addToHistory(HistoryItem item) async {
    final history = await getHistory();
    
    // 检查是否已存在相同的项目（基于modelUrl）
    final existingIndex = history.indexWhere((h) => h.modelUrl == item.modelUrl);
    if (existingIndex != -1) {
      // 如果已存在，移除旧的
      history.removeAt(existingIndex);
    }
    
    // 添加新项目
    history.insert(0, item);
    
    // 限制历史记录数量（例如保留最近的50个）
    if (history.length > 50) {
      // 删除超出限制的项目并清理对应的本地文件
      for (int i = 50; i < history.length; i++) {
        try {
          final file = File(history[i].localModelPath);
          if (await file.exists()) {
            await file.delete();
          }
        } catch (e) {
          // 忽略删除失败的情况
        }
      }
      history.removeRange(50, history.length);
    }
    
    final jsonList = history.map((item) => jsonEncode(item.toJson())).toList();
    await _prefs.setStringList(_historyKey, jsonList);
  }

  Future<void> removeFromHistory(String id) async {
    final history = await getHistory();
    final index = history.indexWhere((h) => h.id == id);
    
    if (index != -1) {
      // 删除本地文件
      try {
        final file = File(history[index].localModelPath);
        if (await file.exists()) {
          await file.delete();
        }
      } catch (e) {
        // 忽略删除失败的情况
      }
      
      history.removeAt(index);
      final jsonList = history.map((item) => jsonEncode(item.toJson())).toList();
      await _prefs.setStringList(_historyKey, jsonList);
    }
  }

  Future<void> clearHistory() async {
    final history = await getHistory();
    
    // 删除所有本地模型文件
    for (final item in history) {
      try {
        final file = File(item.localModelPath);
        if (await file.exists()) {
          await file.delete();
        }
      } catch (e) {
        // 忽略删除失败的情况
      }
    }
    
    await _prefs.setStringList(_historyKey, []);
  }

  String getModelsPath() => _modelsPath;
}