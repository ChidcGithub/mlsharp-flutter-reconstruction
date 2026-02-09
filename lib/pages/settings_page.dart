import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import '../providers/app_settings_provider.dart';
import '../services/inference_logger.dart';
import '../services/network_diagnostics_service.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  late TextEditingController _urlController;
  PackageInfo? _packageInfo;
  bool _isDiagnosing = false;
  DiagnosticResult? _diagnosticResult;

  final List<Color> _seedColors = [
    const Color(0xFF00A8E8), // 科技蓝
    const Color(0xFF7B2CBF), // 紫色
    const Color(0xFFE63946), // 红色
    const Color(0xFF2A9D8F), // 青色
    const Color(0xFFF4A261), // 橙色
    const Color(0xFF606C38), // 绿色
  ];

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

  Future<void> _runDiagnostics() async {
    setState(() {
      _isDiagnosing = true;
      _diagnosticResult = null;
    });

    final baseUrl = context.read<AppSettingsProvider>().backendUrl;
    final result = await NetworkDiagnosticsService().runFullDiagnostics(baseUrl);

    setState(() {
      _isDiagnosing = false;
      _diagnosticResult = result;
    });
  }

  Future<void> _exportLogs() async {
    try {
      final logger = context.read<InferenceLogger>();
      final logsText = logger.allLogsText;
      
      if (logsText.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('暂无日志可导出')),
        );
        return;
      }

      final timestamp = DateTime.now().toString().replaceAll(':', '-').split('.')[0].replaceAll(' ', '_');
      final fileName = 'mlsharp_logs_$timestamp.txt';

      // 方案：先写入临时文件，然后调用系统分享/保存
      final tempDir = await getTemporaryDirectory();
      final tempFile = File('${tempDir.path}/$fileName');
      await tempFile.writeAsString(logsText);

      final result = await Share.shareXFiles(
        [XFile(tempFile.path)],
        subject: 'MLSharp 3D Maker 日志导出',
      );

      if (result.status == ShareResultStatus.success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('日志导出/分享成功')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('导出失败: $e')),
        );
      }
    }
  }

  @override
  void dispose() {
    _urlController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('设置'),
        elevation: 0,
      ),
      body: Consumer<AppSettingsProvider>(
        builder: (context, settings, _) {
          return ListView(
            padding: const EdgeInsets.all(16.0),
            children: [
              // 外观设置卡片
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: colorScheme.primaryContainer,
                            ),
                            child: Icon(
                              Icons.palette,
                              color: colorScheme.onPrimaryContainer,
                            ),
                          ),
                          const SizedBox(width: 12),
                          const Text(
                            '外观',
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      SwitchListTile(
                        title: const Text('深色模式'),
                        subtitle: const Text('启用深色主题'),
                        value: settings.isDarkMode,
                        onChanged: (value) {
                          settings.setDarkMode(value);
                        },
                        contentPadding: EdgeInsets.zero,
                      ),
                      const Divider(),
                      SwitchListTile(
                        title: const Text('动态配色'),
                        subtitle: const Text('基于系统壁纸自动调整颜色 (Android 12+)'),
                        value: settings.useDynamicColor,
                        onChanged: (value) {
                          settings.setUseDynamicColor(value);
                        },
                        contentPadding: EdgeInsets.zero,
                      ),
                      if (!settings.useDynamicColor) ...[
                        const SizedBox(height: 12),
                        const Text(
                          '选择主题种子颜色',
                          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          height: 50,
                          child: ListView.separated(
                            scrollDirection: Axis.horizontal,
                            itemCount: _seedColors.length,
                            separatorBuilder: (context, index) => const SizedBox(width: 12),
                            itemBuilder: (context, index) {
                              final color = _seedColors[index];
                              final isSelected = settings.seedColor.value == color.value;
                              return GestureDetector(
                                onTap: () => settings.setSeedColor(color),
                                child: Container(
                                  width: 50,
                                  height: 50,
                                  decoration: BoxDecoration(
                                    color: color,
                                    shape: BoxShape.circle,
                                    border: isSelected
                                        ? Border.all(color: colorScheme.onSurface, width: 3)
                                        : null,
                                  ),
                                  child: isSelected
                                      ? const Icon(Icons.check, color: Colors.white)
                                      : null,
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // 连接设置卡片
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: colorScheme.secondaryContainer,
                            ),
                            child: Icon(
                              Icons.cloud_queue,
                              color: colorScheme.onSecondaryContainer,
                            ),
                          ),
                          const SizedBox(width: 12),
                          const Text(
                            '连接设置',
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: _urlController,
                        decoration: InputDecoration(
                          labelText: '后端服务器地址',
                          hintText: 'http://192.168.x.x:8000',
                          prefixIcon: const Icon(Icons.link),
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
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: colorScheme.primaryContainer.withOpacity(0.3),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '当前连接: ${settings.backendUrl}',
                          style: TextStyle(
                            fontSize: 12,
                            color: colorScheme.primary,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      const Divider(),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('网络诊断', style: TextStyle(fontWeight: FontWeight.bold)),
                          if (_isDiagnosing)
                            const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                          else
                            TextButton.icon(
                              onPressed: _runDiagnostics,
                              icon: const Icon(Icons.network_check, size: 18),
                              label: const Text('一键诊断'),
                            ),
                        ],
                      ),
                      if (_diagnosticResult != null) ...[
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: _diagnosticResult!.isConnected 
                                ? Colors.green.withOpacity(0.1) 
                                : Colors.orange.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: _diagnosticResult!.isConnected ? Colors.green : Colors.orange,
                              width: 0.5,
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    _diagnosticResult!.isConnected ? Icons.check_circle : Icons.warning,
                                    size: 16,
                                    color: _diagnosticResult!.isConnected ? Colors.green : Colors.orange,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    _diagnosticResult!.message,
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: _diagnosticResult!.isConnected ? Colors.green : Colors.orange,
                                    ),
                                  ),
                                  if (_diagnosticResult!.latency != null) ...[
                                    const Spacer(),
                                    Text('延迟: ${_diagnosticResult!.latency}ms', style: const TextStyle(fontSize: 12)),
                                  ],
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text('连接类型: ${_diagnosticResult!.connectionType}', style: const TextStyle(fontSize: 12)),
                              Text('VPN 状态: ${_diagnosticResult!.isVpnActive ? "已开启" : "未开启"}', style: const TextStyle(fontSize: 12)),
                              if (_diagnosticResult!.suggestions.isNotEmpty) ...[
                                const SizedBox(height: 8),
                                const Text('建议:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                                ..._diagnosticResult!.suggestions.map((s) => Padding(
                                  padding: const EdgeInsets.only(top: 2),
                                  child: Text('• $s', style: const TextStyle(fontSize: 11)),
                                )),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // 数据管理卡片
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: colorScheme.tertiaryContainer,
                            ),
                            child: Icon(
                              Icons.storage,
                              color: colorScheme.onTertiaryContainer,
                            ),
                          ),
                          const SizedBox(width: 12),
                          const Text(
                            '数据管理',
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      ListTile(
                        leading: const Icon(Icons.download),
                        title: const Text('导出日志'),
                        subtitle: const Text('选择位置保存应用日志文件'),
                        onTap: _exportLogs,
                        contentPadding: EdgeInsets.zero,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // 关于应用卡片
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: colorScheme.surfaceContainerHighest,
                            ),
                            child: Icon(
                              Icons.info_outline,
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(width: 12),
                          const Text(
                            '关于',
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      ListTile(
                        title: const Text('应用名称'),
                        subtitle: Text(_packageInfo?.appName ?? 'MLSharp 3D Maker'),
                        contentPadding: EdgeInsets.zero,
                      ),
                      ListTile(
                        title: const Text('版本号'),
                        subtitle: Text(_packageInfo?.version ?? '0.0.1'),
                        contentPadding: EdgeInsets.zero,
                      ),
                      const Divider(),
                      const ListTile(
                        title: Text('制作人'),
                        subtitle: Text('Chidc, Manus AI'),
                        contentPadding: EdgeInsets.zero,
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
