import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:model_viewer_plus/model_viewer_plus.dart';
import 'package:flutter_gaussian_splatter/widgets/gaussian_splatter_widget.dart';
import '../services/history_service.dart';
import '../services/inference_logger.dart';
import 'package:http/http.dart' as http;
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;

class HistoryPage extends StatefulWidget {
  const HistoryPage({super.key});

  @override
  State<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends State<HistoryPage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('历史记录'),
        elevation: 0,
      ),
      body: _buildHistoryList(),
    );
  }

  Widget _buildHistoryList() {
    return Consumer<HistoryService>(
      builder: (context, historyService, child) {
        return RefreshIndicator(
          onRefresh: () async {
            // 刷新历史记录列表
            if (mounted) {
              setState(() {});
            }
          },
          child: FutureBuilder<List<HistoryItem>>(
            future: historyService.getHistory(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              if (snapshot.hasError) {
                return Center(child: Text('加载历史记录出错: ${snapshot.error}'));
              }

              final historyItems = snapshot.data ?? [];

              if (historyItems.isEmpty) {
                return const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.history,
                        size: 64,
                        color: Colors.grey,
                      ),
                      SizedBox(height: 16),
                      Text(
                        '暂无历史记录',
                        style: TextStyle(fontSize: 16, color: Colors.grey),
                      ),
                      SizedBox(height: 8),
                      Text(
                        '生成3D模型后将在这里显示',
                        style: TextStyle(fontSize: 14, color: Colors.grey),
                      ),
                    ],
                  ),
                );
              }

              return ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: historyItems.length,
                itemBuilder: (context, index) {
                  final item = historyItems[index];
                  return _buildHistoryItemCard(item);
                },
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildHistoryItemCard(HistoryItem item) {
    final colorScheme = Theme.of(context).colorScheme;
    
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () => _viewHistoryItem(item),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 缩略图或图标
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.auto_awesome,
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: 12),
              // 详细信息
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.imageFileName,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '生成时间: ${_formatDateTime(item.timestamp)}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.grey,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '格式: ${_getModelFormat(item.modelUrl)}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.grey,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              // 操作按钮
              PopupMenuButton<String>(
                onSelected: (value) => _handleMenuSelection(value, item),
                itemBuilder: (context) => [
                  const PopupMenuItem(
                    value: 'view',
                    child: Text('查看'),
                  ),
                  const PopupMenuItem(
                    value: 'delete',
                    child: Text('删除'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _getModelFormat(String modelUrl) {
    final extension = modelUrl.split('.').last.toLowerCase();
    switch (extension) {
      case 'ply':
        return 'PLY';
      case 'glb':
        return 'GLB';
      case 'gltf':
        return 'GLTF';
      default:
        return extension.toUpperCase();
    }
  }

  String _formatDateTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inDays > 0) {
      return '${difference.inDays}天前';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}小时前';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}分钟前';
    } else {
      return '刚刚';
    }
  }

  void _viewHistoryItem(HistoryItem item) {
    // 导航到3D模型查看页面
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => HistoryItemViewer(historyItem: item),
      ),
    );
  }

  void _handleMenuSelection(String value, HistoryItem item) {
    switch (value) {
      case 'view':
        _viewHistoryItem(item);
        break;
      case 'delete':
        _deleteHistoryItem(item);
        break;
    }
  }

  void _deleteHistoryItem(HistoryItem item) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('确认删除'),
        content: Text('确定要删除 "${item.imageFileName}" 的历史记录吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.of(context).pop();
              final historyService = context.read<HistoryService>();
              await historyService.removeFromHistory(item.id);
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('已删除历史记录')),
                );
                setState(() {}); // 刷新列表
              }
            },
            child: const Text('删除'),
          ),
        ],
      ),
    );
  }
}

class HistoryItemViewer extends StatelessWidget {
  final HistoryItem historyItem;

  const HistoryItemViewer({super.key, required this.historyItem});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(historyItem.imageFileName),
        elevation: 0,
      ),
      body: Column(
        children: [
          Expanded(
            child: historyItem.localModelPath.endsWith('.ply')
                ? _buildPlyViewer(context)
                : _buildModelViewer(context, colorScheme),
          ),
        ],
      ),
    );
  }

  Widget _buildPlyViewer(BuildContext context) {
    // 使用GaussianSplatterWidget显示PLY格式的模型
    final colorScheme = Theme.of(context).colorScheme;
    try {
      return Container(
        color: colorScheme.surfaceContainerLow,
        child: GaussianSplatterWidget(
          assetPath: historyItem.localModelPath,
        ),
      );
    } catch (e) {
      return Container(
        color: colorScheme.surfaceContainerLow,
        child: Center(
          child: Text('无法加载PLY模型: $e'),
        ),
      );
    }
  }

  Widget _buildModelViewer(BuildContext context, ColorScheme colorScheme) {
    // 使用ModelViewer显示非PLY格式的模型
    try {
      return ModelViewer(
        backgroundColor: colorScheme.surfaceContainerLow,
        src: historyItem.localModelPath.startsWith('http') 
            ? historyItem.localModelPath 
            : 'file://${historyItem.localModelPath}',
        alt: "历史记录中的3D模型",
        ar: true,
        arModes: const ['scene-viewer', 'webxr', 'quick-look'],
        autoRotate: false,
        cameraControls: true,
        exposure: 1.0,
        environmentImage: null,
        loading: Loading.lazy,
      );
    } catch (e) {
      return Container(
        color: colorScheme.surfaceContainerLow,
        child: Center(
          child: Text('无法加载模型: $e'),
        ),
      );
    }
  }
}