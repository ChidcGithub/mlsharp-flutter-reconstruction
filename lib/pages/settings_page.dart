import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import '../providers/app_settings_provider.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  late TextEditingController _urlController;
  PackageInfo? _packageInfo;

  @override
  void initState() {
    super.initState();
    _urlController = TextEditingController(
      text: context.read<AppSettingsProvider>().backendUrl,
    );
    _loadPackageInfo();
  }

  Future<void> _loadPackageInfo() async {
    final info = await PackageInfo.fromPlatform();
    setState(() {
      _packageInfo = info;
    });
  }

  Future<void> _exportLogs() async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final logFile = File('${directory.path}/mlsharp_logs.txt');
      
      final timestamp = DateTime.now().toString();
      final logContent = '''
MLSharp 3D Maker - 应用日志
生成时间: $timestamp
应用版本: ${_packageInfo?.version}
构建号: ${_packageInfo?.buildNumber}
包名: ${_packageInfo?.packageName}

--- 系统信息 ---
设备: ${_packageInfo?.appName}

--- 日志内容 ---
这是一个示例日志文件。
实际的日志内容应该由应用的日志系统填充。
''';

      await logFile.writeAsString(logContent);
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('日志已导出到: ${logFile.path}')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('导出失败: $e')),
      );
    }
  }

  @override
  void dispose() {
    _urlController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('设置'),
      ),
      body: Consumer<AppSettingsProvider>(
        builder: (context, settings, _) {
          return ListView(
            padding: const EdgeInsets.all(16.0),
            children: [
              // 主题设置
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        '外观',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 16),
                      SwitchListTile(
                        title: const Text('深色模式'),
                        subtitle: const Text('启用深色主题'),
                        value: settings.isDarkMode,
                        onChanged: (value) {
                          settings.setDarkMode(value);
                        },
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // 连接设置
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        '连接设置',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: _urlController,
                        decoration: InputDecoration(
                          labelText: '后端服务器地址',
                          hintText: 'http://127.0.0.1:8000',
                          border: const OutlineInputBorder(),
                          suffixIcon: IconButton(
                            icon: const Icon(Icons.check),
                            onPressed: () {
                              settings.setBackendUrl(_urlController.text);
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('连接地址已保存')),
                              );
                            },
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        '当前连接: ${settings.backendUrl}',
                        style: const TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // 数据管理
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        '数据管理',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 16),
                      ListTile(
                        leading: const Icon(Icons.download),
                        title: const Text('导出日志'),
                        subtitle: const Text('导出应用日志文件'),
                        onTap: _exportLogs,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // 关于应用
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        '关于',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 16),
                      ListTile(
                        title: const Text('应用名称'),
                        subtitle: Text(_packageInfo?.appName ?? '加载中...'),
                      ),
                      ListTile(
                        title: const Text('版本号'),
                        subtitle: Text(_packageInfo?.version ?? '加载中...'),
                      ),
                      ListTile(
                        title: const Text('构建号'),
                        subtitle: Text(_packageInfo?.buildNumber ?? '加载中...'),
                      ),
                      const Divider(),
                      ListTile(
                        title: const Text('包名'),
                        subtitle: Text(_packageInfo?.packageName ?? '加载中...'),
                        isThreeLine: true,
                      ),
                      const Divider(),
                      const ListTile(
                        title: Text('制作人'),
                        subtitle: Text('Chidc, Manus AI'),
                      ),
                      const ListTile(
                        title: Text('项目描述'),
                        subtitle: Text('MLSharp 3D Maker - 基于 Flutter 的 3D 高斯泼溅生成工具，针对 Snapdragon GPU 优化'),
                        isThreeLine: true,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 32),
            ],
          );
        },
      ),
    );
  }
}
